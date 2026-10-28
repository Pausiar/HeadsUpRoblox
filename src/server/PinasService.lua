-- PinasService: moneda blanda «Las Piñas» (plan §4.5/§7: se ganan caminando y
-- compran cosméticos, bebidas y mejoras). Servidor autoritativo: las Piñas solo
-- se ganan aquí; el saldo, el gasto de la tienda y la persistencia corren por
-- DataService. La distancia la publica MatchService en el atributo "Distancia".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local TelemetriaConfig = require(ReplicatedStorage.Shared.Config.TelemetriaConfig)

-- Reglas de ganancia (plan §4.5): 1 Piña por cada 20 studs caminados, pagadas en
-- vivo (1 Hz) con el atributo Distancia de MatchService. Al cerrar la partida solo
-- quedan los bonus: +25 por récord personal y +BonusPinas por llegar a la meta.
-- Los checkpoints NO dan Piñas: solo puntos (PuntosService).
local STUDS_POR_PINA = 20
local BONUS_RECORD = 25 -- Piñas extra cuando stats.nuevoRecord es true
local INTERVALO_TANDA = 1 -- s entre lecturas de Distancia (throttle de publicación)

local PinasService = {}
local pinas = {} -- [player] = total del jugador (sesión; se siembra desde DataService)
local recorrido = {} -- [player] = studs acumulados desde la última Piña pagada
local ultimaDistancia = {} -- [player] = último valor del atributo Distancia

local remotoPinas
local dataService -- asignado en Iniciar() con pcall; nil = sin persistencia
local telemetriaService
local cargados = {} -- [player] = true cuando DataService.AlCargar ya corrió

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

-- x2 de monetización y +25 % por nivel del Ojo de lince. require perezoso con
-- pcall dentro del tick para no acoplar el arranque (TiendaService.Iniciar corre
-- después; para entonces el atributo MonedasMult ya existe).
local function multiplicador(player)
	local total = 1
	local okMon, monetizacion = pcall(require, script.Parent.MonetizacionService)
	if okMon and monetizacion then
		total *= monetizacion.MultiplicadorPinas(player)
	end
	local okTienda, tienda = pcall(require, script.Parent.TiendaService)
	if okTienda and tienda then
		total *= tienda.MultiplicadorMonedas(player)
	end
	return total
end

-- Tanda de caminata: paga las Piñas completas acumuladas y deja el resto para la
-- siguiente. Redondea UNA vez, después de aplicar los dos multiplicadores.
local function pagarCaminata(player, studs)
	recorrido[player] = (recorrido[player] or 0) + studs
	local base = math.floor(recorrido[player] / STUDS_POR_PINA)
	if base <= 0 then
		return
	end
	recorrido[player] -= base * STUDS_POR_PINA
	local ganadas = math.round(base * multiplicador(player))
	pinas[player] = (pinas[player] or 0) + ganadas
	if dataService then
		dataService.Guardar(player, "pinas", pinas[player])
	end
	remotoPinas:FireClient(player, { pinas = pinas[player], ganadas = ganadas })
	if telemetriaService then
		telemetriaService.Economia(player, true, ganadas, pinas[player],
			TelemetriaConfig.Economia.FuentePartida, "pinas_caminar")
	end
	print("[Pinas] +" .. ganadas .. " por caminar a " .. player.Name .. ": total " .. pinas[player])
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

	-- Fin de partida: solo bonus (caminar ya se pagó en vivo), persistir y publicar
	local matchService = require(script.Parent.MatchService)
	telemetriaService = require(script.Parent.TelemetriaService)
	matchService.AlTerminar.Event:Connect(function(player, stats)
		local ganadas = 0
		if stats and stats.nuevoRecord then
			ganadas += BONUS_RECORD
		end
		if stats and stats.victoria then
			ganadas += Config.Etapa0.Meta.BonusPinas
		end
		if ganadas <= 0 then
			publicar(player) -- sin bonus el total no cambia; el HUD/tienda reciben el saldo
			return
		end
		-- El x2 de monetización también cubre los bonus de fin de partida.
		local factor = 1
		local okMon, monetizacion = pcall(require, script.Parent.MonetizacionService)
		if okMon and monetizacion then
			factor = monetizacion.MultiplicadorPinas(player)
		end
		ganadas = math.round(ganadas * factor)
		pinas[player] = (pinas[player] or 0) + ganadas
		if dataService then
			dataService.Guardar(player, "pinas", pinas[player])
		end
		remotoPinas:FireClient(player, { pinas = pinas[player], ganadas = ganadas, multiplicador = factor })
		if telemetriaService then
			telemetriaService.Economia(player, true, ganadas, pinas[player],
				TelemetriaConfig.Economia.FuentePartida, "pinas_partida")
		end
		print("[Pinas] +" .. ganadas .. " de bonus a " .. player.Name .. ": total " .. pinas[player])
	end)

	-- Ganancia en vivo al caminar: 1 Hz, una publicación como máximo por jugador y
	-- segundo. Si Distancia baja (partida nueva), se reinicia el acumulador sin
	-- devolver Piñas negativas.
	task.spawn(function()
		while true do
			task.wait(INTERVALO_TANDA)
			for _, player in ipairs(Players:GetPlayers()) do
				-- Antes de AlCargar no se toca el saldo: Guardar escribiría en la caché
				-- y el merge de DataService descartaría las Piñas persistidas.
				if dataService and not cargados[player] then
					continue
				end
				local distancia = tonumber(player:GetAttribute("Distancia"))
				if distancia then
					local anterior = ultimaDistancia[player]
					ultimaDistancia[player] = distancia
					if anterior and distancia >= anterior then
						pagarCaminata(player, distancia - anterior)
					else
						recorrido[player] = 0
					end
				end
			end
		end
	end)

	if dataService then
		-- Carga inicial: sembrar el total persistido sin bajarlo nunca
		dataService.AlCargar.Event:Connect(function(player, datos)
			cargados[player] = true
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
		recorrido[player] = nil
		ultimaDistancia[player] = nil
		cargados[player] = nil
	end)

	print("[Pinas] servicio listo: 1 Piña/" .. STUDS_POR_PINA .. " studs caminados, +" .. BONUS_RECORD
		.. " por récord, +" .. Config.Etapa0.Meta.BonusPinas .. " por meta")
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
