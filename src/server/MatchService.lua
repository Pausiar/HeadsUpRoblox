-- MatchService: checkpoints, respawn, fin de partida y reintentar (plan §4.1/§4.2).
-- Servidor autoritativo: LobbyService llama a IniciarPartida y aquí se decide el
-- fin de la partida; el reintentar sigue limitado en el servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.LobbyConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local StageService = require(script.Parent.StageService)
local RondaRapidaService = require(script.Parent.RondaRapidaService)
local TerrenoService = require(script.Parent.TerrenoService)

local MatchService = {}
local playerState -- asignado en Iniciar() con pcall; nil = sin reanimación
local dataService -- asignado en Iniciar() con pcall; nil = sin persistencia
local puntosService -- asignado en Iniciar() con pcall; nil = stats sin puntos

local checkpoints = {} -- [player] = { indice = n, pos = Vector3 }
local distancia = {} -- [player] = progreso máximo en la ruta
local recordSesion = {} -- [player] = mejor distancia de la sesión
local inicio = nil -- os.clock() del inicio de la partida actual
local partidaTerminada = false
local participantesPartida = {} -- roster de la partida actual
local modoActual = nil -- "historia" | "rapida"
local recargando = {} -- [player] = true mientras LoadCharacter está en curso
local viajes = {} -- [player] = token del último teletransporte pendiente
local rutaActual -- ruta del escenario construido (nil si no hay terreno)
local totalCheckpoints = 0 -- checkpoints lógicos de la ruta actual (solo Historia)
local cerrados = {} -- [player] = true al alcanzar la meta; no se vuelve a cerrar ni a cobrar
local ultimoRescate = {} -- [player] = os.clock() del último rescate anti-vacío
local ultimoTick = {} -- [player] = os.clock() del último tick con posición válida

local ENFRIAMIENTO_RESCATE = 2 -- s entre rescates del mismo jugador
local VELOCIDAD_MAXIMA = 32 -- studs/s: sprint real 24 + margen; fija el tope de avance

-- Señal interna para otros servicios del servidor (plan §4.5: checkpoint da puntos)
local checkpointAlcanzado = Instance.new("BindableEvent")
MatchService.CheckpointAlcanzado = checkpointAlcanzado -- (player, indice)

-- Señal de fin de partida por jugador (Piñas, telemetría): (player, stats, modo)
local alTerminar = Instance.new("BindableEvent")
MatchService.AlTerminar = alTerminar

-- Señales del lobby (fase 2): el inicio y el fin se publican una sola vez
local alEmpezar = Instance.new("BindableEvent")
MatchService.AlEmpezar = alEmpezar -- (jugadores, modo, semilla)

local alTerminarPartida = Instance.new("BindableEvent")
MatchService.AlTerminarPartida = alTerminarPartida -- (jugadores)

