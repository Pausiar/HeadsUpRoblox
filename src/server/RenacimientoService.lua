-- RenacimientoService (fase 11 · L5b): sistema de renacimiento. Petición del
-- jugador: «que te permita ganar más puntos de base y que aguante un poco más
-- la velocidad». Renacer consume metas (victorias): 10 × (renacimientos + 1) —
-- y otorga buffs permanentes: +10 % en puntos base y −5 % de drenaje de estamina
-- por renacer (cap 5 renacimientos). NO borra nada del progreso: las metas
-- totales de estadisticas.metas siguen su curso; el requisito se cuenta con un
-- contador propio persistido en DataService: renacimientos = { conteo, metasContadas }.
-- Esquema v2 (E45): campo nuevo, la fusión de DataService lo recupera solo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.RenacimientoConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local RenacimientoService = {}
local estados = {} -- [player] = { conteo = n, metasContadas = m }
local cargados = {} -- [player] = true cuando DataService ya cargó el perfil

local remotoEstado
local dataService -- asignado en Iniciar() con pcall; nil = sin persistencia
local permitirRenacer

-- Metas que cuesta el siguiente renacer: 10 × (renacimientos + 1)
local function metasPara(conteo)
	return Config.MetasBase * (conteo + 1)
end

-- Publica el estado del jugador: al propio jugador (su HUD de progreso) y, en el
-- renacer, a todos (los buffs son visibles). El campo `jugador` permite al cliente
-- atribuir el estado cuando llega por broadcast (mismo patrón que Caidas.nombre).
local function publicar(player, aTodos)
	local st = estados[player]
	local conteo = (st and st.conteo) or 0
	local metas = (st and st.metasContadas) or 0
	local payload = {
		jugador = player.Name,
		renacimientos = conteo,
		metas = metas,
		faltan = math.max(0, metasPara(conteo) - metas),
		multPuntos = 1 + Config.BonusPuntosPorRenacer * conteo,
		aguante = Config.BonusAguantePorRenacer * conteo,
	}
	if aTodos then
		remotoEstado:FireAllClients(payload)
	else
		remotoEstado:FireClient(player, payload)
	end
end

-- Limpia y siembra el estado desde el perfil persistido (AlCargar y barrido de
-- carrera). Clamp del conteo al cap: un cap bajado en config no rompe sesiones.
local function sembrar(player, datos)
	local ren = type(datos) == "table" and type(datos.renacimientos) == "table" and datos.renacimientos or nil
	estados[player] = {
		conteo = math.clamp(math.floor(tonumber(ren and ren.conteo) or 0), 0, Config.MaxRenacimientos),
		metasContadas = math.max(0, math.floor(tonumber(ren and ren.metasContadas) or 0)),
	}
	publicar(player)
end

-- Persiste el contador propio (autoguardado lo escribe en ≤60 s). Antes de
-- AlCargar no se toca: la caché vacía pisaría lo guardado al fusionar.
local function guardar(player)
	local st = estados[player]
	if dataService and cargados[player] and st then
		dataService.Guardar(player, "renacimientos", { conteo = st.conteo, metasContadas = st.metasContadas })
	end
end

function RenacimientoService.Iniciar()
	remotoEstado = Remotes.Crear(Remotes.Nombres.RenacimientoEstado)
	permitirRenacer = RateLimiter.nuevo(1) -- el renacer es raro; 1 s solo frena spam

	local okDatos, resDatos = pcall(require, script.Parent.DataService)
	if okDatos then
		dataService = resDatos
	else
		warn("[Renacer] sin DataService: el renacimiento no se persiste esta sesión")
	end

	-- MatchService perezoso dentro de Iniciar (patrón de PinasService): PuntosService
	-- y EstaminaService requieren este módulo, y MatchService los requiere a ellos.
	-- Cargar MatchService aquí arriba rompería el ciclo en el arranque.
	local matchService = require(script.Parent.MatchService)
	matchService.AlTerminar.Event:Connect(function(player, stats)
		-- La meta para renacer es ganar la partida: 1 victoria = 1 meta contada
		-- (las metas totales de estadisticas.metas las lleva MatchService por su cuenta).
		if stats and stats.victoria == true then
			local st = estados[player]
			-- Sin DataService no hay sembrado real: cuenta en sesión igual que las Piñas
			if st and (dataService == nil or cargados[player]) then
				st.metasContadas += 1
				guardar(player)
				publicar(player)
			end
		end
	end)

	-- Renacer: consume el requisito del siguiente nivel y sube los buffs.
	local remotoRenacer = Remotes.Crear(Remotes.Nombres.Renacer)
	remotoRenacer.OnServerEvent:Connect(function(player)
		if not permitirRenacer(player) then
			return
		end
		local st = estados[player]
		if not st or not cargados[player] then
			return
		end
		if st.conteo >= Config.MaxRenacimientos or st.metasContadas < metasPara(st.conteo) then
			return
		end
		st.conteo += 1
		st.metasContadas = 0
		guardar(player)
		publicar(player, true)
		print("[Renacer] " .. player.Name .. " renace (" .. st.conteo .. " total): +10% puntos, +5% aguante")
	end)

	Players.PlayerRemoving:Connect(function(player)
		estados[player] = nil
		cargados[player] = nil
	end)

	if dataService then
		-- Carga inicial: sembrar { conteo, metasContadas } y publicar el progreso
		dataService.AlCargar.Event:Connect(function(player, datos)
			cargados[player] = true
			sembrar(player, datos)
		end)
		-- Carrera: los datos pueden haber cargado antes de conectar AlCargar
		for _, player in ipairs(Players:GetPlayers()) do
			local datos = dataService.Obtener(player)
			if type(datos) == "table" and datos.schema ~= nil then
				cargados[player] = true
				sembrar(player, datos)
			end
		end
	end

	print("[Renacer] servicio listo: " .. Config.MetasBase .. " metas × nivel, +"
		.. (Config.BonusPuntosPorRenacer * 100) .. "% puntos, −"
		.. (Config.BonusAguantePorRenacer * 100) .. "% drenaje, cap " .. Config.MaxRenacimientos)
end

-- Nivel actual del jugador (para HUD y QA); 0 antes de cargar.
function RenacimientoService.Renacimientos(player)
	local st = estados[player]
	return (st and st.conteo) or 0
end

-- Puntos base ×(1 + 0.10 × renacimientos). Solo puntos de base: checkpoint y
-- reanimar; los bonus de meta (Piñas) no se tocan.
function RenacimientoService.MultiplicadorPuntos(player)
	return 1 + Config.BonusPuntosPorRenacer * RenacimientoService.Renacimientos(player)
end

-- Aguante: fracción de drenaje que se descuenta (0.05 × renacimientos, máx 0.25).
function RenacimientoService.Aguante(player)
	return Config.BonusAguantePorRenacer * RenacimientoService.Renacimientos(player)
end

return RenacimientoService
