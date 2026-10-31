-- RankingGlobalService (plan §L8 · C31): top mensual global de distancias.
-- Una tienda OrderedDataStore por mes (HUMM_Global_v1_<yyyymm>): el ranking se
-- reinicia solo cada mes y el top 50 sale exacto de una sola consulta, sin
-- filtrar claves de meses pasados. Solo cuentan metas cerradas en Modo Puro.
-- Servidor autoritativo: el cliente pide el top y lo pinta; nunca envía datos.
-- Cableado: requiere Iniciar() en Main.server.lua después de MatchService
-- (igual que AmigosRankingService) — lo añade quien integre la fase.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.RankingGlobalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local RankingGlobalService = {}

local MAX_REINTENTOS = 3 -- intentos extra de escritura (backoff 1-2-4 s)
local ESPERA_LECTURA = 0.05 -- s entre consultas web (nombres del top), compartidas
local MSG_SIN_API = "Ranking global no disponible en Studio"
local MSG_ERROR = "No se pudo cargar el ranking global; inténtalo más tarde"

local mesTienda = nil -- mes de la tienda abierta (nil = ninguna)
local tienda -- OrderedDataStore del mes en curso (nil = sin datos)
local sinApi = false -- bandera: sin acceso a API (warn una vez, no reintenta)
local nombres = {} -- [userId] = nombre resuelto (caché de sesión de GetNameFromUserIdAsync)
local enVuelo = {} -- [player] = true mientras se construye su top

local remotoDatos

local function claveDe(userId)
	return Config.PrefijoClave .. tostring(userId)
end

-- Tienda del mes en curso: al cruzar el cambio de mes la siguiente se abre
-- sola, así el servidor nunca escribe en el mes pasado.
local function tiendaActual()
	if sinApi then
		return nil
	end
	local mes = Config.Mes()
	if mes ~= mesTienda then
		local ok, res = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.NombreTienda .. "_" .. mes)
		end)
		if not ok then
			sinApi = true
			warn("[RankingGlobal] sin DataStore: ranking desactivado (" .. tostring(res) .. ")")
			return nil
		end
		tienda = res
		mesTienda = mes
	end
	return tienda
end

-- Mismos mensajes que AmigosRankingService: Studio sin API o servidor sin DataStore.
local function esErrorApi(err)
	local m = string.lower(tostring(err))
	return string.find(m, "studio", 1, true) ~= nil
		or string.find(m, "game servers", 1, true) ~= nil
		or string.find(m, "not allowed", 1, true) ~= nil
end

local function marcarSinApi(err)
	if not sinApi then
		sinApi = true
		warn("[RankingGlobal] sin acceso a DataStore: ranking desactivado (" .. tostring(err) .. ")")
	end
end

-- OrderedDataStore no tiene Increment: se lee la marca previa y se escribe el
-- máximo. La carrera (mismo jugador cerrando metas en dos servidores a la vez)
-- a lo sumo pierde una mejora de esa misma persona; con max() el valor no baja.
local function guardarDistancia(player, distancia)
	local t = tiendaActual()
	if not t then
		return -- modo sin datos (Studio): la distancia no persiste, nada que leer
	end
	local valor = math.round(distancia)
	local clave = claveDe(player.UserId)

	for intento = 0, MAX_REINTENTOS do
		local okLectura, previo = pcall(function()
			return t:GetAsync(clave)
		end)
		if okLectura and tonumber(previo) and tonumber(previo) >= valor then
			return -- ya hay una marca igual o mejor este mes
		end
		-- Si la lectura falla se sigue: previo nil implica escribir el nuevo valor.

		local ok, err = pcall(function()
			t:SetAsync(clave, valor)
		end)
		if ok then
			print("[RankingGlobal] " .. player.Name .. ": " .. valor .. " studs (" .. mesTienda .. ")")
			return
		end
		if esErrorApi(err) then
			marcarSinApi(err)
			return
		end
		warn("[RankingGlobal] guardado falló (" .. (intento + 1) .. "/" .. (MAX_REINTENTOS + 1) .. "): " .. tostring(err))
		if intento < MAX_REINTENTOS then
			task.wait(2 ^ intento) -- 1, 2, 4 s
		end
	end
	warn("[RankingGlobal] no se pudo guardar la distancia de " .. player.Name)
