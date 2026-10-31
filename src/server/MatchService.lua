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
local TerrenoConfig = require(ReplicatedStorage.Shared.Config.TerrenoConfig)
local TerrenoService = require(script.Parent.TerrenoService)

local MatchService = {}
local playerState -- asignado en Iniciar() con pcall; nil = sin reanimación
local dataService -- asignado en Iniciar() con pcall; nil = sin persistencia
local puntosService -- asignado en Iniciar() con pcall; nil = stats sin puntos
local recordRemoto -- creado en Iniciar(); nil antes de arrancar

local checkpoints = {} -- [player] = { indice = n, pos = Vector3 }
local distancia = {} -- [player] = progreso máximo en la ruta
local recordSesion = {} -- [player] = mejor distancia de la sesión
local recordSuperado = {} -- [player] = true al avisar en vivo del récord (B5)
local datosCargados = {} -- [player] = true cuando DataService.AlCargar ya corrió
local inicio = nil -- os.clock() del inicio de la partida actual
local partidaTerminada = false
local participantesPartida = {} -- roster de la partida actual
local modoActual = nil -- "historia" | "rapida"
local semillaActualPartida = nil -- semilla de la partida actual (B4)
local indiceSemillaHistoria = 0 -- rotación de TerrenoConfig.HistoriaSemillas
local recargando = {} -- [player] = true mientras LoadCharacter está en curso
local viajes = {} -- [player] = token del último teletransporte pendiente
local rutaActual -- ruta del escenario construido (nil si no hay terreno)
local totalCheckpoints = 0 -- checkpoints lógicos de la ruta actual (solo Historia)
local cerrados = {} -- [player] = true al alcanzar la meta; no se vuelve a cerrar ni a cobrar
local reanimaciones = {} -- [player] = reanimaciones hechas a compañeros en esta partida
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

-- B5: publica el récord al HUD; `superado` dispara el aviso en vivo.
local function publicarRecord(player, superado)
	if recordRemoto then
		recordRemoto:FireClient(player, {
			record = math.floor(recordSesion[player] or 0),
			superado = superado == true,
		})
	end
end

-- B4: rotación estable de semillas curadas de Historia (sin repetir la anterior).
local function siguienteSemillaHistoria()
	local semillas = TerrenoConfig.HistoriaSemillas
	indiceSemillaHistoria = indiceSemillaHistoria % #semillas + 1
	return semillas[indiceSemillaHistoria]
end

-- B6: medalla por tiempo relativo a la longitud (segundos por 1000 studs).
local function medallaDe(distanciaRuta, segundos)
	if type(distanciaRuta) ~= "number" or distanciaRuta <= 0 or type(segundos) ~= "number" then
		return nil
	end
	local umbral = Config.Medallas.SegundosPor1000
	local tramo = distanciaRuta / 1000
	if segundos <= umbral.oro * tramo then
		return "oro"
	elseif segundos <= umbral.plata * tramo then
		return "plata"
	elseif segundos <= umbral.bronce * tramo then
		return "bronce"
	end
	return nil
end

-- B6: mejor tiempo de ronda rápida en estadisticas.mejorRapida (solo si ya cargó).
local function guardarMejorRapida(player, segundos)
	if modoActual ~= "rapida" or not dataService or not datosCargados[player] then
		return
	end
	local datos = dataService.Obtener(player)
	local estadisticas = datos.estadisticas
	if type(estadisticas) ~= "table" then
		estadisticas = {}
		datos.estadisticas = estadisticas
	end
	-- Deuda L4 cerrada: estadisticas.partidas y estadisticas.metas (esquema v2 §3)
	local function sumarPartida(player)
		local datos = dataService.Obtener(player)
		local estadisticas = datos.estadisticas
		if type(estadisticas) ~= "table" then
			estadisticas = {}
			datos.estadisticas = estadisticas
		end
		estadisticas.partidas = (tonumber(estadisticas.partidas) or 0) + 1
		dataService.Guardar(player, "estadisticas", estadisticas)
	end

	local function sumarMeta(player)
		local datos = dataService.Obtener(player)
		local estadisticas = datos.estadisticas
		if type(estadisticas) ~= "table" then
			estadisticas = {}
			datos.estadisticas = estadisticas
		end
		estadisticas.metas = (tonumber(estadisticas.metas) or 0) + 1
		dataService.Guardar(player, "estadisticas", estadisticas)
	end

	local mejor = tonumber(estadisticas.mejorRapida) or 0
	if mejor <= 0 or segundos < mejor then
		estadisticas.mejorRapida = segundos
		dataService.Guardar(player, "estadisticas", estadisticas)
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
		StageService.Construir(semilla)
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

