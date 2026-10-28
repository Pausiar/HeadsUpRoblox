-- MonetizacionService: pases, productos de Robux, reanimación personal y Modo Puro (plan §7).
-- Servidor autoritativo: la posesión de pases se consulta a MarketplaceService, los
-- recibos se deduplican en DataService y toda entrega se decide aquí. Con IDs 0 o
-- Activo=false no se abre ningún prompt y RobuxResult avisa de que falta publicar.
-- Los seams _Probar* solo existen en Studio para poder probar sin comprar.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MonetizacionConfig = require(ReplicatedStorage.Shared.Config.MonetizacionConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local RANURAS_BASE = 3
local RANURAS_PASE = 9
local MAX_RECIBOS = 100
local Recibo = Enum.ProductPurchaseDecision

local MonetizacionService = {}

local pases = {} -- [player] = { [efecto] = true } posesión confirmada en esta sesión
local generaciones = {} -- [player] = token de la última comprobación de pases
local reanimacionesPartida = {} -- [player] = usos personales en la partida actual
local cargados = {} -- [player] = true cuando DataService.AlCargar ya corrió
local avisadoSinPases = false

local dataService
local pinasService
local playerState
local matchService
local ropaService -- require perezoso: RopaService también requiere este módulo
local tiendaService -- require perezoso: TiendaService no depende de este módulo

local remotoComprar
local remotoResultado
local remotoPaseEstado
local remotoReclamar
local remotoReanimar
local remotoReanimarResultado
local remotoModoPuro

local permitirComprar
local permitirReclamar
local permitirReanimar
local permitirModoPuro

local function avisarSinPases(motivo)
	if avisadoSinPases then
		return
	end
	avisadoSinPases = true
	warn("[Monetizacion] " .. motivo .. ": se juega sin pases")
end

local function datosDe(player)
	if not player or not dataService then
		return {}
	end
	return dataService.Obtener(player)
end

-- Modo Puro: sin ventajas ni reanimaciones de pago (plan §7.3).
local function esPuro(player)
	local valor = datosDe(player).modoPuro
	if valor == nil then
		return MonetizacionConfig.ModoPuroPorDefecto == true
	end
	return valor == true
end

-- Payload exacto de PaseEstado: el cliente no recibe estado interno de más.
local function estadoDe(player)
	local datos = datosDe(player)
	local poseidos = pases[player] or {}
	return {
		activo = MonetizacionConfig.Activo == true,
		pases = {
			ranurasRopa = poseidos.ranurasRopa == true,
			linternaPro = poseidos.linternaPro == true,
		},
		reanimaciones = math.max(0, math.floor(tonumber(datos.reanimacionesPersonales) or 0)),
		pinasX2Hasta = tonumber(datos.pinasX2Hasta) or 0,
		modoPuro = esPuro(player),
	}
end

local function publicar(player)
	if not remotoPaseEstado or not player or not player.Parent then
		return
	end
	remotoPaseEstado:FireClient(player, estadoDe(player))
end

-- Tras conceder ranuras extra, la UI de ropa necesita un RopaEstado fresco.
local function avisarRanuras(player)
	if not ropaService then
		local ok, res = pcall(require, script.Parent.RopaService)
		if ok then
			ropaService = res
		end
	end
	if ropaService then
		ropaService.RefrescarRanuras(player)
	end
end

local function concederItem(player, id)
	if not tiendaService then
		local ok, res = pcall(require, script.Parent.TiendaService)
		if not ok then
			warn("[Monetizacion] sin TiendaService: " .. tostring(res))
			return false
		end
		tiendaService = res
	end
	return tiendaService.ConcederItem(player, id)
end

local function efectoSoportado(item)
	return item.efecto == "pinasX2" or item.efecto == "reanimacion" or item.efecto == "cosmetico"
end

-- Entrega única para recibos y seams: sin cobro y con persistencia en DataService.
local function entregarProducto(player, item)
	if item.efecto == "pinasX2" then
		local duracion = math.max(1, math.floor(tonumber(item.duracion) or 1800))
		-- Recompra = extensión: parte del vencimiento vigente, no de ahora.
		local hasta = math.max(os.time(), tonumber(datosDe(player).pinasX2Hasta) or 0)
		dataService.Guardar(player, "pinasX2Hasta", hasta + duracion)
	elseif item.efecto == "reanimacion" then
		local datos = datosDe(player)
		local stock = math.max(0, math.floor(tonumber(datos.reanimacionesPersonales) or 0))
		local usos = math.max(1, math.floor(tonumber(item.usos) or 1))
		dataService.Guardar(player, "reanimacionesPersonales", stock + usos)
	elseif item.efecto == "cosmetico" then
		for _, id in ipairs(item.items or {}) do
			concederItem(player, id)
		end
	else
		warn("[Monetizacion] producto sin efecto conocido: " .. tostring(item.id))
		return false
	end
	publicar(player)
	print("[Monetizacion] entregado " .. item.id .. " a " .. player.Name)
	return true
end

-- Lista de PurchaseId ya entregados. Vive en la caché de DataService y se acota
-- para no crecer sin límite: se descartan los recibos más viejos.
local function listaRecibos(player)
	local datos = datosDe(player)
	if type(datos.recibos) ~= "table" then
		datos.recibos = {}
	end
	return datos.recibos
end

-- Registra el recibo ANTES de entregar (si el servidor cae, el reintento no
-- duplica). Devuelve false si ya estaba atendido.
local function procesarRecibo(player, purchaseId, item)
	local recibos = listaRecibos(player)
	if table.find(recibos, purchaseId) then
		return false
	end
	table.insert(recibos, purchaseId)
	while #recibos > MAX_RECIBOS do
		table.remove(recibos, 1)
	end
	dataService.Guardar(player, "recibos", recibos)
	entregarProducto(player, item)
	return true
end

-- Revalida todos los pases con la API. Un fallo transitorio conserva la posesión
-- ya confirmada; en Studio sin API degrada a «sin pases» con un único warn.
local function comprobarPases(player)
	local generacion = (generaciones[player] or 0) + 1
	generaciones[player] = generacion
	local previos = pases[player] or {}
	local nuevos = {}
	for _, item in ipairs(MonetizacionConfig.Pases) do
		if item.tipo == "pase" and item.disponible ~= false and item.efecto then
			local paseId = tonumber(item.paseId) or 0
			if paseId <= 0 then
				if RunService:IsStudio() then
					avisarSinPases("pases con ID 0 (sin publicar)")
				end
			else
				local ok, posee = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, paseId)
				end)
				if ok then
					if posee then
						nuevos[item.efecto] = true
					end
				else
					if previos[item.efecto] then
						nuevos[item.efecto] = true
					end
					avisarSinPases("no se pudieron comprobar los pases (" .. tostring(posee) .. ")")
				end
			end
		end
	end
	if generaciones[player] ~= generacion or not player.Parent then
		return nil -- una comprobación más nueva manda (reclamar tras comprar)
	end
	pases[player] = nuevos
	publicar(player)
	if nuevos.ranurasRopa then
		avisarRanuras(player)
	end
	return nuevos
