-- DataService: persistencia del jugador (plan §3.3: UpdateAsync, reintentos,
-- guardado al salir y periódico; monedas, cosméticos, ajustes, camisetas, récords).
-- Servidor autoritativo: la caché de sesión es la fuente de verdad mientras el
-- jugador está aquí; el DataStore solo se lee al entrar y se escribe al salir/
-- periódicamente. En Studio sin acceso a API degrada a modo memoria (warn una vez).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NOMBRE_TIENDA = "HUMM_Jugador_v1" -- versionado para migraciones futuras
local INTERVALO_AUTO = 60 -- segundos entre tandas de autoguardado
local MAX_REINTENTOS = 3 -- reintentos tras el primer intento (backoff 1-2-4 s)

local DataService = {}
DataService.AlCargar = Instance.new("BindableEvent") -- (player, datos)

local tienda -- DataStore (nil = modo memoria desde el arranque)
local sinApiStudio = false -- bandera: Studio sin acceso a API (warn una vez, no reintenta)
local caches = {} -- [player] = tabla de datos de sesión
local sucios = {} -- [player] = true si hay cambios sin guardar

local function claveDe(player)
	return "u_" .. player.UserId
end

-- Los mensajes típicos de Studio sin API: "Studio access to APIs is not allowed"
-- y "DataStores can only be accessed from game servers".
local function esErrorStudio(err)
	local m = string.lower(tostring(err))
	return string.find(m, "studio", 1, true) ~= nil
		or string.find(m, "game servers", 1, true) ~= nil
end

local function marcarSinApi()
	if not sinApiStudio then
		sinApiStudio = true
		warn("[Datos] Studio sin acceso a API: persistencia desactivada (modo memoria)")
	end
end

-- GetAsync con reintentos. Devuelve (datos, fallo): fallo = "fallo" (agotó
-- reintentos), "studio" (sin API) o nil (OK, datos puede ser nil = primera vez).
local function cargar(clave)
	for reintento = 0, MAX_REINTENTOS do
		local ok, res = pcall(function()
			return tienda:GetAsync(clave)
		end)
		if ok then
			return res, nil
		end
		if esErrorStudio(res) then
			marcarSinApi()
			return nil, "studio"
		end
		warn("[Datos] intento " .. (reintento + 1) .. " de carga falló: " .. tostring(res))
		if reintento < MAX_REINTENTOS then
			task.wait(2 ^ reintento) -- 1, 2, 4 s
		end
	end
	return nil, "fallo"
end

-- UpdateAsync (NO SetAsync, plan §3.3): el merge devuelve la caché de sesión,
-- fuente de verdad. Con pcall y reintentos; nunca lanza.
local function guardarYa(clave, datos, nombre)
	if not tienda or sinApiStudio then
		return false -- modo memoria: nada que persistir
	end
	for reintento = 0, MAX_REINTENTOS do
		local ok, err = pcall(function()
			tienda:UpdateAsync(clave, function()
				return datos
			end)
		end)
		if ok then
			print("[Datos] guardado OK para " .. nombre)
			return true
		end
		if esErrorStudio(err) then
			marcarSinApi()
			break
		end
		warn("[Datos] intento " .. (reintento + 1) .. " de guardado falló para " .. nombre .. ": " .. tostring(err))
		if reintento < MAX_REINTENTOS then
			task.wait(2 ^ reintento) -- 1, 2, 4 s
		end
	end
	warn("[Datos] guardado falló para " .. nombre)
	return false
end

local function cargarJugador(player)
	local nombre = player.Name
	local datos, fallo
	if tienda and not sinApiStudio then
		datos, fallo = cargar(claveDe(player))
	end
	if fallo == "fallo" then
		warn("[Datos] carga falló para " .. nombre .. " (modo memoria)")
	end
	if not player.Parent then -- se fue antes de terminar de cargar
		caches[player] = nil
		sucios[player] = nil
		return
	end
	-- Respetar escrituras previas a la carga (Obtener/Guardar crean la tabla antes).
	local cache = caches[player] or {}
	if datos then
		for k, v in pairs(datos) do
			if cache[k] == nil then
				cache[k] = v
			end
		end
	end
	caches[player] = cache
	if fallo == nil then
		print("[Datos] carga OK para " .. nombre)
	end
	DataService.AlCargar:Fire(player, cache)
	Remotes.Crear(Remotes.Nombres.TusDatos):FireClient(player, cache)
end

local function guardarSiFalla(player, cache)
	if not guardarYa(claveDe(player), cache, player.Name) then
		-- Reintentar solo si el fallo fue transitorio (no modo memoria).
		if tienda and not sinApiStudio and player.Parent and caches[player] == cache then
			sucios[player] = true
		end
	end
end

function DataService.Iniciar()
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore(NOMBRE_TIENDA)
	end)
	if ok then
		tienda = res
	else
		if esErrorStudio(res) then
			marcarSinApi()
		else
			warn("[Datos] no se pudo abrir el DataStore: modo memoria (" .. tostring(res) .. ")")
		end
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(cargarJugador, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do -- carrera con Iniciar
		task.spawn(cargarJugador, player)
	end

	-- Autoguardado periódico: solo jugadores sucios; nunca rompe el bucle.
	task.spawn(function()
		while true do
			task.wait(INTERVALO_AUTO)
			local okTick, err = pcall(function()
				for player in pairs(sucios) do
					sucios[player] = nil
					local cache = caches[player]
					if cache and player.Parent then
						task.spawn(guardarSiFalla, player, cache)
					end
				end
			end)
			if not okTick then
				warn("[Datos] tick de autoguardado falló: " .. tostring(err))
			end
		end
	end)

	-- Guardado al salir: un UpdateAsync asíncrono con la caché actual.
	Players.PlayerRemoving:Connect(function(player)
		local cache = caches[player]
		caches[player] = nil
		sucios[player] = nil
		if cache and tienda and not sinApiStudio then
			task.spawn(guardarYa, claveDe(player), cache, player.Name)
		end
	end)

	-- Flush final al cerrar el servidor (task.spawn + espera acotada).
	game:BindToClose(function()
		if not tienda or sinApiStudio then
			return
		end
		local pendientes = 0
		local lista = {}
		for player, cache in pairs(caches) do
			lista[#lista + 1] = { player, cache }
		end
		for _, par in ipairs(lista) do
			local player, cache = par[1], par[2]
			pendientes += 1
			task.spawn(function()
				guardarYa(claveDe(player), cache, player.Name)
				pendientes -= 1
			end)
		end
		local t0 = os.clock()
		while pendientes > 0 and os.clock() - t0 < 20 do
			task.wait(0.25)
		end
	end)

	print("[Datos] servicio listo" .. (tienda and "" or " (modo memoria)"))
end

-- Tabla de datos en caché del jugador; {} si aún no cargó (no espera).
-- La tabla devuelta es viva: escribir en ella cuenta como escribir en la caché.
function DataService.Obtener(player)
	local cache = caches[player]
	if not cache then
		cache = {}
		caches[player] = cache
	end
	return cache
end

-- Escribe en la caché y marca sucio; el guardado real es asíncrono y no bloquea.
function DataService.Guardar(player, clave, valor)
	DataService.Obtener(player)[clave] = valor
	sucios[player] = true
end

return DataService
