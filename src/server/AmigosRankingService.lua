-- AmigosRankingService: ranking persistente de amigos (plan §3.3/§4.5).
-- Guarda la mejor distancia de cada jugador en un OrderedDataStore y responde
-- al cliente con el top de sus amigos (o el global si no hay amigos o falla la
-- API). Servidor autoritativo: el cliente solo pide y pinta; nunca envía datos.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.RankingAmigosConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local AmigosRankingService = {}

local MAX_REINTENTOS = 3 -- intentos extra de escritura (backoff 1-2-4 s)
-- shortcut: una consulta lee hasta MaxAmigos claves (50) por jugador; si varios jugadores
-- refrescan a la vez se agota el cupo por minuto y la lista sale parcial (sin error).
-- La caché de marcas por userId amortigua el caso normal: el grupo suele compartir amigos.
-- Revisar si un servidor pasa de ~8 jugadores o si el ranking tarda >60 s en refrescar.
local ESPERA_LECTURA = 0.05 -- s entre GetAsync de amigos (presupuesto de DataStore)
local MSG_SIN_API = "Ranking no disponible en Studio"
local MSG_ERROR = "No se pudo cargar el ranking; inténtalo más tarde"

local tienda -- OrderedDataStore (nil = sin datos)
local sinApi = false -- bandera: sin acceso a API (warn una vez, no reintenta)
local mejores = {} -- [player] = mejor distancia de la sesión (optimista)
local cache = {} -- [player] = { t = os.clock(), payload = ... }
local enVuelo = {} -- [player] = true mientras se construye su ranking
local marcas = {} -- [userId] = { t, valor } compartida entre jugadores del servidor

local remotoRanking

local function claveDe(userId)
	return Config.PrefijoClave .. tostring(userId)
end

-- Mismos mensajes que DataService: Studio sin API o servidor sin DataStore.
local function esErrorApi(err)
	local m = string.lower(tostring(err))
	return string.find(m, "studio", 1, true) ~= nil
		or string.find(m, "game servers", 1, true) ~= nil
		or string.find(m, "not allowed", 1, true) ~= nil
end

local function marcarSinApi(err)
	if not sinApi then
		sinApi = true
		warn("[AmigosRanking] sin acceso a DataStore: ranking desactivado (" .. tostring(err) .. ")")
	end
end

local function leerMarca(userId)
	if not tienda or sinApi then
		return nil
	end
	local guardada = marcas[userId]
	if guardada and os.clock() - guardada.t < Config.CacheSegundos then
		return guardada.valor or nil
	end
	local ok, res = pcall(function()
		return tienda:GetAsync(claveDe(userId))
	end)
	if ok then
		local valor = tonumber(res)
		marcas[userId] = { t = os.clock(), valor = valor or false }
		return valor
	end
	if esErrorApi(res) then
		marcarSinApi(res)
	end
	return nil
end

local function entrada(nombre, distancia, tu)
	return {
		nombre = tostring(nombre),
		distancia = math.round(tonumber(distancia) or 0),
		tu = tu == true,
	}
end

-- Nunca baja una marca: UpdateAsync con math.max (OrderedDataStore lo hereda de
-- GlobalDataStore; no tiene versiones, pero el merge sigue siendo atómico).
local function guardarMarca(player, distancia)
	local valor = math.max(mejores[player] or 0, math.round(distancia))
	mejores[player] = valor
	cache[player] = nil -- la próxima consulta verá la marca nueva
	marcas[player.UserId] = nil
	if not tienda or sinApi then
		return -- modo sin datos: la marca vive solo en la sesión
	end

	for intento = 0, MAX_REINTENTOS do
		local ok, err = pcall(function()
			tienda:UpdateAsync(claveDe(player.UserId), function(actual)
				return math.max(tonumber(actual) or 0, valor)
			end)
		end)
		if ok then
			print("[AmigosRanking] " .. player.Name .. ": " .. valor .. " studs")
			return
		end
		if esErrorApi(err) then
			marcarSinApi(err)
			return
		end
		warn("[AmigosRanking] guardado falló (" .. (intento + 1) .. "/" .. (MAX_REINTENTOS + 1) .. "): " .. tostring(err))
		if intento < MAX_REINTENTOS then
			task.wait(2 ^ intento) -- 1, 2, 4 s
		end
	end
	warn("[AmigosRanking] no se pudo guardar la marca de " .. player.Name)