end

-- ComprarRobux: valida catálogo, disponibilidad e ID; sin publicar no hay prompt.
local function comprarRobux(player, payload)
	if not permitirComprar(player) then
		return
	end
	local id = type(payload) == "table" and payload.id or payload
	local item = type(id) == "string" and MonetizacionConfig.PorId(id) or nil
	if not item or (item.tipo ~= "pase" and item.tipo ~= "producto") then
		remotoResultado:FireClient(player, { ok = false, mensaje = "Compra inválida", id = id })
		return
	end
	local idRobux = item.tipo == "pase" and item.paseId or item.productoId
	if MonetizacionConfig.Activo ~= true or type(idRobux) ~= "number" or idRobux <= 0 then
		remotoResultado:FireClient(player, { ok = false, mensaje = MonetizacionConfig.AvisoNoPublicado, id = id })
		return
	end
	if item.disponible == false then
		remotoResultado:FireClient(player, { ok = false, mensaje = "No disponible en esta versión", id = id })
		return
	end

	-- Responder antes del prompt: la entrega real ocurre en ProcessReceipt o ReclamarPase.
	remotoResultado:FireClient(player, { ok = true, mensaje = "Abriendo tienda…", id = id })
	local ok, err = pcall(function()
		if item.tipo == "pase" then
			MarketplaceService:PromptGamePassPurchase(player, item.paseId)
		else
			MarketplaceService:PromptProductPurchase(player, item.productoId)
		end
	end)
	if not ok then
		warn("[Monetizacion] no se pudo abrir la tienda para " .. player.Name .. ": " .. tostring(err))
		remotoResultado:FireClient(player, { ok = false, mensaje = MonetizacionConfig.AvisoNoPublicado, id = id })
	end
end

-- El cliente solo avisa tras el prompt; el servidor revalida la posesión.
local function reclamarPase(player, payload)
	if not permitirReclamar(player) then
		return
	end
	local id = type(payload) == "table" and payload.id or payload
	local item = type(id) == "string" and MonetizacionConfig.PorId(id) or nil
	if not item or item.tipo ~= "pase" then
		return
	end
	task.spawn(function()
		local poseidos = comprobarPases(player)
		if poseidos and poseidos[item.efecto] then
			print("[Monetizacion] pase " .. item.id .. " reclamado por " .. player.Name)
		end
	end)
