-- TelemetriaService: eventos y embudo de AnalyticsService (plan §9 fase 6).
-- Servidor autoritativo y sin datos personales: solo nombres estables de evento y
-- contadores; nunca nombres de jugador ni texto libre. Toda llamada a AnalyticsService
-- va en pcall: si la API falla en Studio se avisa una vez y el juego sigue. Con
-- TelemetriaConfig.Activo ~= true no se envía nada.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local TelemetriaConfig = require(ReplicatedStorage.Shared.Config.TelemetriaConfig)

local TelemetriaService = {}

local activo = false
local iniciado = false
local avisado = false
local sinApi = false
local sesiones = {} -- [player] = id de sesión del embudo (sin datos personales)
local pasos = {} -- [player] = último paso del embudo emitido

-- nombre -> número de paso, para no repetir el orden del embudo en cada hook
local pasosPorNombre = {}
for _, paso in ipairs(TelemetriaConfig.Funnel.Pasos) do
	pasosPorNombre[paso.nombre] = paso.paso
end

-- Solo se envían eventos declarados en Config: nunca texto libre de un llamador.
local eventosValidos = {}
for _, nombre in pairs(TelemetriaConfig.Eventos) do
	eventosValidos[nombre] = true
end

-- El remoto del cliente solo admite el subconjunto de UI (E46).
local eventosUIValidos = {}
for nombre in pairs(TelemetriaConfig.EventosUI) do
	eventosUIValidos[nombre] = true
end

local function jugadorValido(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent ~= nil
end

local function estaActiva()
	return activo and TelemetriaConfig.Activo == true
end

local function avisarFallo(err)
	if avisado then
		return
	end
	avisado = true
	warn("[Telemetria] AnalyticsService no disponible: " .. tostring(err) .. "; se sigue jugando")
end

-- Un fallo de Analytics nunca debe romper la partida ni repetir el warn: tras el
-- primer error se deja de intentar durante esta sesión.
local function llamar(metodo, ...)
	if sinApi then
		return
	end
	local fn = AnalyticsService and AnalyticsService[metodo]
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, AnalyticsService, ...)
	if not ok then
		sinApi = true
		avisarFallo(err)
	end
end

local function nuevaSesion()
	local servidor = game.JobId
	if type(servidor) ~= "string" or servidor == "" then
		servidor = "studio" -- JobId vacío en Studio; no es dato personal
	end
	return ("%s-%d-%d"):format(servidor, os.time(), math.random(100000, 999999))
end

local function evento(player, nombre)
	if not estaActiva() or not jugadorValido(player) then
		return
	end
	if type(nombre) ~= "string" or not eventosValidos[nombre] then
		return
	end
	-- En Studio Analytics no siempre acepta eventos: la consola deja la evidencia del QA.
	if RunService:IsStudio() then
		print("[Telemetria] " .. nombre .. " · " .. player.Name)
	end
	llamar("LogCustomEvent", player, nombre, 1)
end

-- Cada paso se emite una sola vez por jugador y sesión de servidor. No se exige
-- llegar al paso anterior: si una señal falta, el embudo muestra el salto.
local function pasoEmbudo(player, nombre)
	if not estaActiva() or not jugadorValido(player) then
		return
	end
	local paso = pasosPorNombre[nombre]
	if not paso then
		return
	end
	local anterior = pasos[player] or 0
	if paso <= anterior then
		return
	end
	pasos[player] = paso -- se registra antes de enviar: nunca se duplica el paso
	if RunService:IsStudio() then
		print("[Telemetria] embudo " .. paso .. " · " .. nombre .. " · " .. player.Name)
	end

	local sesion = sesiones[player]
	if not sesion then
		sesion = nuevaSesion()
		sesiones[player] = sesion
	end
	llamar("LogFunnelStepEvent", player, TelemetriaConfig.Funnel.Nombre, sesion, paso, nombre)
end