end

-- Lista de amigos con los campos documentados (Id, DisplayName/Username).
-- Devuelve nil si la API falla; el llamador decide el fallback global.
local function leerAmigos(userId)
	local ok, paginas = pcall(function()
		return Players:GetFriendsAsync(userId)
	end)
	if not ok or not paginas then
		return nil
	end

	local amigos = {}
	local okPagina, pagina = pcall(function()
		return paginas:GetCurrentPage()
	end)
	while okPagina and type(pagina) == "table" do
		for _, amigo in ipairs(pagina) do
			if #amigos >= Config.MaxAmigos then
				return amigos
			end
			local id = type(amigo) == "table" and tonumber(amigo.Id) or nil
			if id and id ~= userId then
				amigos[#amigos + 1] = {
					Id = id,
					nombre = amigo.DisplayName or amigo.Username or "Jugador",
				}
			end
		end

		local okFin, fin = pcall(function()
			return paginas.IsFinished
		end)
		if not okFin or fin then
			return amigos
		end
		local okAvance = pcall(function()
			paginas:AdvanceToNextPageAsync()
		end)
		if not okAvance then
			return amigos
		end
		okPagina, pagina = pcall(function()
			return paginas:GetCurrentPage()
		end)
	end
	return amigos
end

-- Ordena desc, corta a Top e incluye siempre al jugador aunque quede fuera.
local function topConJugador(entradas, propia)
	table.sort(entradas, function(a, b)
		if a.distancia ~= b.distancia then
			return a.distancia > b.distancia
		end
		return a.nombre < b.nombre
	end)

	local top = {}
	for i = 1, math.min(#entradas, Config.Top) do
		top[i] = entradas[i]
	end
	local incluido = false
	for _, e in ipairs(top) do
		if e.tu then
			incluido = true
			break
		end
	end
	if not incluido then
		top[#top + 1] = propia
	end
	return top
end

-- nil = sin amigos o GetFriendsAsync falló (el llamador decide el fallback).
local function construirAmigos(player, propia)
	local amigos = leerAmigos(player.UserId)
	if not amigos or #amigos == 0 then
		return nil
	end

	local entradas = { propia }
	local vistos = { [player.UserId] = true }
	for _, amigo in ipairs(amigos) do
		if not vistos[amigo.Id] then
			vistos[amigo.Id] = true
			local marca = leerMarca(amigo.Id)
			if marca and marca > 0 then
				entradas[#entradas + 1] = entrada(amigo.nombre, marca, false)
			end
			task.wait(ESPERA_LECTURA) -- presupuesto de DataStore
		end
	end
	return topConJugador(entradas, propia)
end

local function construirGlobal(player, propia)
	local entradas = {}
	local estaElJugador = false

	local ok, paginas = pcall(function()
		return tienda:GetSortedAsync(false, Config.Top)
	end)
	if ok and paginas then
		local okPagina, pagina = pcall(function()
			return paginas:GetCurrentPage()
		end)
		if okPagina and type(pagina) == "table" then
			for _, fila in ipairs(pagina) do
				local clave = tostring(fila.key or "")
				local id
				if string.sub(clave, 1, #Config.PrefijoClave) == Config.PrefijoClave then
					id = tonumber(string.sub(clave, #Config.PrefijoClave + 1))
				end
				local valor = tonumber(fila.value)
				if id and valor and valor > 0 then
					local nombre
					if id == player.UserId then
						estaElJugador = true
						nombre = player.DisplayName
						valor = math.max(valor, propia.distancia)
					else
						local okNombre, res = pcall(function()
							return Players:GetNameFromUserIdAsync(id)
						end)
						nombre = okNombre and res or "Jugador"
					end
					entradas[#entradas + 1] = entrada(nombre, valor, id == player.UserId)
					task.wait(ESPERA_LECTURA)
				end
			end
		end
	elseif not ok and esErrorApi(paginas) then
		marcarSinApi(paginas)
	end

	if not estaElJugador then
		entradas[#entradas + 1] = propia
	end
	return topConJugador(entradas, propia)
end

local function construir(player)
	if not tienda or sinApi then
		return { fuente = "ninguna", entradas = {}, mensaje = MSG_SIN_API }
	end

	local propia = entrada(player.DisplayName, math.max(mejores[player] or 0, leerMarca(player.UserId) or 0), true)
	if sinApi then -- leerMarca pudo descubrir que no hay API
		return { fuente = "ninguna", entradas = {}, mensaje = MSG_SIN_API }
	end

	local lista = construirAmigos(player, propia)
	local fuente = "amigos"

	if not lista then
		if Config.FallbackGlobal then
			lista = construirGlobal(player, propia)
			fuente = "global"
		else
			lista = { propia }
		end
	end

	if sinApi then -- alguna lectura pudo descubrir que no hay API
		return { fuente = "ninguna", entradas = {}, mensaje = MSG_SIN_API }
	end
	return { fuente = fuente, entradas = lista }
end

function AmigosRankingService.Iniciar()
	local ok, res = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.NombreTienda)
	end)
	if ok then
		tienda = res
	else
		sinApi = true
		warn("[AmigosRanking] sin DataStore: ranking desactivado (" .. tostring(res) .. ")")
	end

	remotoRanking = Remotes.Crear(Remotes.Nombres.RankingAmigos) -- el servidor crea, el cliente espera
	local pedir = Remotes.Crear(Remotes.Nombres.PedirRankingAmigos)
	local permitir = RateLimiter.nuevo(Config.EnfriamientoPeticion)

	pedir.OnServerEvent:Connect(function(player)
		if not permitir(player) then
			return
		end

		local guardado = cache[player]
		if guardado and os.clock() - guardado.t < Config.CacheSegundos then
			remotoRanking:FireClient(player, guardado.payload)
			return
		end
		if enVuelo[player] then
			return -- una petición en vuelo por jugador
		end

		enVuelo[player] = true
		task.spawn(function()
			local okPeticion, payload = pcall(construir, player)
			enVuelo[player] = nil

			if not okPeticion then
				warn("[AmigosRanking] petición falló: " .. tostring(payload))
				if player.Parent then
					remotoRanking:FireClient(player, { fuente = "ninguna", entradas = {}, mensaje = MSG_ERROR })
				end
				return
			end

			if player.Parent then -- pudo irse mientras se consultaba
				cache[player] = { t = os.clock(), payload = payload }
				remotoRanking:FireClient(player, payload)
			end
		end)
	end)

	-- Mejor marca al cerrar partida (stats.distancia es entera y autoritativa).
	-- Plan §7.3: solo las partidas en Modo Puro cuentan para el ranking de récords.
	local matchService = require(script.Parent.MatchService)
	local okMonetizacion, monetizacion = pcall(require, script.Parent.MonetizacionService)
	matchService.AlTerminar.Event:Connect(function(player, stats)
		local distancia = tonumber(stats and stats.distancia)
		if not distancia or distancia <= 0 then
			return
		end
		if not okMonetizacion or not monetizacion.EsModoPuro(player) then
			return -- con ventajas o reanimaciones de pago la marca no cuenta
		end
		task.spawn(guardarMarca, player, distancia)
	end)

	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
		enVuelo[player] = nil
		mejores[player] = nil
	end)

	if tienda then
		print("[AmigosRanking] activo: " .. Config.NombreTienda .. " (top " .. Config.Top .. ")")
	else
		print("[AmigosRanking] servicio listo sin datos (ranking desactivado)")
	end
end

return AmigosRankingService
