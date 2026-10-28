-- MatchService: checkpoints, respawn, fin de partida y reintentar (slice etapa 0).
-- Servidor autoritativo: el fin de partida se decide aquí y el reintentar se limita aquí.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local MatchService = {}
local playerState
local dataService -- asignado en Iniciar(); lo usa el fin de partida

local checkpoints = {} -- [player] = { indice = n, x = x }
local distancia = {} -- [player] = X máxima alcanzada
local recordSesion = {} -- [player] = mejor distancia de la sesión
local inicio = nil -- os.clock() del primer CharacterAdded; Reintentar lo resetea
local partidaTerminada = false

-- Señal interna para otros servicios del servidor (plan §4.5: checkpoint da puntos)
local checkpointAlcanzado = Instance.new("BindableEvent")
MatchService.CheckpointAlcanzado = checkpointAlcanzado -- (player, indice)

-- Señal de fin de partida por jugador (Piñas, telemetría): (player, stats)
local alTerminar = Instance.new("BindableEvent")
MatchService.AlTerminar = alTerminar

local function crearZona(x, indice, padre)
	local zona = Instance.new("Part")
	zona.Anchored = true
	zona.TopSurface = Enum.SurfaceType.Smooth
	zona.BottomSurface = Enum.SurfaceType.Smooth
	zona.Name = "ZonaCheckpoint" .. indice
	zona.Size = Vector3.new(2, 10, Config.Etapa0.Ancho + 4)
	zona.CFrame = CFrame.new(x, 5, 0)
	zona.CanCollide = false
	zona.Transparency = 1
	zona.Parent = padre
	return zona
end

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

function MatchService.ObtenerDistancia(player)
	return distancia[player] or 0
end

function MatchService.Iniciar()
	playerState = require(script.Parent.PlayerStateService)

	local etapa = Config.Etapa0
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Match"
	carpeta.Parent = workspace

	-- Zonas-gatillo en las mismas X que los postes visuales de StageService
	local indice = 0
	for x = etapa.CheckpointCada, etapa.Longitud - 20, etapa.CheckpointCada do
		indice += 1
		local info = { indice = indice, x = x }
		local zona = crearZona(x, indice, carpeta)
		zona.Touched:Connect(function(otra)
			local char = otra and otra.Parent
			local player = char and Players:GetPlayerFromCharacter(char)
			if not player then
				return
			end
			local actual = checkpoints[player]
			if not actual or info.indice > actual.indice then
				checkpoints[player] = info
				checkpointAlcanzado:Fire(player, info.indice)
				print("[Match] checkpoint", info.indice, "por", player.Name)
			end
		end)
	end

	local finPartida = Remotes.Crear(Remotes.Nombres.FinPartida)
	local reintentar = Remotes.Crear(Remotes.Nombres.Reintentar)
	local empezar = Remotes.Crear(Remotes.Nombres.Empezar)
	local permitirEmpezar = RateLimiter.nuevo(1)
	local permitirReintentar = RateLimiter.nuevo(etapa.Match.EnfriamientoReintentar)
	local puntosService = require(script.Parent.PuntosService)

	-- JUGAR: el servidor pone EnJuego (los atributos que fija el cliente no replican)
	empezar.OnServerEvent:Connect(function(player)
		if not permitirEmpezar(player) then
			return
		end
		player:SetAttribute("EnJuego", true)
		print("[Match] empieza:", player.Name)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			if not inicio then
				inicio = os.clock()
			end
			task.wait(0.1)
			local cp = checkpoints[player]
			if cp and char.Parent then
				char:PivotTo(CFrame.new(cp.x, 4, 0))
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		checkpoints[player] = nil
		distancia[player] = nil
	end)

	reintentar.OnServerEvent:Connect(function(player)
		if not permitirReintentar(player) then
			return
		end
		partidaTerminada = false
		inicio = os.clock()
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health <= 0 then
				p:LoadCharacter() -- el respawn en checkpoint lo recoloca
			elseif hum and hum.PlatformStand then
				playerState.Reanimar(p)
				local cp = checkpoints[p]
				if cp then
					char:PivotTo(CFrame.new(cp.x, 4, 0))
				end
			end
		end
		print("[Match] partida reiniciada por", player.Name)
	end)

	-- Bucle de fin de partida: 1 Hz, igual que el del estado del jugador
	task.spawn(function()
		while true do
			task.wait(1)
			if not partidaTerminada then
				for _, player in Players:GetPlayers() do
					local char = player.Character
					local raiz = char and char:FindFirstChild("HumanoidRootPart")
					if raiz then
						distancia[player] = math.max(distancia[player] or 0, raiz.Position.X)
					end
				end

				-- Solo cuentan los jugadores que han pulsado JUGAR (lobby, plan §4.1)
				local jugadores = {}
				for _, player in Players:GetPlayers() do
					if player:GetAttribute("EnJuego") then
						table.insert(jugadores, player)
					end
				end
				if #jugadores > 0 and inicio then
					local todosCaidos = true
					for _, player in jugadores do
						if not estaCaido(player) then
							todosCaidos = false
							break
						end
					end
					if todosCaidos then
						partidaTerminada = true
						for _, player in jugadores do
							local cp = checkpoints[player]
							local dist = math.round(distancia[player] or 0)
							local recordAnterior = recordSesion[player] or 0
							local nuevoRecord = dist > recordAnterior
							recordSesion[player] = math.max(recordAnterior, dist)
							-- Persistir el récord para la próxima sesión (plan §3.3/§4.5)
							dataService.Guardar(player, "record", recordSesion[player])
							local stats = {
								distancia = dist,
								tiempo = math.floor(os.clock() - inicio),
								checkpoint = cp and cp.indice or 0,
								puntos = puntosService.GetPuntos(player),
								record = math.max(recordSesion[player], dist),
								nuevoRecord = nuevoRecord,
							}
							finPartida:FireClient(player, stats)
							alTerminar:Fire(player, stats)
						end
						print("[Match] fin de partida")
					end
				end
			end
		end
	end)

	-- Récord personal persistente vía DataService (plan §3.3/§4.5)
	dataService = require(script.Parent.DataService)
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

	print("[Match] checkpoints activos:", indice)
end

return MatchService