-- Economía de Piñas: esIngreso=true para ganadas, false para gastadas. itemSku es
-- un identificador del catálogo o de la fuente, nunca texto escrito por el jugador.
local function economia(player, esIngreso, cantidad, saldo, tipoTransaccion, itemSku)
	if not estaActiva() or not jugadorValido(player) then
		return
	end
	if type(cantidad) ~= "number" or cantidad <= 0 or type(saldo) ~= "number" then
		return
	end
	if type(tipoTransaccion) ~= "string" or tipoTransaccion == "" then
		return
	end
	if type(itemSku) ~= "string" or itemSku == "" then
		return
	end
	local tipoFlujo = Enum.AnalyticsEconomyFlowType
	if tipoFlujo == nil then
		return
	end
	local flujo = tipoFlujo.Source
	if not esIngreso then
		flujo = tipoFlujo.Sink
	end
	llamar(
		"LogEconomyEvent",
		player,
		flujo,
		TelemetriaConfig.Economia.Moneda,
		math.floor(cantidad),
		math.floor(saldo),
		tipoTransaccion,
		itemSku
	)
end

function TelemetriaService.Iniciar()
	if iniciado then
		return
	end
	iniciado = true
	if TelemetriaConfig.Activo ~= true then
		print("[Telemetria] desactivada por TelemetriaConfig.Activo")
		return
	end
	activo = true

	-- Main llama a Iniciar() de los demás servicios antes que a este.
	local matchService = require(script.Parent.MatchService)
	local playerState = require(script.Parent.PlayerStateService)
	local dataService = require(script.Parent.DataService)

	-- Entrar al servidor ya es el primer paso del embudo; los que ya estaban, también.
	local function alEntrar(player)
		pasoEmbudo(player, "Lobby")
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, player in ipairs(Players:GetPlayers()) do
		alEntrar(player)
	end

	matchService.AlEmpezar.Event:Connect(function(jugadores)
		for _, player in ipairs(jugadores or {}) do
			evento(player, TelemetriaConfig.Eventos.PartidaInicio)
			-- Respaldo si el jugador ya estaba dentro cuando arrancó la telemetría.
			pasoEmbudo(player, "Lobby")
			-- No hay señal de entrada a la etapa: empezar la partida es entrar en la 1.
			pasoEmbudo(player, "PrimeraEtapa")
		end
	end)

	matchService.AlTerminar.Event:Connect(function(player, _stats, modo)
		-- E46: el cierre se separa por modo; sin modo (llamada antigua) queda el genérico.
		local nombre = TelemetriaConfig.Eventos.PartidaFin
		if modo == "historia" then
			nombre = TelemetriaConfig.Eventos.PartidaFinHistoria
		elseif modo == "rapida" then
			nombre = TelemetriaConfig.Eventos.PartidaFinRapida
		end
		evento(player, nombre)
		pasoEmbudo(player, "PartidaCompletada")
	end)

	matchService.CheckpointAlcanzado.Event:Connect(function(player)
		evento(player, TelemetriaConfig.Eventos.Checkpoint)
		pasoEmbudo(player, "PrimerCheckpoint")
	end)

	playerState.Reanimado.Event:Connect(function(reanimador, player)
		-- Sin reanimador es la reanimación personal de monetización: no es cooperativa.
		if jugadorValido(reanimador) then
			evento(player, TelemetriaConfig.Eventos.Reanimacion)
		end
	end)

	-- E46: fallo de lectura del perfil (la sesión no persistirá); uno por jugador.
	dataService.AlFallar.Event:Connect(function(player)
		evento(player, TelemetriaConfig.Eventos.DatosFallo)
	end)

	-- E46: apertura de tienda y pestaña desde el cliente, con lista blanca y límite.
	local permitirUI = RateLimiter.nuevo(0.25)
	local remotoUI = Remotes.Crear(Remotes.Nombres.TelemetriaUI)
	remotoUI.OnServerEvent:Connect(function(player, nombre)
		if type(nombre) ~= "string" or not eventosUIValidos[nombre] then
			return
		end
		if not permitirUI(player) then
			return
		end
		evento(player, nombre)
	end)

	Players.PlayerRemoving:Connect(function(player)
		sesiones[player] = nil
		pasos[player] = nil
	end)

	print("[Telemetria] activa: embudo " .. TelemetriaConfig.Funnel.Nombre
		.. " con " .. #TelemetriaConfig.Funnel.Pasos .. " pasos")
end

TelemetriaService.Evento = evento
TelemetriaService.Economia = economia

return TelemetriaService
