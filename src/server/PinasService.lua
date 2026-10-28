-- PinasService: moneda blanda «Las Piñas» (plan §4.5/§7: se ganan jugando y
-- compran cosméticos). Servidor autoritativo: las Piñas solo se ganan aquí,
-- escuchando AlTerminar de MatchService; la persistencia corre a cargo de
-- DataService. NOTA: gastarlas llega con la tienda (fase 5); hoy solo se acumulan.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TelemetriaConfig = require(ReplicatedStorage.Shared.Config.TelemetriaConfig)

-- Reglas de ganancia (plan §4.5): al cerrar la partida, 1 Piña por cada N studs
-- de distancia máxima alcanzada (redondeo abajo) y un bonus fijo por récord
-- personal nuevo. Los checkpoints NO dan Piñas: solo puntos (PuntosService).
local STUDIOS_POR_PINA = 10 -- math.floor(distancia / 10)
local BONUS_RECORD = 25 -- Piñas extra cuando stats.nuevoRecord es true

local PinasService = {}
local pinas = {} -- [player] = total del jugador (sesión; se siembra desde DataService)

local remotoPinas
local dataService -- asignado en Iniciar() con pcall; nil = sin persistencia
local telemetriaService

-- Publica el total sin ganancia: siembra el saldo del HUD y de la tienda al entrar.
local function publicar(player, ganadas)
	remotoPinas:FireClient(player, { pinas = pinas[player] or 0, ganadas = ganadas or 0 })
end

-- Nunca baja un total ya alcanzado (mismo patrón que el récord en MatchService)
local function aplicarPinasGuardadas(player, valor)
	if type(valor) == "number" then
		pinas[player] = math.max(pinas[player] or 0, valor)
	end
end

function PinasService.Iniciar()
	remotoPinas = Remotes.Crear(Remotes.Nombres.Pinas) -- el servidor crea, el cliente espera

	-- DataService puede no existir aún en una fase temprana: require con pcall
	local ok, res = pcall(function()
		return require(script.Parent.DataService)
	end)
	if ok then
		dataService = res
	else
		warn("[Pinas] sin DataService: las Piñas no se persisten esta sesión")
	end

	-- Fin de partida: calcular ganadas, sumar, persistir y publicar
	local matchService = require(script.Parent.MatchService)
	telemetriaService = require(script.Parent.TelemetriaService)
	matchService.AlTerminar.Event:Connect(function(player, stats)
		local dist = tonumber(stats and stats.distancia) or 0
		local ganadas = math.floor(dist / STUDIOS_POR_PINA)
		if stats and stats.nuevoRecord then
			ganadas += BONUS_RECORD
		end
		-- Multiplicador x2 de monetización: require perezoso dentro del handler
		-- para no acoplar el arranque de PinasService a MonetizacionService.
		local multiplicador = 1
		local ok, monetizacion = pcall(require, script.Parent.MonetizacionService)
		if ok and monetizacion then
			multiplicador = monetizacion.MultiplicadorPinas(player)
		end
		ganadas = ganadas * multiplicador
		pinas[player] = (pinas[player] or 0) + ganadas
		if dataService then
			dataService.Guardar(player, "pinas", pinas[player])
		end
		remotoPinas:FireClient(player, { pinas = pinas[player], ganadas = ganadas, multiplicador = multiplicador })
		if telemetriaService then
			telemetriaService.Economia(player, true, ganadas, pinas[player],
				TelemetriaConfig.Economia.FuentePartida, "pinas_partida")
		end
		print("[Pinas] +" .. ganadas .. " a " .. player.Name .. ": total " .. pinas[player])
	end)

	if dataService then
		-- Carga inicial: sembrar el total persistido sin bajarlo nunca
		dataService.AlCargar.Event:Connect(function(player, datos)
			if type(datos) == "table" then
				aplicarPinasGuardadas(player, datos.pinas)
			end
			publicar(player)
		end)
		-- Carrera: los datos pueden haber cargado antes de conectar AlCargar
		for _, player in Players:GetPlayers() do
			local datos = dataService.Obtener(player)
			if type(datos) == "table" then
				aplicarPinasGuardadas(player, datos.pinas)
			end
			publicar(player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		pinas[player] = nil
	end)

	print("[Pinas] servicio listo: " .. STUDIOS_POR_PINA .. " studs/Piña, +" .. BONUS_RECORD .. " por récord")
end

function PinasService.GetPinas(player)
	return pinas[player] or 0
end

-- Gasto de la tienda (plan §7): el SERVIDOR decide si hay saldo y descuenta.
-- Devuelve true si se completó el gasto. Publica el total actualizado.
function PinasService.Gastar(player, cantidad)
	if type(cantidad) ~= "number" or cantidad <= 0 then
		return false
	end
	local total = pinas[player] or 0
	if total < cantidad then
		return false
	end
	pinas[player] = total - cantidad
	if dataService then
		dataService.Guardar(player, "pinas", pinas[player])
	end
	remotoPinas:FireClient(player, { pinas = pinas[player], ganadas = 0 })
	return true
end

return PinasService