-- D38 brújula (plan fase-11 §L9): objetivos estáticos de la ruta para el HUD.
-- Solo puntos públicos de la carrera; JAMÁS posiciones de El Doble ni de enemigos.
-- PlayerStateService los adjunta al payload de HudEstado (bucle de 1 Hz).
function MatchService.ObjetivosBrujula(player)
	if not rutaActual or player:GetAttribute("EnJuego") ~= true then
		return nil
	end
	local meta = rutaActual:PuntoEnDistancia(rutaActual.Longitud)
	-- Próximo checkpoint: el primero tras el último alcanzado; sin pendientes = meta.
	-- La ronda rápida (totalCheckpoints 0) también apunta su C a la meta.
	local puntoCheckpoint = meta
	local alcanzado = checkpoints[player] and checkpoints[player].indice or 0
	if totalCheckpoints > 0 and alcanzado < totalCheckpoints then
		puntoCheckpoint = rutaActual:PuntoEnDistancia((alcanzado + 1) * Config.Etapa0.CheckpointCada)
	end
	-- La tienda de campaña se ancla al inicio de la ruta (StageService/TiendaCampamento)
	local tienda = rutaActual:PuntoEnDistancia(0)
	return {
		checkpoint = { x = math.floor(puntoCheckpoint.X), z = math.floor(puntoCheckpoint.Z) },
		meta = { x = math.floor(meta.X), z = math.floor(meta.Z) },
		tienda = { x = math.floor(tienda.X), z = math.floor(tienda.Z) },
	}
end

-- Mejor distancia alcanzada por cualquier participante en la partida actual.
local function mejorDelEquipo()
	local mejor = 0
	for _, player in ipairs(participantesPartida) do
		if player.Parent then
			mejor = math.max(mejor, distancia[player] or 0)
		end
	end
	return math.floor(mejor)
end

-- QA de Studio (E49): coloca al jugador al final de la ruta sin caminar los ~5.000
-- studs. El bucle de 1 Hz sigue cerrando checkpoints y meta; la distancia avanza un
-- stud menos que el destino para que el tope de 32 studs/s no descarte el salto.
function MatchService._ProbarAvanzarRuta(player, objetivo)
	if not RunService:IsStudio() or not rutaActual or not modoActual then
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

function MatchService.GetSemilla()
	return semillaActualPartida
end