end

-- Reanimación personal: 1 por partida, stock o Piñas, nunca en Modo Puro.
local function reanimarPersonal(player)
	if not permitirReanimar(player) then
		return
	end
	local function responder(ok, mensaje)
		remotoReanimarResultado:FireClient(player, { ok = ok, mensaje = mensaje })
	end

	if esPuro(player) then
		responder(false, "Modo Puro: sin reanimación personal")
		return
	end
	if not playerState.EstaCaido(player) then
		responder(false, "No estás caído")
		return
	end
	local item = MonetizacionConfig.PorId("reanimacion_personal")
	local limite = item and tonumber(item.limitePorPartida) or 1
	if (reanimacionesPartida[player] or 0) >= limite then
		responder(false, "Ya usaste tu reanimación en esta partida")
		return
	end
	local stock = math.max(0, math.floor(tonumber(datosDe(player).reanimacionesPersonales) or 0))
	local costo = item and tonumber(item.costoPinas) or 100
	local usaStock = stock > 0
	if not usaStock and pinasService.GetPinas(player) < costo then
		responder(false, ("Sin reanimaciones ni %d Piñas"):format(costo))
		return
	end

	playerState.Reanimar(player, nil)
	if playerState.EstaCaido(player) then
		responder(false, "No se pudo reanimar")
		return
	end
	if usaStock then
		dataService.Guardar(player, "reanimacionesPersonales", stock - 1)
	else
		pinasService.Gastar(player, costo) -- saldo comprobado arriba: no puede fallar
	end
	reanimacionesPartida[player] = (reanimacionesPartida[player] or 0) + 1
	publicar(player)
	responder(true, "Reanimado")
	print("[Monetizacion] reanimación personal usada por " .. player.Name
		.. (usaStock and " (stock)" or " (" .. costo .. " Piñas)"))
end

local function cambiarModoPuro(player, valor)
	if not permitirModoPuro(player) or type(valor) ~= "boolean" then
		return
	end
	-- shortcut: el Modo Puro aún no separa récords; el ranking Puro (plan §7.3) llega después.
	dataService.Guardar(player, "modoPuro", valor)
	publicar(player)
	print("[Monetizacion] Modo Puro " .. (valor and "on" or "off") .. " para " .. player.Name)
end

-- Callback de Roblox: solo productos, validados por productId y deduplicados.
local function procesarReciboRoblox(receiptInfo)
	if type(receiptInfo) ~= "table" then
		return Recibo.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Recibo.NotProcessedYet
	end
	-- Sin datos cargados, entregar pisaría el stock y los recibos guardados:
	-- NotProcessedYet hace que Roblox reintente cuando AlCargar haya corrido.
	if not cargados[player] then
		return Recibo.NotProcessedYet
	end
	local purchaseId = receiptInfo.PurchaseId
	if type(purchaseId) ~= "string" or purchaseId == "" then
		return Recibo.NotProcessedYet
	end
	local item
	for _, producto in ipairs(MonetizacionConfig.Productos) do
		if producto.productoId == receiptInfo.ProductId and producto.productoId > 0 then
			item = producto
			break
		end
	end
	if not item or not efectoSoportado(item) then
		warn("[Monetizacion] recibo de producto desconocido: " .. tostring(receiptInfo.ProductId))
		return Recibo.NotProcessedYet
	end
	procesarRecibo(player, purchaseId, item) -- false = ya entregado, sigue siendo Granted
	print("[Monetizacion] recibo " .. purchaseId .. " de " .. player.Name .. " (" .. item.id .. ")")
	return Recibo.PurchaseGranted
end

