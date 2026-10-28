-- LobbyService: lobby formal de 2–8 jugadores (plan §4.1 y §9 fase 2).
-- Servidor autoritativo: listo, host, modo, cuenta atrás e inicio se deciden aquí.
-- No depende de la UI ni de DataService: publica LobbyEstado y la UI dibuja.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyConfig = require(ReplicatedStorage.Shared.Config.LobbyConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local LobbyService = {}

local fase = "esperando" -- "esperando" | "cuenta" | "partida" | "resultados"
local modo = LobbyConfig.ModoPorDefecto
local participantes = {} -- array por orden de llegada; [1] = host
local enLobby = {} -- [player] = true si está en participantes
local listos = {} -- [player] = true
local cuenta = nil -- segundos restantes o nil
local tokenCuenta = 0 -- invalida bucles de cuenta atrás antiguos
local tokenResultados = 0 -- invalida vueltas al lobby antiguas
local matchService -- asignado en Iniciar() con pcall

local remotoEstado, remotoListo, remotoModo, remotoComenzar

local function minimo()
	if RunService:IsStudio() and LobbyConfig.PermitirSoloEnStudio then
		return 1 -- playtest del MCP con un solo jugador
	end
	return LobbyConfig.MinJugadores
end

local function esParticipante(player)
	return enLobby[player] == true
end

local function host()
	return participantes[1]
end

local function puedeEmpezar()
	if fase ~= "esperando" and fase ~= "cuenta" then
		return false
	end
	if #participantes < minimo() then
		return false
	end
	for _, player in ipairs(participantes) do
		if not listos[player] then
			return false
		end
	end
	return true
end

-- Host primero y luego por nombre (el payload no expone Player, solo datos)
local function listarJugadores(hostActual)
	local filas = {}
	for _, player in ipairs(participantes) do
		if player.Parent then
			table.insert(filas, {
				player = player,
				nombre = player.DisplayName,
				listo = listos[player] == true,
				host = player == hostActual,
			})
		end
	end
	table.sort(filas, function(a, b)
		if a.host ~= b.host then
			return a.host
		end
		local na, nb = string.lower(a.nombre), string.lower(b.nombre)
		if na ~= nb then
			return na < nb
		end
		return a.player.UserId < b.player.UserId
	end)
	return filas
end

local function mensajePara(player)
	if esParticipante(player) then
		return nil
	end
	if fase == "partida" or fase == "resultados" then
		return "Partida en curso"
	end
	return ("Lobby lleno (%d/%d) · espectador"):format(#participantes, LobbyConfig.MaxJugadores)
end

-- FireClient individual: `tu` se calcula por receptor (nunca FireAllClients)
local function publicar()
	if not remotoEstado then
		return
	end
	local hostActual = host()
	local filas = listarJugadores(hostActual)
	for _, receptor in ipairs(Players:GetPlayers()) do
		local jugadores = {}
		for _, fila in ipairs(filas) do
			table.insert(jugadores, {
				nombre = fila.nombre,
				listo = fila.listo,
				host = fila.host,
				tu = fila.player == receptor,
			})
		end
		remotoEstado:FireClient(receptor, {
			fase = fase,
			jugadores = jugadores,
			modo = modo,
			min = minimo(),
			max = LobbyConfig.MaxJugadores,
			cuenta = cuenta,
			host = hostActual and hostActual.DisplayName or nil,
			puedeEmpezar = puedeEmpezar(),
			mensaje = mensajePara(receptor),
		})
	end
end

local function agregarParticipante(player)
	if enLobby[player] or not player.Parent then
		return false
	end
	if #participantes >= LobbyConfig.MaxJugadores then
		return false
	end
	enLobby[player] = true
	listos[player] = false
	table.insert(participantes, player)
	return true
end

local function quitarParticipante(player)
	if not enLobby[player] then
		return false
	end
	enLobby[player] = nil
	listos[player] = nil
	local indice = table.find(participantes, player)
	if indice then
		table.remove(participantes, indice)
	end
	return true
end

-- Completa huecos con espectadores (los que llegaron con el lobby lleno)
local function rellenarParticipantes(excluir)
	for _, player in ipairs(Players:GetPlayers()) do
		if #participantes >= LobbyConfig.MaxJugadores then
			break
		end
		if player ~= excluir then
			agregarParticipante(player)
		end
	end
end

local function cancelarCuenta()
	tokenCuenta += 1
	cuenta = nil
end

local iniciarPartida -- se define antes del bucle de cuenta atrás

local function empezarCuenta()
	if fase ~= "esperando" and fase ~= "cuenta" then
		return
	end
	if not puedeEmpezar() then
		return
	end
	tokenCuenta += 1
	local miToken = tokenCuenta
	fase = "cuenta"
	cuenta = LobbyConfig.CuentaAtras
	publicar()
	print("[Lobby] cuenta atrás:", LobbyConfig.CuentaAtras)

	task.spawn(function()
		while miToken == tokenCuenta and cuenta and cuenta > 0 do
			task.wait(1)
			if miToken ~= tokenCuenta or not cuenta then
				return
			end
			cuenta -= 1
			if cuenta <= 0 then
				cuenta = nil
				iniciarPartida()
				return
			end
			publicar()
		end
	end)
end

iniciarPartida = function()
	if not puedeEmpezar() then
		if fase == "cuenta" then
			cancelarCuenta()
			fase = "esperando"
			publicar()
		end
		return false
	end
	if not matchService then
		warn("[Lobby] sin MatchService: no se puede iniciar la partida")
		cancelarCuenta()
		fase = "esperando"
		publicar()
		return false
	end

	local roster = {}
	for _, player in ipairs(participantes) do
		if player.Parent then
			table.insert(roster, player)
		end
	end
	if #roster < minimo() then
		cancelarCuenta()
		fase = "esperando"
		publicar()
		return false
	end

	cancelarCuenta()
	local semilla = modo == "rapida" and os.time() or nil
	local ok = matchService.IniciarPartida(roster, modo, semilla)
	if ok then
		-- AlEmpezar deja la fase en "partida"; se fuerza si el evento no llegó
		if fase ~= "partida" then
			fase = "partida"
			publicar()
		end
		print("[Lobby] partida iniciada:", modo, "con", #roster, "jugadores")
	else
		fase = "esperando"
		publicar()
		warn("[Lobby] MatchService rechazó el inicio de la partida")
	end
	return ok
end

-- Cualquier cambio revalida la cuenta atrás; con token, nunca quedan dos bucles
local function evaluarCuenta()
	if fase == "cuenta" then
		if puedeEmpezar() then
			empezarCuenta() -- contador nuevo si cambió el número de listos
		else
			cancelarCuenta()
			fase = "esperando"
			publicar()
		end
	elseif fase == "esperando" then
		if puedeEmpezar() then
			empezarCuenta()
		else
			publicar()
		end
	else
		publicar()
	end
end

local function cambiarListo(player, valor)
	if not esParticipante(player) then
		return false
	end
	if fase ~= "esperando" and fase ~= "cuenta" then
		return false
	end
	if listos[player] == valor then
		return false
	end
	listos[player] = valor
	print("[Lobby]", player.Name, valor and "listo" or "no listo")
	evaluarCuenta()
	return true
end

local function volverAlLobby()
	tokenResultados += 1
	cancelarCuenta()
	fase = "esperando"
	if matchService then
		matchService.PrepararLobby() -- limpia EnJuego y teletransporta al spawn del lobby
	end
	listos = {}
	enLobby = {}
	participantes = {}
	rellenarParticipantes() -- los espectadores entran ahora en el lobby
	for _, player in ipairs(participantes) do
		listos[player] = false
	end
	publicar()
	print("[Lobby] vuelta al lobby con", #participantes, "jugadores")
end

local function alEmpezar(_jugadores, modoPartida, semilla)
	if LobbyConfig.EsModoValido(modoPartida) then
		modo = modoPartida
	end
	fase = "partida"
	cancelarCuenta()
	tokenResultados += 1 -- REINTENTAR durante los resultados cancela la vuelta
	publicar()
	print("[Lobby] fase partida:", modoPartida, semilla and ("semilla " .. tostring(semilla)) or "sin semilla")
end

local function alTerminarPartida()
	fase = "resultados"
	cancelarCuenta()
	tokenResultados += 1
	local miToken = tokenResultados
	publicar()
	print("[Lobby] resultados: vuelta al lobby en", LobbyConfig.EsperaResultados, "s")
	task.delay(LobbyConfig.EsperaResultados, function()
		if miToken ~= tokenResultados then
			return
		end
		volverAlLobby()
	end)
end

function LobbyService.Iniciar()
	remotoEstado = Remotes.Crear(Remotes.Nombres.LobbyEstado)
	remotoListo = Remotes.Crear(Remotes.Nombres.Listo)
	remotoModo = Remotes.Crear(Remotes.Nombres.CambiarModo)
	remotoComenzar = Remotes.Crear(Remotes.Nombres.Comenzar)

	local ok, res = pcall(require, script.Parent.MatchService)
	if ok and type(res) == "table" then
		matchService = res
		matchService.AlEmpezar.Event:Connect(alEmpezar)
		matchService.AlTerminarPartida.Event:Connect(alTerminarPartida)
	else
		warn("[Lobby] sin MatchService: no se podrán iniciar partidas (" .. tostring(res) .. ")")
	end

	local permitirListo = RateLimiter.nuevo(LobbyConfig.EnfriamientoListo)
	local permitirModo = RateLimiter.nuevo(LobbyConfig.EnfriamientoModo)
	local permitirComenzar = RateLimiter.nuevo(LobbyConfig.EnfriamientoComenzar)

	remotoListo.OnServerEvent:Connect(function(player, valor)
		if not permitirListo(player) then
			return
		end
		if type(valor) ~= "boolean" then
			return
		end
		cambiarListo(player, valor)
	end)

	remotoModo.OnServerEvent:Connect(function(player, nuevoModo)
		if not permitirModo(player) then
			return
		end
		if player ~= host() or fase ~= "esperando" then
			return
		end
		if type(nuevoModo) ~= "string" or not LobbyConfig.EsModoValido(nuevoModo) or nuevoModo == modo then
			return
		end
		modo = nuevoModo
		print("[Lobby] modo:", modo)
		publicar()
	end)

	remotoComenzar.OnServerEvent:Connect(function(player)
		if not permitirComenzar(player) then
			return
		end
		if player ~= host() then
			return
		end
		if fase ~= "esperando" and fase ~= "cuenta" then
			return
		end
		if not puedeEmpezar() then
			return
		end
		iniciarPartida()
	end)

	Players.PlayerAdded:Connect(function(player)
		local agrego = false
		if fase == "esperando" or fase == "cuenta" then
			agrego = agregarParticipante(player)
		end
		if not agrego then
			player:SetAttribute("EnJuego", false) -- espectador hasta la próxima ronda
		end
		if agrego and fase == "cuenta" then
			evaluarCuenta() -- el número de participantes cambió
		else
			publicar()
		end
		-- Primer FireClient puede llegar antes de que el cliente conecte OnClientEvent;
		-- un segundo envío cuando ya hay LocalScripts evita el «Conectando…» eterno.
		task.delay(2, function()
			if player.Parent then
				publicar()
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if quitarParticipante(player) then
			if fase == "esperando" or fase == "cuenta" then
				rellenarParticipantes(player) -- el hueco lo ocupa un espectador
				evaluarCuenta()
			else
				publicar()
			end
		else
			publicar()
		end
	end)

	rellenarParticipantes()
	publicar()

	-- Red de seguridad: un cliente lento puede perder el primer FireClient. Mientras se
	-- espera, un estado cada 5 s mantiene la sala sincronizada (≤8 clientes, coste mínimo).
	task.spawn(function()
		while true do
			task.wait(5)
			if fase == "esperando" or fase == "cuenta" then
				publicar()
			end
		end
	end)

	print(("[Lobby] servicio listo (min %d, max %d)"):format(minimo(), LobbyConfig.MaxJugadores))
end

function LobbyService.GetFase()
	return fase
end

function LobbyService.GetModo()
	return modo
end

function LobbyService.GetParticipantes()
	local copia = {}
	for _, player in ipairs(participantes) do
		if player.Parent then
			table.insert(copia, player)
		end
	end
	return copia
end

return LobbyService