-- Seams de Studio para la QA de L4: medallas sintéticas y récord sembrado.
if RunService:IsStudio() then
	function MatchService._ProbarMedalla(distancia, segundos)
		return medallaDe(distancia, segundos)
	end

	function MatchService._ProbarRecord(player, valor)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return false
		end
		recordSesion[player] = math.max(0, math.floor(tonumber(valor) or 0))
		recordSuperado[player] = nil
		publicarRecord(player, false)
		return true
	end
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
	if modoPartida == "historia" and semilla == nil then
		semilla = siguienteSemillaHistoria()
	end
	semillaActualPartida = semilla

	-- Reset de la partida anterior (los récords de sesión se conservan)
	partidaTerminada = false
	inicio = nil
	table.clear(checkpoints)
	table.clear(distancia)
	table.clear(cerrados)
	table.clear(reanimaciones)
	table.clear(ultimoRescate)
	table.clear(ultimoTick)
	table.clear(recordSuperado)
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

	-- B5/B7: el HUD recibe el récord de partida y el feed de caídas arranca vacío
	if playerState then
		playerState.LimpiarCaidas()
	end
	for _, player in ipairs(roster) do
		publicarRecord(player, false)
	end

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
		-- A8: solo cuentan las reanimaciones a un compañero dentro de la partida
		playerState.Reanimado.Event:Connect(function(reanimador, jugador)
			if not reanimador or reanimador == jugador or not inicio or partidaTerminada then
				return
			end
			if reanimador:GetAttribute("EnJuego") ~= true then
				return
			end
			reanimaciones[reanimador] = (reanimaciones[reanimador] or 0) + 1
		end)
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
	recordRemoto = Remotes.Crear(Remotes.Nombres.Record)
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
		reanimaciones[player] = nil
		ultimoRescate[player] = nil
		ultimoTick[player] = nil
		recordSuperado[player] = nil
		datosCargados[player] = nil
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
		local ok = MatchService.IniciarPartida(roster, modoActual, semillaActualPartida, true)
		if ok then
			print("[Match] partida reiniciada por", player.Name)
		end
	end)

	-- Cierre al alcanzar la meta, común a Historia y ronda rápida (fase 11 · L4/B6).
	local function cerrarMeta(player)
		cerrados[player] = true
		player:SetAttribute("Terminado", true)
		distancia[player] = rutaActual.Longitud
		player:SetAttribute("Distancia", math.floor(rutaActual.Longitud))
		local largoTramo = math.floor(rutaActual.Longitud)
		local recordAnterior = recordSesion[player] or 0
		local nuevoRecord = largoTramo > recordAnterior
		local tiempo = math.floor(os.clock() - inicio)
		recordSesion[player] = math.max(recordAnterior, largoTramo)
		if dataService then
			dataService.Guardar(player, "record", recordSesion[player])
		end
		publicarRecord(player, false)
		guardarMejorRapida(player, tiempo)
		sumarPartida(player)
		sumarMeta(player)
		local stats = {
			distancia = largoTramo,
			tiempo = tiempo,
			checkpoint = totalCheckpoints,
			puntos = puntosService and puntosService.GetPuntos(player) or 0,
			record = math.max(recordSesion[player], largoTramo),
			nuevoRecord = nuevoRecord,
			reanimaciones = reanimaciones[player] or 0,
			mejorEquipo = mejorDelEquipo(),
			victoria = true,
			medalla = medallaDe(rutaActual.Longitud, tiempo),
			semilla = semillaActualPartida,
		}
		finPartida:FireClient(player, stats)
		alTerminar:Fire(player, stats, modoActual)
		sonido:FireClient(player, { id = "Fin", subtitulo = AudioConfig.Efectos.Fin.subtitulo })
		print(("[Match] meta alcanzada por %s en %ds%s"):format(
			player.Name,
			tiempo,
			stats.medalla and (" · medalla " .. stats.medalla) or ""
		))
	end

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
							-- B7: el vacío también derriba, con su propia causa
							if playerState and not playerState.EstaCaido(player) then
								playerState.Derribar(player, "vacio")
							end
							print("[Match] rescate de", player.Name, "en", math.floor(distancia[player] or 0), "(vacio)")
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
						-- B5: aviso en vivo al superar el récord (solo si ya había uno)
						local recordPrevio = recordSesion[player] or 0
						if recordPrevio > 0 and not recordSuperado[player] and distancia[player] > recordPrevio then
							recordSuperado[player] = true
							publicarRecord(player, true)
							print("[Record] " .. player.Name .. " supera " .. math.floor(recordPrevio) .. " studs")
						end
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
						end

						-- Meta: cierra la carrera sin sacar al jugador de EnJuego (HUD/estamina).
						-- Común a Historia y ronda rápida: la rápida también tiene arco de meta (B6).
						if inicio
							and progreso >= rutaActual.Longitud - Config.Etapa0.Meta.Distancia
							and not estaCaido(player) then
							cerrarMeta(player)
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
								publicarRecord(player, false)
								sumarPartida(player)
								local stats = {
									distancia = dist,
									tiempo = math.floor(os.clock() - inicio),
									checkpoint = cp and cp.indice or 0,
									puntos = puntosService and puntosService.GetPuntos(player) or 0,
									record = math.max(recordSesion[player], dist),
									nuevoRecord = nuevoRecord,
									reanimaciones = reanimaciones[player] or 0,
									mejorEquipo = mejorDelEquipo(),
									causa = playerState and playerState.Causa(player) or nil,
									semilla = semillaActualPartida,
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
			datosCargados[player] = true
			if type(datos) == "table" then
				aplicarRecord(player, datos.record)
			end
			publicarRecord(player, false)
		end)
		-- Carrera: los datos pueden haber cargado antes de conectar AlCargar
		for _, player in Players:GetPlayers() do
			local datos = dataService.Obtener(player)
			if type(datos) == "table" then
				if datos.schema ~= nil then
					datosCargados[player] = true
				end
				aplicarRecord(player, datos.record)
			end
			publicarRecord(player, false)
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
