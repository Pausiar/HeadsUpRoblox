-- ProgresionService: XP y niveles del jugador (fase 11 · L8, C32, plan §3).
-- Servidor autoritativo: la XP solo se suma aquí, escuchando las señales REALES
-- de MatchService (CheckpointAlcanzado, AlTerminar) y PlayerStateService
-- (Reanimado), igual que PuntosService. La XP nunca baja; el nivel se deriva de
-- ProgresionConfig y la recompensa se abona UNA vez al cruzar el umbral
-- (`nivelOtorgado` persiste en el perfil junto a `xp`, campo abierto del
-- esquema v2). Sin Main no hay servicio: Main.server.lua debe requerirlo y
-- llamar a Iniciar() (después de MatchService; PinasService con pcall).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ProgresionConfig = require(ReplicatedStorage.Shared.Config.ProgresionConfig)

local ProgresionService = {}

local xp = {} -- [player] = XP total de la sesión (sembrada del perfil; nunca baja)
local nivelOtorgado = {} -- [player] = último nivel cuya recompensa ya se abonó
local cargados = {} -- [player] = true cuando DataService.AlCargar ya corrió

local remotoProgresion
local dataService -- asignado en Iniciar() con pcall; nil = sin persistencia
local pinasService -- asignado en Iniciar() con pcall; nil = recompensa sin abonar

-- Publica el estado de progresión. `xp` es la XP total acumulada y `xpSiguiente`
-- el umbral acumulado del siguiente nivel (misma escala, apto para «X/Y»).
local function publicar(player, subio)
	local total = xp[player] or 0
	local nivel = ProgresionConfig.NivelDeXp(total)
	remotoProgresion:FireClient(player, {
		nivel = nivel,
		xp = total,
		xpSiguiente = ProgresionConfig.UmbralDe(nivel + 1),
		subio = subio == true,
	})
end

-- Suma XP (nunca resta), persiste y publica. Al cruzar uno o varios umbrales
-- abona la recompensa de cada nivel nuevo UNA vez y lo marca en el perfil.
local function sumar(player, cantidad, motivo)
	if dataService and not cargados[player] then
		return -- antes de AlCargar no se lleva XP (patrón de PinasService)
	end
	if type(cantidad) ~= "number" or cantidad <= 0 then
		return
	end
	local total = (xp[player] or 0) + math.floor(cantidad)
	xp[player] = total
	if dataService then
		dataService.Guardar(player, "xp", total)
	end
	print("[Progresion] +" .. math.floor(cantidad) .. " XP (" .. motivo .. ") a "
		.. player.Name .. ": total " .. total)

	local nivel = ProgresionConfig.NivelDeXp(total)
	local otorgado = nivelOtorgado[player] or 0
	if nivel > otorgado then
		local recompensa = 0
		for n = otorgado + 1, nivel do
			recompensa += ProgresionConfig.RecompensaPorNivel.PinasPorNivel * n
		end
		nivelOtorgado[player] = nivel
		if dataService then
			dataService.Guardar(player, "nivelOtorgado", nivel)
		end
		if pinasService then
			pinasService.Sumar(player, recompensa) -- publica el saldo por su propio remote
		else
			warn("[Progresion] sin PinasService: recompensa de nivel no abonada")
		end
		print("[Progresion] " .. player.Name .. " sube a nivel " .. nivel
			.. " (recompensa +" .. recompensa .. " Piñas)")
		publicar(player, true)
		return
	end
	publicar(player, false)
end

function ProgresionService.Iniciar()
	remotoProgresion = Remotes.Crear(Remotes.Nombres.Progresion) -- el servidor crea, el cliente espera

	-- Dependencias tolerantes (patrón bengala): si faltan, degradan sin romper.
	local okDatos, resDatos = pcall(require, script.Parent.DataService)
	if okDatos then
		dataService = resDatos
	else
		warn("[Progresion] sin DataService: la XP no se persiste esta sesión")
	end
	local okPinas, resPinas = pcall(require, script.Parent.PinasService)
	if okPinas then
		pinasService = resPinas
	else
		warn("[Progresion] sin PinasService: las recompensas de nivel no se abonan")
	end

	local matchService = require(script.Parent.MatchService)
	local playerState = require(script.Parent.PlayerStateService)

	-- Checkpoints: XP en el momento (solo Historia: la señal solo dispara ahí)
	matchService.CheckpointAlcanzado.Event:Connect(function(player, _indice)
		sumar(player, ProgresionConfig.XPPor.Checkpoint, "checkpoint")
	end)

	-- Reanimar: solo premia a un jugador que reanima a otro (patrón de PuntosService)
	playerState.Reanimado.Event:Connect(function(reanimador, jugador)
		if reanimador and reanimador ~= jugador then
			sumar(reanimador, ProgresionConfig.XPPor.Reanimar, "reanimar")
		end
	end)

	-- Cierre de partida (AlTerminar dispara UNA vez por jugador): XP por distancia
	-- recorrida + meta. Los checkpoints ya se cobraron en su señal: no se relean.
	matchService.AlTerminar.Event:Connect(function(player, stats, _modo)
		if type(stats) ~= "table" then
			return
		end
		local distancia = tonumber(stats.distancia) or 0
		local cantidad = math.floor(distancia / 100) * ProgresionConfig.XPPor.Cada100Studs
		if stats.victoria then
			cantidad += ProgresionConfig.XPPor.Meta
		end
		if cantidad > 0 then
			sumar(player, cantidad, stats.victoria and "meta" or "fin de partida")
		end
	end)

	if dataService then
		-- Carga inicial: sembrar XP y nivelOtorgado sin bajarlos nunca
		local function sembrar(player, datos)
			if type(datos) ~= "table" then
				return
			end
			xp[player] = math.max(xp[player] or 0, tonumber(datos.xp) or 0)
			nivelOtorgado[player] = math.max(
				nivelOtorgado[player] or 0,
				tonumber(datos.nivelOtorgado) or 0
			)
			cargados[player] = true
			publicar(player, false)
		end
		dataService.AlCargar.Event:Connect(sembrar)
		-- Carrera: el perfil pudo cargar antes de conectar AlCargar
		for _, player in ipairs(Players:GetPlayers()) do
			sembrar(player, dataService.Obtener(player))
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		xp[player] = nil
		nivelOtorgado[player] = nil
		cargados[player] = nil
	end)

	print("[Progresion] servicio listo: XP por checkpoint/meta/reanimar/distancia, +"
		.. ProgresionConfig.RecompensaPorNivel.PinasPorNivel .. "×nivel Piñas por nivel")
end

-- Nivel de la sesión (para RankingGlobalService C31: `nivel` del top global).
function ProgresionService.NivelDe(player)
	return ProgresionConfig.NivelDeXp(xp[player] or 0)
end

return ProgresionService
