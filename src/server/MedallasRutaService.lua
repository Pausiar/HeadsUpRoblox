-- MedallasRutaService: medallas visuales por rutas completadas (fase 11 · L5b).
-- NO es C28 (insignias de BadgeService): estas medallas viven solo en el juego.
-- Cada victoria (meta con stats.victoria) suma una ruta; el tier alcanzado es el
-- mayor del config que cubre el contador y SOLO se flexea lo que se ganó.
-- El atributo "MedallaRuta" lo escribe el servidor y replica a todos los
-- clientes: el chip del HudRanking lo lee sin remote extra.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config.MedallasRutaConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local MedallasRutaService = {}
local rutas = {} -- [player] = rutas completadas (victorias)
local equipada = {} -- [player] = id del tier flexeado (o nil)
local ultimoTier = {} -- [player] = id del último tier publicado (para avisar solo subidas)

local remotoEstado
local dataService -- asignado en Iniciar con pcall; nil = sin persistencia

-- Medalla visible: la flexeada o, si nunca flexeó, la más alta ganada.
local function medallaMostrada(player)
	return equipada[player] or Config.TierDe(rutas[player] or 0)
end

local function publicarAtributo(player)
	local mostrada = medallaMostrada(player)
	player:SetAttribute("MedallaRuta", mostrada and mostrada.id or nil)
end

local function publicar(player)
	local tier = Config.TierDe(rutas[player] or 0)
	local mostrada = medallaMostrada(player)
	remotoEstado:FireClient(player, {
		rutas = rutas[player] or 0,
		tier = tier and tier.id,
		equipada = mostrada and mostrada.id,
	})
end

-- Restauración con el patrón de PinasService: lo de la sesión nunca baja
-- (una meta cruzada antes de terminar la carga no se pierde).
local function cargarJugador(player, datos)
	if type(datos) == "table" then
		local guardadas = tonumber(datos.rutasCompletadas)
		if guardadas and guardadas > 0 then
			rutas[player] = math.max(rutas[player] or 0, math.floor(guardadas))
		end
		local guardada = Config.PorId(datos.medallaEquipada)
		if guardada and (rutas[player] or 0) >= guardada.rutas then
			equipada[player] = guardada.id
		elseif datos.medallaEquipada ~= nil and equipada[player] == nil then
			-- Guardado corrupto o tier ya no válido: limpiar el campo persistido.
			if dataService then
				dataService.Guardar(player, "medallaEquipada", nil)
			end
		end
	end
	local tier = Config.TierDe(rutas[player] or 0)
	ultimoTier[player] = tier and tier.id
	publicarAtributo(player)
	publicar(player)
end

function MedallasRutaService.Iniciar()
	remotoEstado = Remotes.Crear(Remotes.Nombres.MedallaRutaEstado) -- el servidor crea, el cliente espera
	local remotoEquipar = Remotes.Crear(Remotes.Nombres.MedallaRutaEquipar)

	-- DataService puede no existir aún en una fase temprana: require con pcall
	local ok, res = pcall(function()
		return require(script.Parent.DataService)
	end)
	if ok then
		dataService = res
	else
		warn("[MedallaRuta] sin DataService: las medallas no se persisten esta sesión")
	end

	-- Flexear: solo tiers ya alcanzados (nada de compra ni de azar); persiste y
	-- replica el atributo para el chip del ranking.
	local permitirEquipar = RateLimiter.nuevo(1)
	remotoEquipar.OnServerEvent:Connect(function(player, payload)
		if not permitirEquipar(player) then
			return
		end
		local tier = Config.PorId(type(payload) == "table" and payload.id or nil)
		if not tier or (rutas[player] or 0) < tier.rutas then
			return -- no alcanzado: sin flexeo
		end
		equipada[player] = tier.id
		if dataService then
			dataService.Guardar(player, "medallaEquipada", tier.id)
		end
		publicarAtributo(player)
		publicar(player)
	end)

	-- Victoria en la meta: +1 ruta, aviso solo al subir de tier.
	local matchService = require(script.Parent.MatchService)
	matchService.AlTerminar.Event:Connect(function(player, stats)
		if not (stats and stats.victoria) then
			return
		end
		rutas[player] = (rutas[player] or 0) + 1
		if dataService then
			dataService.Guardar(player, "rutasCompletadas", rutas[player])
		end
		local tier = Config.TierDe(rutas[player])
		if tier and ultimoTier[player] ~= tier.id then
			print(("[MedallaRuta] %s alcanza tier %s (%d rutas)"):format(player.Name, tier.nombre, tier.rutas))
		end
		ultimoTier[player] = tier and tier.id
		publicarAtributo(player)
		publicar(player)
	end)

	-- Carga y barrido de carrera (patrón del repo: AccesoriosService).
	if dataService then
		dataService.AlCargar.Event:Connect(cargarJugador)
		for _, player in ipairs(Players:GetPlayers()) do
			cargarJugador(player, dataService.Obtener(player))
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		rutas[player] = nil
		equipada[player] = nil
		ultimoTier[player] = nil
	end)

	print("[MedallaRuta] servicio listo: " .. #Config.Tiers .. " tiers por rutas completadas")
end

return MedallasRutaService