end

-- Nombre del top: el propio jugador no necesita consulta; el resto se cachea
-- por userId durante la sesión (el top 50 es estable entre peticiones).
local function nombreDe(id, propio)
	if propio and id == propio.UserId then
		return propio.DisplayName
	end
	local cacheado = nombres[id]
	if cacheado then
		return cacheado
	end
	local ok, res = pcall(function()
		return Players:GetNameFromUserIdAsync(id)
	end)
	if ok and type(res) == "string" and res ~= "" then
		nombres[id] = res
		return res
	end
	return "Jugador"
end

local function construir(player)
	local t = tiendaActual()
	if not t then
		return { entradas = {}, mensaje = MSG_SIN_API }
	end

	local ok, res = pcall(function()
		return t:GetSortedAsync(false, Config.TopN) -- descendente, primera página = top 50 del mes
	end)
	if not ok then
		if esErrorApi(res) then
			marcarSinApi(res)
			return { entradas = {}, mensaje = MSG_SIN_API }
		end
		warn("[RankingGlobal] consulta falló: " .. tostring(res))
		return { entradas = {}, mensaje = MSG_ERROR }
	end

	local okPagina, pagina = pcall(function()
		return res:GetCurrentPage()
	end)
	if not okPagina or type(pagina) ~= "table" then
		return { entradas = {}, mensaje = MSG_ERROR }
	end

	local entradas = {}
	for _, fila in ipairs(pagina) do
		local id = tonumber(string.match(tostring(fila.key or ""), "^" .. Config.PrefijoClave .. "(%d+)$"))
		local valor = tonumber(fila.value)
		if id and valor and valor > 0 then
			entradas[#entradas + 1] = {
				nombre = nombreDe(id, player),
				nivel = 0, -- C32 lo rellenará desde ProgresionService cuando exista
				valor = math.round(valor),
			}
			task.wait(ESPERA_LECTURA) -- espacia los GetNameFromUserIdAsync entre entradas
		end
	end
	return { entradas = entradas }
end

function RankingGlobalService.Iniciar()
	tiendaActual()

	remotoDatos = Remotes.Crear(Remotes.Nombres.RankingGlobalDatos)
	local pedir = Remotes.Crear(Remotes.Nombres.RankingGlobal)
	local permitir = RateLimiter.nuevo(Config.EnfriamientoPeticion)

	pedir.OnServerEvent:Connect(function(player)
		if not permitir(player) then
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
				warn("[RankingGlobal] petición falló: " .. tostring(payload))
				if player.Parent then
					remotoDatos:FireClient(player, { entradas = {}, mensaje = MSG_ERROR })
				end
				return
			end

			if player.Parent then -- pudo irse mientras se consultaba
				remotoDatos:FireClient(player, payload)
			end
		end)
	end)

	-- Solo las metas cerradas en Modo Puro entran al ranking global (§L8 C31).
	local matchService = require(script.Parent.MatchService)
	local okMonetizacion, monetizacion = pcall(require, script.Parent.MonetizacionService)
	matchService.AlTerminar.Event:Connect(function(player, stats)
		if not (stats and stats.victoria == true) then
			return -- el fin sin meta no trae victoria y no cuenta
		end
		local distancia = tonumber(stats.distancia)
		if not distancia or distancia <= 0 then
			return
		end
		if not okMonetizacion or not monetizacion.EsModoPuro(player) then
			return -- con ventajas o reanimaciones de pago la meta no cuenta
		end
		task.spawn(guardarDistancia, player, distancia)
	end)

	Players.PlayerRemoving:Connect(function(player)
		enVuelo[player] = nil
	end)

	if tienda then
		print("[RankingGlobal] activo: " .. Config.NombreTienda .. "_" .. mesTienda .. " (top " .. Config.TopN .. ")")
	else
		print("[RankingGlobal] servicio listo sin datos (ranking desactivado)")
	end
end

return RankingGlobalService