function MonetizacionService.Iniciar()
	-- Main llama DataService.Iniciar() y TiendaService.Iniciar() antes que este.
	dataService = require(script.Parent.DataService)
	pinasService = require(script.Parent.PinasService)
	playerState = require(script.Parent.PlayerStateService)
	matchService = require(script.Parent.MatchService)

	remotoComprar = Remotes.Crear(Remotes.Nombres.ComprarRobux)
	remotoResultado = Remotes.Crear(Remotes.Nombres.RobuxResult)
	remotoPaseEstado = Remotes.Crear(Remotes.Nombres.PaseEstado)
	remotoReclamar = Remotes.Crear(Remotes.Nombres.ReclamarPase)
	remotoReanimar = Remotes.Crear(Remotes.Nombres.ReanimarPersonal)
	remotoReanimarResultado = Remotes.Crear(Remotes.Nombres.ReanimarResult)
	remotoModoPuro = Remotes.Crear(Remotes.Nombres.ModoPuro)

	permitirComprar = RateLimiter.nuevo(2)
	permitirReclamar = RateLimiter.nuevo(2)
	permitirReanimar = RateLimiter.nuevo(1)
	permitirModoPuro = RateLimiter.nuevo(1)

	remotoComprar.OnServerEvent:Connect(comprarRobux)
	remotoReclamar.OnServerEvent:Connect(reclamarPase)
	remotoReanimar.OnServerEvent:Connect(reanimarPersonal)
	remotoModoPuro.OnServerEvent:Connect(cambiarModoPuro)
	MarketplaceService.ProcessReceipt = procesarReciboRoblox

	local function alEntrar(player)
		reanimacionesPartida[player] = 0
		task.spawn(comprobarPases, player)
		-- Segunda entrega: un LocalScript que arranca tarde no pierde el estado inicial.
		task.delay(3, function()
			publicar(player)
		end)
	end

	Players.PlayerAdded:Connect(alEntrar)
	for _, player in ipairs(Players:GetPlayers()) do
		alEntrar(player)
	end

	-- Datos cargados (AlCargar puede llegar después de la primera comprobación):
	-- republicar deja PaseEstado exacto al entrar.
	dataService.AlCargar.Event:Connect(function(player)
		cargados[player] = true
		publicar(player)
	end)

	-- El límite de reanimación personal es por partida (plan §7.3).
	matchService.AlEmpezar.Event:Connect(function(jugadores)
		for _, player in ipairs(jugadores or {}) do
			reanimacionesPartida[player] = 0
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		pases[player] = nil
		generaciones[player] = nil
		reanimacionesPartida[player] = nil
		cargados[player] = nil
	end)

	print("[Monetizacion] activo: " .. #MonetizacionConfig.Pases .. " pases, "
		.. #MonetizacionConfig.Productos .. " productos, Activo=" .. tostring(MonetizacionConfig.Activo))
end

function MonetizacionService.Estado(player)
	return estadoDe(player)
end

function MonetizacionService.TienePase(player, efecto)
	if type(efecto) ~= "string" then
		return false
	end
	local poseidos = pases[player]
	return poseidos ~= nil and poseidos[efecto] == true
end

function MonetizacionService.RanurasRopa(player)
	return MonetizacionService.TienePase(player, "ranurasRopa") and RANURAS_PASE or RANURAS_BASE
end

function MonetizacionService.MultiplicadorPinas(player)
	local hasta = tonumber(datosDe(player).pinasX2Hasta) or 0
	return hasta > os.time() and 2 or 1
end

function MonetizacionService.EsModoPuro(player)
	return esPuro(player)
end

function MonetizacionService.Refrescar(player)
	if not player or not player.Parent then
		return
	end
	task.spawn(comprobarPases, player)
end

-- Seams de Studio: misma entrega que un recibo válido, sin pasar por Roblox.
-- En producción no existen.
if RunService:IsStudio() then
	function MonetizacionService._ProbarConceder(player, id)
		if not player or not player.Parent or type(id) ~= "string" then
			return false
		end
		local item = MonetizacionConfig.PorId(id)
		if not item then
			return false
		end
		if item.tipo == "pase" and item.efecto then
			pases[player] = pases[player] or {}
			pases[player][item.efecto] = true
			generaciones[player] = (generaciones[player] or 0) + 1 -- invalida comprobaciones en vuelo
			publicar(player)
			if item.efecto == "ranurasRopa" then
				avisarRanuras(player)
			end
			print("[Monetizacion] _ProbarConceder pase " .. id .. " a " .. player.Name)
			return true
		end
		if item.tipo == "producto" and efectoSoportado(item) then
			entregarProducto(player, item)
			print("[Monetizacion] _ProbarConceder producto " .. id .. " a " .. player.Name)
			return true
		end
		return false
	end

	function MonetizacionService._ProbarRecibo(player, purchaseId, id)
		if not player or not player.Parent then
			return false, "Jugador inválido"
		end
		if type(purchaseId) ~= "string" or purchaseId == "" then
			return false, "purchaseId inválido"
		end
		local item = type(id) == "string" and MonetizacionConfig.PorId(id) or nil
		if not item or item.tipo ~= "producto" or not efectoSoportado(item) then
			return false, "Producto inválido"
		end
		local nuevo = table.find(listaRecibos(player), purchaseId) == nil
		procesarRecibo(player, purchaseId, item)
		if nuevo then
			print("[Monetizacion] _ProbarRecibo " .. id .. " (" .. purchaseId .. ") concedido")
			return true, "Concedido"
		end
		print("[Monetizacion] _ProbarRecibo " .. purchaseId .. " repetido: sin duplicar")
		return false, "Recibo repetido: sin duplicar"
	end
end

return MonetizacionService
