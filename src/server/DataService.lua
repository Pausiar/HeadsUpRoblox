-- DataService: persistencia del jugador (plan §3.3: UpdateAsync, reintentos,
-- guardado al salir y periódico; monedas, cosméticos, ajustes, camisetas, récords).
-- Servidor autoritativo: la caché de sesión es la fuente de verdad mientras el
-- jugador está aquí; el DataStore solo se lee al entrar y se escribe al salir/
-- periódicamente. En Studio sin acceso a API degrada a modo memoria (warn una vez).
-- Esquema v2 (fase 11 · E45): clave HUMM_Jugador_v2, migración desde la v1 con
-- respaldo previo y autoguardado que solo escribe los campos cambiados.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)

-- Lista blanca de §3.1 para GuardarAjustes: las claves de Settings.Valores y el
-- tipo de su default (foto fija al cargar). El servidor no decide valores, solo
-- valida que la clave exista y el valor sea del tipo esperado antes de guardar.
local TIPO_AJUSTES = {}
for clave, valor in pairs(Settings.Valores) do
	TIPO_AJUSTES[clave] = type(valor)
end

local TIENDA_V2 = "HUMM_Jugador_v2"
local TIENDA_V1 = "HUMM_Jugador_v1" -- solo se lee para migrar perfiles antiguos
local ESQUEMA = 2
local INTERVALO_AUTO = 60 -- segundos entre tandas de autoguardado
local ENFRIAMIENTO_AJUSTES = 0.2 -- s entre GuardarAjustes aceptados (el cliente coalesce a 0,3)
local MAX_REINTENTOS = 3 -- reintentos tras el primer intento (backoff 1-2-4 s)
local SUFIJO_RESPALDO = "_respaldo_v1"

local DataService = {}
DataService.AlCargar = Instance.new("BindableEvent") -- (player, datos)
-- (player, motivo): la lectura falló y la sesión no persistirá (E46, telemetría).
DataService.AlFallar = Instance.new("BindableEvent")

local tiendaV2 -- DataStore del esquema actual (nil = modo memoria)
local tiendaV1 -- DataStore antiguo, solo para migrar y respaldar
local sinApiStudio = false -- bandera: Studio sin acceso a API (warn una vez, no reintenta)
local caches = {} -- [player] = tabla de datos de sesión
local sucios = {} -- [player] = true si hay cambios sin guardar
local camposSucios = {} -- [player][campo] = true desde el último guardado
local sinPersistir = {} -- [player] = true si una lectura falló: no se pisa lo guardado
local cargando = {} -- [player] = true mientras corre una carga (evita duplicarla)
local ultimoAjuste = {} -- [player] = os.clock() del último GuardarAjustes aceptado

local function claveDe(player)
	return "u_" .. player.UserId
end

-- Campos nuevos del esquema v2 (plan §3). Los que aún no usa ningún lote quedan
-- aquí desde el principio para que la migración no dependa del orden de llegada.
local function perfilNuevo()
	return {
		schema = ESQUEMA,
		tutorialVisto = false,
		estadisticas = { partidas = 0, metas = 0, reanimaciones = 0, mejorDistancia = 0, mejorRapida = 0 },
		misiones = { dia = "", progreso = {}, reclamadas = {} },
		racha = { ultimoDia = "", dias = 0 },
		xp = 0,
		cosmeticos = { poseidos = {}, equipados = {} },
		bienvenidaComprada = false,
		ultimaPartida = {},
		ajustes = {}, -- §3.1 (D37/D41): GuardarAjustes la sanea contra la lista blanca y marca sucia
	}
end