-- PlayerStateService no expone su tabla de estados: caído == PlatformStand o muerte
local function estaCaido(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	return hum.PlatformStand or hum.Health <= 0
end

-- Récord personal persistente (plan §3.3/§4.5): nunca baja un récord ya logrado
local function aplicarRecord(player, record)
	if type(record) == "number" then
		recordSesion[player] = math.max(recordSesion[player] or 0, record)
	end
end

-- Spawn de la partida: el que acaba de construir StageService/RondaRapidaService
local function posicionSpawn(modoPartida)
	if modoPartida == "rapida" then
		local carpeta = workspace:FindFirstChild("RondaRapida")
		local spawn = carpeta and carpeta:FindFirstChild("Spawn")
		if spawn then
			return spawn.Position + Vector3.new(0, 4, 0)
		end
		return Vector3.new(0, 4, 4) -- respaldo: inicio del camino
	end

	local carpeta = workspace:FindFirstChild("Etapa0")
	local spawn = carpeta and carpeta:FindFirstChild("Spawn")
	if spawn then
		return spawn.Position + Vector3.new(0, 4, 0)
	end
	return Vector3.new(-8, 4, 0) -- respaldo: spawn del sendero
end

-- Coloca al jugador; si está caído lo reanima y si está muerto recarga el personaje.
-- recargarCaido fuerza el respawn al volver al lobby: así se cierra el FinScreen,
-- que solo se oculta en CharacterAdded. viajes evita que un respawn pendiente pise
-- un teletransporte posterior (lobby/partida).
local function telegrafiar(player, destino, recargarCaido)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local forzar = recargarCaido == true and playerState ~= nil and playerState.EstaCaido(player)

	if playerState and playerState.EstaCaido(player) and not forzar then
		playerState.Reanimar(player)
	end

	viajes[player] = (viajes[player] or 0) + 1
	local miViaje = viajes[player]

	if not forzar and char and hum and hum.Health > 0 then
		char:PivotTo(CFrame.new(destino))
		return
	end
	if not player.Parent then
		return
	end

	recargando[player] = true
	local conexion
	conexion = player.CharacterAdded:Connect(function(nuevo)
		if conexion then
			conexion:Disconnect()
			conexion = nil
		end
		recargando[player] = nil
		task.wait(0.1) -- mismo margen que el respawn en checkpoint
		if nuevo.Parent and viajes[player] == miViaje then
			nuevo:PivotTo(CFrame.new(destino))
		end
	end)
	-- En segundo plano: IniciarPartida no debe ceder el turno al lobby a mitad de inicio
	task.spawn(function()
		local ok, err = pcall(function()
			player:LoadCharacter()
		end)
		if not ok then
			recargando[player] = nil
			if conexion then
				conexion:Disconnect()
			end
			warn("[Match] no se pudo recargar a " .. player.Name .. ": " .. tostring(err))
		end
	end)
end

-- Prepara el mapa del modo pedido. ConstruirConSemilla/Limpiar ya son idempotentes.
local function prepararEscenario(modoPartida, semilla)
	if modoPartida == "historia" then
		RondaRapidaService.Limpiar()
		StageService.Construir()
	else
		StageService.Limpiar()
		RondaRapidaService.ConstruirConSemilla(semilla)
	end
end

function MatchService.EstaEnPartida()
	return #participantesPartida > 0 and not partidaTerminada
end

function MatchService.GetDistancia(player)
	return distancia[player] or 0
end

-- Alias del contrato anterior (RankingService llama a ObtenerDistancia)
MatchService.ObtenerDistancia = MatchService.GetDistancia

-- QA de Studio (E49): coloca al jugador al final de la ruta sin caminar los ~5.000
-- studs. El bucle de 1 Hz sigue cerrando checkpoints y meta; la distancia avanza un
-- stud menos que el destino para que el tope de 32 studs/s no descarte el salto.
function MatchService._ProbarAvanzarRuta(player, objetivo)
	if not RunService:IsStudio() or not rutaActual or modoActual ~= "historia" then
		return false
	end
	local char = player and player.Parent and player.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return false
	end
	objetivo = math.clamp(objetivo or (rutaActual.Longitud - 2), 1, rutaActual.Longitud)
	distancia[player] = math.max(distancia[player] or 0, objetivo - 1)
	char:PivotTo(CFrame.new(rutaActual:PuntoEnDistancia(objetivo) + Vector3.new(0, 4, 0)))
	return true
end

-- Inicio formal desde el lobby (o reintentar). Valida todo lo que llega de fuera.
-- recargarCaidos es interno de REINTENTAR: respawnea a los caídos para cerrar el FinScreen.
function MatchService.IniciarPartida(jugadores, modoPartida, semilla, recargarCaidos)
	if not LobbyConfig.EsModoValido(modoPartida) then
		warn("[Match] modo inválido: " .. tostring(modoPartida))
		return false
	end
	if type(jugadores) ~= "table" then
		warn("[Match] lista de jugadores inválida")
		return false
	end

	-- Solo Player en el servidor, sin duplicados y como máximo el aforo del lobby
	local roster = {}
	local vistos = {}
	for _, player in ipairs(jugadores) do
		if typeof(player) == "Instance" and player:IsA("Player") and player.Parent and not vistos[player] then
			if #roster >= LobbyConfig.MaxJugadores then
				break
			end
			vistos[player] = true
			table.insert(roster, player)
		end
	end
	if #roster == 0 then
		warn("[Match] no hay jugadores válidos para iniciar")
		return false
	end

	if type(semilla) ~= "number" then
		semilla = nil
	end
	if modoPartida == "rapida" and semilla == nil then
		semilla = os.time()
	end

	-- Reset de la partida anterior (los récords de sesión se conservan)
	partidaTerminada = false
	inicio = nil
	table.clear(checkpoints)
	table.clear(distancia)
	table.clear(cerrados)
	table.clear(ultimoRescate)
	table.clear(ultimoTick)
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("Distancia", 0)
		player:SetAttribute("Terminado", false)
	end
	participantesPartida = roster
	modoActual = modoPartida

	prepararEscenario(modoPartida, semilla)
	-- Los checkpoints lógicos son exactamente los postes que colocó StageService;
	-- la ronda rápida no tiene y nunca los cobra.
	rutaActual = TerrenoService.RutaActual()
	totalCheckpoints = modoPartida == "historia" and StageService.TotalCheckpoints or 0
	print(("[Match] ruta de %d studs, %d checkpoints"):format(
		rutaActual and math.floor(rutaActual.Longitud) or 0,
		totalCheckpoints
	))

	local destino = posicionSpawn(modoPartida)
	for _, player in ipairs(roster) do
		telegrafiar(player, destino, recargarCaidos == true)
	end

	-- EnJuego solo después del teletransporte: los espectadores nunca cuentan
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("EnJuego", false)
	end
	for _, player in ipairs(roster) do
		if player.Parent then
			player:SetAttribute("EnJuego", true)
		end
	end
	inicio = os.clock()

	print(("[Match] inicio modo %s con %d jugadores%s"):format(
		modoPartida,
		#roster,
		semilla and (" (semilla " .. tostring(semilla) .. ")") or ""
	))
	alEmpezar:Fire(roster, modoPartida, semilla)
	return true
end

-- Vuelta al lobby: si la partida fue rápida no queda suelo, se reconstruye el de historia
-- (idempotente) para que el spawn del lobby no quede en el vacío.
function MatchService.PrepararLobby()
	if not workspace:FindFirstChild("Etapa0") then
		StageService.Construir()
	end
	participantesPartida = {}
	modoActual = nil
	partidaTerminada = false
	inicio = nil
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("EnJuego", false)
		telegrafiar(player, LobbyConfig.SpawnLobby, true)
	end
	print("[Match] vuelta al lobby")
end

function MatchService.Iniciar()
	local okEstado, resEstado = pcall(require, script.Parent.PlayerStateService)
	if okEstado then
		playerState = resEstado
	else
		warn("[Match] sin PlayerStateService: no se reanimará al iniciar")
	end

	local okPuntos, resPuntos = pcall(require, script.Parent.PuntosService)
	if okPuntos then
		puntosService = resPuntos
	end

	local sonido = Remotes.Crear(Remotes.Nombres.Sonido) -- fase 6: checkpoint y fin
	local finPartida = Remotes.Crear(Remotes.Nombres.FinPartida)
	local reintentar = Remotes.Crear(Remotes.Nombres.Reintentar)
	local permitirReintentar = RateLimiter.nuevo(Config.Etapa0.Match.EnfriamientoReintentar)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			task.wait(0.1)
			local cp = checkpoints[player]
			-- Solo reposiciona en checkpoints de Historia; los viejos sin pos se ignoran
			if cp and cp.pos and char.Parent and modoActual == "historia" and MatchService.EstaEnPartida() then
				char:PivotTo(CFrame.new(cp.pos + Vector3.new(0, 4, 0)))
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		checkpoints[player] = nil
		distancia[player] = nil
		recargando[player] = nil
		viajes[player] = nil
		cerrados[player] = nil
		ultimoRescate[player] = nil
		ultimoTick[player] = nil
		for i, p in ipairs(participantesPartida) do
			if p == player then
				table.remove(participantesPartida, i)
				break
			end
		end
	end)

	-- Reintentar: reinicia la misma partida con el roster y el modo actuales
	reintentar.OnServerEvent:Connect(function(player)
		if not permitirReintentar(player) then
			return
		end
		local roster = {}
		for _, p in ipairs(participantesPartida) do
			if p.Parent then
				table.insert(roster, p)
			end
		end
		if #roster == 0 then
			return -- sin participantes no hay nada que reiniciar
		end
		local ok = MatchService.IniciarPartida(roster, modoActual, os.time(), true)
		if ok then
			print("[Match] partida reiniciada por", player.Name)
		end
	end)

	-- Bucle de fin de partida: 1 Hz, igual que el del estado del jugador
	task.spawn(function()
		while true do
			task.wait(1)
			if not partidaTerminada then
				for _, player in Players:GetPlayers() do
					local char = player.Character
					local raiz = char and char:FindFirstChild("HumanoidRootPart")
					if raiz and rutaActual and player:GetAttribute("EnJuego") and not cerrados[player] then
						local distanciaRuta = rutaActual:CercanoXZ(raiz.Position.X, raiz.Position.Z)
						-- Salirse del sendero es libre: no se teletransporta. Solo se rescata
						-- al caer al vacío entre teselas, para no perder la partida.
						local ahora = os.clock()
						local dt = math.min(ahora - (ultimoTick[player] or ahora), 2)
						ultimoTick[player] = ahora
						if raiz.Position.Y < -10
							and not recargando[player]
							and ahora - (ultimoRescate[player] or 0) >= ENFRIAMIENTO_RESCATE then
							ultimoRescate[player] = ahora
							local punto = rutaActual:PuntoEnDistancia(distancia[player] or 0)
							telegrafiar(player, punto + Vector3.new(0, 4, 0))
							print("[Match] rescate de", player.Name, "en", math.floor(distancia[player] or 0))
							continue
						end
						-- Fuera del corredor no hay progreso: caerse al monte no regala checkpoints
						if distanciaRuta > Config.Etapa0.RadioProgreso then
							continue
						end
						local progreso = rutaActual:Progreso(raiz.Position)
						-- Tope de avance por tiempo (32 studs/s + 4 de holgura): un teleport
						-- de cientos de studs no entra nunca; caminar o esprintar (24) sí.
						if progreso > (distancia[player] or 0) + VELOCIDAD_MAXIMA * dt + 4 then
							continue
						end
						distancia[player] = math.max(
							distancia[player] or 0,
							math.min(progreso, rutaActual.Longitud)
						)
						player:SetAttribute("Distancia", math.floor(distancia[player]))
						-- Por progreso: si un tick cruza varios postes, se cobran todos
						if modoActual == "historia" then
							local actual = checkpoints[player]
							local siguiente = (actual and actual.indice or 0) + 1
							while siguiente <= totalCheckpoints
								and progreso >= siguiente * Config.Etapa0.CheckpointCada - 2 do
								local punto = rutaActual:PuntoEnDistancia(siguiente * Config.Etapa0.CheckpointCada)
								checkpoints[player] = { indice = siguiente, pos = punto }
								checkpointAlcanzado:Fire(player, siguiente)
								sonido:FireClient(player, { id = "Checkpoint", subtitulo = AudioConfig.Efectos.Checkpoint.subtitulo })
								print("[Match] checkpoint", siguiente, "por", player.Name)
								siguiente += 1
							end

							-- Meta: cierra la carrera sin sacar al jugador de EnJuego (HUD/estamina).
							if inicio
								and progreso >= rutaActual.Longitud - Config.Etapa0.Meta.Distancia
								and not estaCaido(player) then
								cerrados[player] = true
								player:SetAttribute("Terminado", true)
								distancia[player] = rutaActual.Longitud
								player:SetAttribute("Distancia", math.floor(rutaActual.Longitud))
								local largoTramo = math.floor(rutaActual.Longitud)
								local recordAnterior = recordSesion[player] or 0
								local nuevoRecord = largoTramo > recordAnterior
								recordSesion[player] = math.max(recordAnterior, largoTramo)
								if dataService then
									dataService.Guardar(player, "record", recordSesion[player])
								end
								local stats = {
									distancia = largoTramo,
									tiempo = math.floor(os.clock() - inicio),
									checkpoint = totalCheckpoints,
									puntos = puntosService and puntosService.GetPuntos(player) or 0,
									record = math.max(recordSesion[player], largoTramo),
									nuevoRecord = nuevoRecord,
									victoria = true,
								}
								finPartida:FireClient(player, stats)
								alTerminar:Fire(player, stats, modoActual)
								sonido:FireClient(player, { id = "Fin", subtitulo = AudioConfig.Efectos.Fin.subtitulo })
								print("[Match] meta alcanzada por", player.Name)
							end
						end
					end
				end

				-- Solo cuentan los participantes: el lobby pone EnJuego en el servidor
				local jugadores = {}
				for _, player in Players:GetPlayers() do
					if player:GetAttribute("EnJuego") then
						table.insert(jugadores, player)
					end
				end
				if inicio and #jugadores == 0 then
					-- Todos los participantes se fueron: cerrar la ronda para que el lobby no
					-- quede en «partida». Los espectadores entran en la siguiente.
					partidaTerminada = true
					alTerminarPartida:Fire({})
					print("[Match] partida abandonada: sin participantes")
				elseif #jugadores > 0 and inicio then
					local todosCerrados = true
					for _, player in ipairs(jugadores) do
						-- Un personaje recargándose no cuenta como caído todavía
						if not recargando[player] and not estaCaido(player) and not cerrados[player] then
							todosCerrados = false
							break
						end
					end
					if todosCerrados then
						partidaTerminada = true
						for _, player in ipairs(jugadores) do
							-- Los que ya llegaron a la meta recibieron su FinPartida al cerrar:
							-- no se les repite pantalla, récord, Piñas ni sonido.
							if not cerrados[player] then
								local cp = checkpoints[player]
								local dist = math.round(distancia[player] or 0)
								local recordAnterior = recordSesion[player] or 0
								local nuevoRecord = dist > recordAnterior
								recordSesion[player] = math.max(recordAnterior, dist)
								-- Persistir el récord para la próxima sesión (plan §3.3/§4.5)
								if dataService then
									dataService.Guardar(player, "record", recordSesion[player])
								end
								local stats = {
									distancia = dist,
									tiempo = math.floor(os.clock() - inicio),
									checkpoint = cp and cp.indice or 0,
									puntos = puntosService and puntosService.GetPuntos(player) or 0,
									record = math.max(recordSesion[player], dist),
									nuevoRecord = nuevoRecord,
								}
								finPartida:FireClient(player, stats)
								alTerminar:Fire(player, stats, modoActual)
								-- Solo los que cierran sin meta: los ganadores ya oyeron el suyo.
								sonido:FireClient(player, { id = "Fin", subtitulo = AudioConfig.Efectos.Fin.subtitulo })
							end
						end
						-- Aviso único al lobby (los FinPartida por jugador siguen igual)
						local roster = {}
						for _, player in ipairs(participantesPartida) do
							if player.Parent then
								table.insert(roster, player)
							end
						end
						alTerminarPartida:Fire(roster)
						print("[Match] fin de partida")
					end
				end
			end
		end
	end)

	-- Récord personal persistente vía DataService (plan §3.3/§4.5)
	local okDatos, resDatos = pcall(require, script.Parent.DataService)
	if okDatos then
		dataService = resDatos
		dataService.AlCargar.Event:Connect(function(player, datos)
			if type(datos) == "table" then
				aplicarRecord(player, datos.record)
			end
		end)
		-- Carrera: los datos pueden haber cargado antes de conectar AlCargar
		for _, player in Players:GetPlayers() do
			local datos = dataService.Obtener(player)
			if type(datos) == "table" then
				aplicarRecord(player, datos.record)
			end
		end
	else
		warn("[Match] sin DataService: el récord no se persiste esta sesión")
	end

	-- La ruta de historia ya está construida por Main antes de este Iniciar
	rutaActual = TerrenoService.RutaActual()
	totalCheckpoints = StageService.TotalCheckpoints
	print(("[Match] ruta: %d studs · %d checkpoints por partida"):format(
		rutaActual and math.floor(rutaActual.Longitud) or 0,
		totalCheckpoints
	))
end

return MatchService
