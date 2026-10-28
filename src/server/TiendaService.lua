-- TiendaService: tienda de cosméticos por Piñas (plan §7). Servidor autoritativo:
-- valida el payload contra TiendaConfig, cobra con PinasService, marca la compra
-- en DataService ("comprados") y aplica el item (sombrero → AccesoriosService,
-- camiseta → CustomizationService). Los Robux/ProcessReceipt llegan al publicar
-- el place; hoy solo la moneda blanda. PolicyService se consulta por cumplimiento
-- (§7.4): el catálogo no tiene compras aleatorias de pago.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PolicyService = game:GetService("PolicyService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TiendaConfig = require(ReplicatedStorage.Shared.Config.TiendaConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local TiendaService = {}

local remotoComprar
local remotoResultado
local permitirCompra -- RateLimiter.nuevo(1) por jugador
local dataService -- se asignan en Iniciar: Main llama DataService.Iniciar() antes
local pinasService
local accesorios
local personalizacion
local restringidosAleatorios = {} -- [player] = true si PolicyService restringe aleatorios (§7.4)

-- Fuente única de compras: DataService.Obtener(player).comprados (lista de ids).
-- Sin caché aparte (plan §3.3: todo por datos). Inicializa la lista si es nil.
local function listaComprados(player)
	local datos = dataService.Obtener(player)
	if type(datos.comprados) ~= "table" then
		datos.comprados = {} -- compras inicialmente vacías
	end
	return datos.comprados
end

-- Lectura pura para terceros (UI, spawns): no inicializa nada.
function TiendaService.YaComprado(player, id)
	if type(id) ~= "string" then
		return false
	end
	local datos = dataService.Obtener(player)
	local comprados = type(datos) == "table" and datos.comprados
	if type(comprados) ~= "table" then
		return false
	end
	return table.find(comprados, id) ~= nil
end

-- Aplica el item ya validado. pcall porque aplicar no debe tumbar la respuesta
-- (y menos tras cobrar): si falla, la compra queda guardada y el jugador puede
-- re-equiparla gratis más tarde (el id ya está en "comprados").
local function aplicarItem(player, item)
	local ok, err
	if item.tipo == "sombrero" then
		ok, err = pcall(accesorios.EquiparSombrero, player, item.id)
	elseif item.tipo == "camiseta" then
		ok, err = pcall(personalizacion.ElegirColorCamiseta, player, item.color)
	end
	if ok == false then
		warn("[Tienda] fallo al aplicar " .. item.id .. ": " .. tostring(err))
	end
end

-- Flujo de compra (plan §7): rate limit → validar → ¿ya comprado? re-equipar
-- gratis → cobrar → guardar → aplicar → responder.
local function procesarCompra(player, payload)
	if not permitirCompra(player) then
		return
	end
	if type(payload) ~= "table" or type(payload.id) ~= "string" then
		remotoResultado:FireClient(player, { ok = false, mensaje = "Petición inválida", pinas = pinasService.GetPinas(player) })
		return
	end
	local item = TiendaConfig.PorId(payload.id)
	if not item then
		remotoResultado:FireClient(player, { ok = false, mensaje = "Item desconocido", pinas = pinasService.GetPinas(player) })
		return
	end

	-- Ya propietario: re-equipar gratis (nunca se cobra dos veces).
	if table.find(listaComprados(player), payload.id) then
		aplicarItem(player, item)
		remotoResultado:FireClient(player, { ok = true, mensaje = "Equipado", pinas = pinasService.GetPinas(player) })
		return
	end

	-- Compra nueva: el servidor decide si hay saldo y descuenta.
	if not pinasService.Gastar(player, item.precio) then
		remotoResultado:FireClient(player, { ok = false, mensaje = "Piñas insuficientes", pinas = pinasService.GetPinas(player) })
		return
	end
	local comprados = listaComprados(player)
	table.insert(comprados, payload.id)
	dataService.Guardar(player, "comprados", comprados) -- marca sucio para autoguardado
	aplicarItem(player, item)
	remotoResultado:FireClient(player, { ok = true, mensaje = item.nombre, pinas = pinasService.GetPinas(player) })
	print("[Tienda] " .. player.Name .. " compró " .. item.nombre .. " (" .. item.precio .. " Piñas)")
end

function TiendaService.Iniciar()
	-- Se requieren aquí: Main llama DataService.Iniciar() antes que este
	-- (mismo motivo que CustomizationService y AccesoriosService).
	dataService = require(script.Parent.DataService)
	pinasService = require(script.Parent.PinasService)
	accesorios = require(script.Parent.AccesoriosService)
	personalizacion = require(script.Parent.CustomizationService)

	permitirCompra = RateLimiter.nuevo(1)
	remotoComprar = Remotes.Crear(Remotes.Nombres.Comprar)
	remotoResultado = Remotes.Crear(Remotes.Nombres.CompraResult)
	remotoComprar.OnServerEvent:Connect(procesarCompra)

	-- Cumplimiento §7.4: se consulta la política y se registra si el jugador
	-- tiene restringidas las compras aleatorias de pago. El catálogo no tiene
	-- aleatorios: si aparece la restricción, se deja constancia y nada que bloquear.
	local function consultarPolitica(player)
		local ok, politica = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and type(politica) == "table" and politica.ArePaidRandomItemsRestricted then
			restringidosAleatorios[player] = true
			print("[Tienda] " .. player.Name
				.. " con aleatorios restringidos: el catálogo no tiene aleatorios, sin impacto")
		end
	end

	Players.PlayerAdded:Connect(consultarPolitica)
	-- Carrera con Iniciar: consultar también a los ya conectados.
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(consultarPolitica, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		restringidosAleatorios[player] = nil
	end)

	print("[Tienda] lista: " .. #TiendaConfig.Catalogo .. " items")
end

return TiendaService