-- Migración pura v1 → v2: conserva todos los campos v1 y añade los del esquema.
-- Idempotente: migrar el resultado otra vez devuelve el mismo perfil.
local function migrarPerfil(datosV1)
	local perfil = perfilNuevo()
	if type(datosV1) == "table" then
		for campo, valor in pairs(datosV1) do
			perfil[campo] = valor
		end
	end
	perfil.schema = ESQUEMA
	return perfil
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
local function cargar(store, clave)
	for reintento = 0, MAX_REINTENTOS do
		local ok, res = pcall(function()
			return store:GetAsync(clave)
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

-- UpdateAsync (NO SetAsync, plan §3.3). Con `campos` escribe solo esos campos
-- sobre lo guardado (autoguardado); sin él reemplaza el perfil (salida/cierre).
-- Con pcall y reintentos; nunca lanza.
local function guardarYa(clave, datos, nombre, campos)
	if not tiendaV2 or sinApiStudio then
		return false -- modo memoria: nada que persistir
	end
	for reintento = 0, MAX_REINTENTOS do
		local ok, err = pcall(function()
			tiendaV2:UpdateAsync(clave, function(anterior)
				if not campos then
					datos.schema = ESQUEMA
					return datos
				end
				local nuevo = type(anterior) == "table" and anterior or {}
				for campo in pairs(campos) do
					nuevo[campo] = datos[campo] -- nil borra el campo (p. ej. sombrero)
				end
				nuevo.schema = ESQUEMA
				return nuevo
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

-- Copia de seguridad del perfil v1 antes de migrar. Nunca sobrescribe un
-- respaldo previo y nunca bloquea la carga (si falla, solo avisa).
local function respaldarV1(clave, datos, nombre)
	if not tiendaV1 or sinApiStudio then
		return
	end
	local ok, err = pcall(function()
		tiendaV1:UpdateAsync(clave .. SUFIJO_RESPALDO, function(anterior)
			return anterior or datos
		end)
	end)
	if ok then
		print("[Datos] respaldo v1 guardado para " .. nombre)
	else
		warn("[Datos] respaldo v1 falló para " .. nombre .. ": " .. tostring(err))
	end
end

local function marcarCampos(player, campos)
	if not campos then
		return
	end
	local pendientes = camposSucios[player]
	if not pendientes then
		pendientes = {}
		camposSucios[player] = pendientes
	end
	for campo in pairs(campos) do
		pendientes[campo] = true
	end
end

-- Fusión de la caché con lo guardado (o con el perfil migrado): lo que ya
-- escribió la sesión manda, después entra lo guardado y al final los defaults
-- del esquema solo rellenan huecos. Orden importante: al revés, un perfil
-- guardado perdería xp/estadísticas/misiones contra los valores por defecto.
local function fusionarPerfil(cache, datos)
	if datos then
		for k, v in pairs(datos) do
			if cache[k] == nil then
				cache[k] = v
			end
		end
	end
	for campo, valor in pairs(perfilNuevo()) do
		if cache[campo] == nil then
			cache[campo] = valor
		end
	end
	return cache
end

local function cargarJugador(player)
	if cargando[player] then
		return -- PlayerAdded y el barrido de arranque pueden coincidir
	end
	cargando[player] = true
	local nombre = player.Name
	local clave = claveDe(player)
	local datos, fallo
	if tiendaV2 and not sinApiStudio then
		datos, fallo = cargar(tiendaV2, clave)
	end
	if fallo == "fallo" then
		-- Sin saber qué había guardado, escribir al salir lo pisaría con la caché vacía.
		sinPersistir[player] = true
		warn("[Datos] carga falló para " .. nombre .. ": sesión sin guardar")
		DataService.AlFallar:Fire(player, "carga")
	end

	-- Migración v1 → v2 solo si v2 aún no existe; así dos cargas seguidas no
	-- vuelven a migrar ni duplican campos. Respaldo y escritura son best-effort.
	if datos == nil and fallo == nil and tiendaV2 and not sinApiStudio and tiendaV1 then
		local v1, falloV1 = cargar(tiendaV1, clave)
		if v1 ~= nil then
			task.spawn(respaldarV1, clave, v1, nombre)
			datos = migrarPerfil(v1)
			if guardarYa(clave, datos, nombre, nil) then
				print("[Datos] perfil v1 migrado a v2 para " .. nombre)
			else
				warn("[Datos] migración v1→v2 no se pudo escribir para " .. nombre)
			end
		elseif falloV1 == "fallo" then
			-- Sin saber qué había en v1, escribir v2 taparía el perfil antiguo.
			sinPersistir[player] = true
			warn("[Datos] lectura v1 falló para " .. nombre .. ": sesión sin guardar")
			DataService.AlFallar:Fire(player, "carga_v1")
		end
	end

	if not player.Parent then -- se fue antes de terminar de cargar
		caches[player] = nil
		sucios[player] = nil
		camposSucios[player] = nil
		sinPersistir[player] = nil
		cargando[player] = nil
		ultimoAjuste[player] = nil
		return
	end

	-- Respetar escrituras previas a la carga (Obtener/Guardar crean la tabla antes).
	local cache = fusionarPerfil(caches[player] or {}, datos)
	caches[player] = cache
	cargando[player] = nil
	if fallo == nil then
		print("[Datos] carga OK para " .. nombre)
	end
	DataService.AlCargar:Fire(player, cache)
	Remotes.Crear(Remotes.Nombres.TusDatos):FireClient(player, cache)
	Remotes.Crear(Remotes.Nombres.AjustesCargados):FireClient(player, cache.ajustes or {}) -- §3.1
end

-- Guardado de una tanda: campos concretos si se conocen, perfil completo si no.
-- Si falla de forma transitoria, deja la marca para el siguiente intento.
local function guardarSiFalla(player, cache, campos)
	if sinPersistir[player] then
		return
	end
	if guardarYa(claveDe(player), cache, player.Name, campos) then
		return
	end
	if tiendaV2 and not sinApiStudio and player.Parent and caches[player] == cache then
		sucios[player] = true
		marcarCampos(player, campos)
	end
end

function DataService.Iniciar()
	local okV2, resV2 = pcall(function()
		return DataStoreService:GetDataStore(TIENDA_V2)
	end)
	if okV2 then
		tiendaV2 = resV2
	else
		if esErrorStudio(resV2) then
			marcarSinApi()
		else
			warn("[Datos] no se pudo abrir el DataStore: modo memoria (" .. tostring(resV2) .. ")")
		end
	end
	if tiendaV2 then
		local okV1, resV1 = pcall(function()
			return DataStoreService:GetDataStore(TIENDA_V1)
		end)
		if okV1 then
			tiendaV1 = resV1
		else
			warn("[Datos] DataStore v1 no disponible: sin migración (" .. tostring(resV1) .. ")")
		end
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(cargarJugador, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do -- carrera con Iniciar
		task.spawn(cargarJugador, player)
	end

	-- Autoguardado periódico: solo jugadores sucios y solo sus campos cambiados;
	-- nunca rompe el bucle.
	task.spawn(function()
		while true do
			task.wait(INTERVALO_AUTO)
			local okTick, err = pcall(function()
				for player in pairs(sucios) do
					sucios[player] = nil
					local cache = caches[player]
					if cache and player.Parent then
						local campos = camposSucios[player]
						camposSucios[player] = nil
						task.spawn(guardarSiFalla, player, cache, campos)
					end
				end
			end)
			if not okTick then
				warn("[Datos] tick de autoguardado falló: " .. tostring(err))
			end
		end
	end)

	-- §3.1: GuardarAjustes (cliente -> servidor, limitado). Valida el payload y
	-- sanea cada clave contra TIPO_AJUSTES (números finitos, cadenas acotadas);
	-- el servidor no decide valores. Si no queda nada válido no toca la caché:
	-- así un payload vacío no pisa los ajustes ya cargados del perfil.
	Remotes.Crear(Remotes.Nombres.GuardarAjustes).OnServerEvent:Connect(function(player, ajustes)
		if type(ajustes) ~= "table" then
			return
		end
		local ahora = os.clock()
		if ultimoAjuste[player] and ahora - ultimoAjuste[player] < ENFRIAMIENTO_AJUSTES then
			return
		end
		local saneada = {}
		for clave, valor in pairs(ajustes) do
			local tipo = TIPO_AJUSTES[clave]
			if type(valor) == tipo
				and (tipo ~= "number" or (valor == valor and valor ~= math.huge and valor ~= -math.huge))
				and (tipo ~= "string" or #valor <= 32) then
				saneada[clave] = valor
			end
		end
		if next(saneada) then
			ultimoAjuste[player] = ahora
			DataService.Guardar(player, "ajustes", saneada) -- cache.ajustes = saneada + marca sucia
		end
	end)

	-- Guardado al salir: perfil completo con la caché actual.
	Players.PlayerRemoving:Connect(function(player)
		local cache = caches[player]
		local bloqueado = sinPersistir[player]
		caches[player] = nil
		sucios[player] = nil
		camposSucios[player] = nil
		sinPersistir[player] = nil
		cargando[player] = nil
		ultimoAjuste[player] = nil
		if cache and not bloqueado and tiendaV2 and not sinApiStudio then
			task.spawn(guardarYa, claveDe(player), cache, player.Name, nil)
		end
	end)

	-- Flush final al cerrar el servidor (task.spawn + espera acotada).
	game:BindToClose(function()
		if not tiendaV2 or sinApiStudio then
			return
		end
		local pendientes = 0
		local lista = {}
		for player, cache in pairs(caches) do
			if not sinPersistir[player] then
				lista[#lista + 1] = { player, cache }
			end
		end
		for _, par in ipairs(lista) do
			local player, cache = par[1], par[2]
			pendientes += 1
			task.spawn(function()
				guardarYa(claveDe(player), cache, player.Name, nil)
				pendientes -= 1
			end)
		end
		local t0 = os.clock()
		while pendientes > 0 and os.clock() - t0 < 20 do
			task.wait(0.25)
		end
	end)

	print("[Datos] servicio listo" .. (tiendaV2 and "" or " (modo memoria)"))
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
	marcarCampos(player, { [clave] = true })
end

-- Seam de Studio (sin DataStore no se puede ejercitar la migración real):
-- devuelve el perfil migrado y si una segunda migración es idéntica.
if RunService:IsStudio() then
	function DataService._ProbarMigracion(datosV1)
		local primero = migrarPerfil(datosV1)
		local segundo = migrarPerfil(primero)
		local iguales = true
		for campo, valor in pairs(primero) do
			if segundo[campo] ~= valor then
				iguales = false
				break
			end
		end
		return primero, iguales
	end

	-- Lo guardado debe ganar a los defaults; la sesión, a lo guardado.
	function DataService._ProbarFusion(datos, sesion)
		return fusionarPerfil(sesion or {}, datos)
	end
end

return DataService
