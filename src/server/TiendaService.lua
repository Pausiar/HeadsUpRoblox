-- TiendaService: tienda del campamento por Piñas (plan §7). Servidor autoritativo:
-- valida el payload contra TiendaConfig, cobra con PinasService y persiste en
-- DataService (cosméticos en "comprados", stock en "bebidas" y niveles en "mejoras").
-- Los cosméticos se aplican al momento (sombrero → AccesoriosService, camiseta →
-- CustomizationService); bebidas y mejoras solo publican atributos del Player que
-- leen la UI y Estamina. Los Robux/ProcessReceipt viven en MonetizacionService:
-- aquí no se compra nada con dinero real. PolicyService se consulta por
-- cumplimiento (§7.4): el catálogo no tiene compras aleatorias de pago.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PolicyService = game:GetService("PolicyService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TiendaConfig = require(ReplicatedStorage.Shared.Config.TiendaConfig)
local TelemetriaConfig = require(ReplicatedStorage.Shared.Config.TelemetriaConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local TiendaService = {}

local remotoComprar
local remotoResultado
local remotoBeber
local remotoBebidaResultado
local permitirCompra -- RateLimiter.nuevo(1) por jugador
local permitirBeber -- RateLimiter.nuevo(1) por jugador
local dataService -- se asignan en Iniciar: Main llama DataService.Iniciar() antes
local pinasService
local accesorios
local personalizacion
local telemetriaService
local playerState
local monetizacion
local restringidosAleatorios = {} -- [player] = true si PolicyService restringe aleatorios (§7.4)
local cargados = {} -- [player] = true cuando DataService.AlCargar ya corrió

-- Topes del catálogo, para sanear lo persistido (un DataStore manipulado no puede
-- dar más stock ni niveles que los máximos de TiendaConfig). El tope absoluto de
-- bebidas incluye la Mochila Pro (+1), que Modo Puro anula.
local bebidaCatalogo = TiendaConfig.PorId("bebida_energetica")
local BEBIDAS_BASE = bebidaCatalogo and bebidaCatalogo.maximo or 5
local TOPE_BEBIDAS = BEBIDAS_BASE + 1
local TOPE_MEJORAS = 3

local function limiteBebidas(player)
	if monetizacion and player and not monetizacion.EsModoPuro(player)
		and monetizacion.TienePase(player, "mochilaPro") then
		return TOPE_BEBIDAS
	end
	return BEBIDAS_BASE
end

-- Fuente única de compras: DataService.Obtener(player).comprados (lista de ids).
-- Sin caché aparte (plan §3.3: todo por datos). Inicializa la lista si es nil.
local function listaComprados(player)
	local datos = dataService.Obtener(player)
	if type(datos.comprados) ~= "table" then
		datos.comprados = {} -- compras inicialmente vacías
	end
	return datos.comprados
end

-- Lectura pura del progreso de consumo: no escribe en la caché (publicar corre
-- antes de que DataService termine de cargar y escribir ahí bloquearía el merge).
local function estadoConsumo(datos, player)
	local bebidas = math.clamp(math.floor(tonumber(datos.bebidas) or 0), 0, limiteBebidas(player))
	local mejoras = type(datos.mejoras) == "table" and datos.mejoras or {}
	local monedas = math.clamp(math.floor(tonumber(mejoras.monedas) or 0), 0, TOPE_MEJORAS)
	local aguante = math.clamp(math.floor(tonumber(mejoras.aguante) or 0), 0, TOPE_MEJORAS)
	return bebidas, monedas, aguante
end

-- Normaliza la caché viva antes de una compra/consumo (patrón de listaComprados):
-- a partir de aquí "bebidas" y "mejoras" existen siempre y en rango.
local function datosJugador(player)
	local datos = dataService.Obtener(player)
	local bebidas, monedas, aguante = estadoConsumo(datos, player)
	if type(datos.mejoras) ~= "table" then
		datos.mejoras = {}
	end
	datos.bebidas = bebidas
	datos.mejoras.monedas = monedas
	datos.mejoras.aguante = aguante
	return datos
end

-- Atributos que leen la TiendaUI y Estamina: stock de bebidas, factor de cansancio
-- (1 = normal, 0,55 con las Botas ligeras al máximo) y multiplicador de Piñas.
local function publicar(player)
	local bebidas, monedas, aguante = estadoConsumo(dataService.Obtener(player), player)
	player:SetAttribute("Bebidas", bebidas)
	player:SetAttribute("Cansancio", math.clamp(1 - 0.15 * aguante, 0.4, 1))
	player:SetAttribute("MonedasMult", 1 + 0.25 * monedas)
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

-- Multiplicadores de la tienda para PinasService (sin caché propia: el atributo
-- lo publica este servicio y sobrevive a respawns).
function TiendaService.MultiplicadorMonedas(player)
	local valor = tonumber(player:GetAttribute("MonedasMult"))
	if valor and valor >= 1 then
		return valor
	end
	return 1
end

function TiendaService.GetBebidas(player)
	return tonumber(player:GetAttribute("Bebidas")) or 0
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

-- Entrega sin cobro (recibos de Robux y pruebas de Studio): valida el catálogo,
-- añade a "comprados" sin duplicar, persiste y aplica el cosmético.
function TiendaService.ConcederItem(player, id)
	if not dataService then
		warn("[Tienda] ConcederItem antes de Iniciar: sin DataService")
		return false
	end
	if type(id) ~= "string" then
		return false
	end
	local item = TiendaConfig.PorId(id)
	if not item then
		warn("[Tienda] ConcederItem con id desconocido: " .. tostring(id))
		return false
	end
	local comprados = listaComprados(player)
	if not table.find(comprados, id) then
		table.insert(comprados, id)
		dataService.Guardar(player, "comprados", comprados) -- sin cobro: ya pagado en Robux
	end
	aplicarItem(player, item)
	print("[Tienda] concedido " .. item.nombre .. " a " .. player.Name)
	return true
end

-- Telemetría y log de cualquier compra aceptada (mismo embudo para las tres ramas).
local function registrarCompra(player, item, precio)
	if telemetriaService then
		telemetriaService.Evento(player, TelemetriaConfig.Eventos.Compra)
		telemetriaService.Economia(player, false, precio, pinasService.GetPinas(player),
			TelemetriaConfig.Economia.SumideroTienda, item.id)
	end
	print("[Tienda] " .. player.Name .. " compró " .. item.nombre .. " (" .. precio .. " Piñas)")
end

-- Flujo de compra (plan §7): rate limit → validar → consumible/mejora → cosmético
-- (¿ya comprado? re-equipar gratis → cobrar → guardar → aplicar) → responder.
-- shortcut: los mensajes de resultado van en español y la UI los enseña tal cual; con
-- idioma EN la tienda mezcla idiomas. Enviar un código estable y traducirlo en el
-- cliente (L(codigo)) antes del lanzamiento en inglés.
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
	-- Sin datos cargados, escribir stock/niveles pisaría lo persistido: se espera.
	-- (Mismo motivo por el que MonetizacionService deja los recibos para luego.)
	if not cargados[player] then
		remotoResultado:FireClient(player, { ok = false, mensaje = "Cargando…", pinas = pinasService.GetPinas(player) })
		return
	end

	-- Consumible: stock acotado por item.maximo; no entra en "comprados".
	if item.tipo == "bebida" then
		local datos = datosJugador(player)
		if datos.bebidas >= limiteBebidas(player) then
			remotoResultado:FireClient(player, { ok = false, mensaje = "Máximo", pinas = pinasService.GetPinas(player), bebidas = datos.bebidas })
			return
		end
		if not pinasService.Gastar(player, item.precio) then
			remotoResultado:FireClient(player, { ok = false, mensaje = "Piñas insuficientes", pinas = pinasService.GetPinas(player), bebidas = datos.bebidas })
			return
		end
		datos.bebidas += 1
		dataService.Guardar(player, "bebidas", datos.bebidas)
		publicar(player)
		remotoResultado:FireClient(player, { ok = true, mensaje = item.nombre, pinas = pinasService.GetPinas(player), bebidas = datos.bebidas })
		registrarCompra(player, item, item.precio)
		return
	end

	-- Mejora: el nivel actual manda; el precio es el del siguiente nivel.
	if item.tipo == "mejora" then
		local datos = datosJugador(player)
		local nivel = datos.mejoras[item.mejora] or 0
		if nivel >= item.maximo then
			remotoResultado:FireClient(player, {
				ok = false, mensaje = "Máximo", pinas = pinasService.GetPinas(player),
				mejoras = { monedas = datos.mejoras.monedas, aguante = datos.mejoras.aguante },
			})
			return
		end
		local precio = item.precios[nivel + 1]
		if type(precio) ~= "number" then
			warn("[Tienda] catálogo inválido en " .. item.id .. ": falta precios[" .. (nivel + 1) .. "]")
			remotoResultado:FireClient(player, { ok = false, mensaje = "Item no disponible", pinas = pinasService.GetPinas(player) })
			return
		end
		if not pinasService.Gastar(player, precio) then
			remotoResultado:FireClient(player, { ok = false, mensaje = "Piñas insuficientes", pinas = pinasService.GetPinas(player) })
			return
		end
		datos.mejoras[item.mejora] = nivel + 1
		dataService.Guardar(player, "mejoras", datos.mejoras)
		publicar(player)
		remotoResultado:FireClient(player, {
			ok = true, mensaje = item.nombre, pinas = pinasService.GetPinas(player),
			mejoras = { monedas = datos.mejoras.monedas, aguante = datos.mejoras.aguante },
		})
		registrarCompra(player, item, precio)
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
	registrarCompra(player, item, item.precio)
end

function TiendaService.Iniciar()
	-- Se requieren aquí: Main llama DataService.Iniciar() antes que este
	-- (mismo motivo que CustomizationService y AccesoriosService).
	dataService = require(script.Parent.DataService)
	pinasService = require(script.Parent.PinasService)
	accesorios = require(script.Parent.AccesoriosService)
	personalizacion = require(script.Parent.CustomizationService)
	telemetriaService = require(script.Parent.TelemetriaService)
	playerState = require(script.Parent.PlayerStateService)
	monetizacion = require(script.Parent.MonetizacionService)

	permitirCompra = RateLimiter.nuevo(1)
	remotoComprar = Remotes.Crear(Remotes.Nombres.Comprar)
	remotoResultado = Remotes.Crear(Remotes.Nombres.CompraResult)
	remotoComprar.OnServerEvent:Connect(procesarCompra)

	-- Beber: el servidor solo descuenta stock; la estamina la repone el cliente
	-- (es cliente-autoritativa, ver la nota de Estamina.client.lua).
	permitirBeber = RateLimiter.nuevo(1)
	remotoBeber = Remotes.Crear(Remotes.Nombres.BeberBebida)
	remotoBebidaResultado = Remotes.Crear(Remotes.Nombres.BebidaResult)
	remotoBeber.OnServerEvent:Connect(function(player)
		if not permitirBeber(player) then
			return
		end
		if not cargados[player] then
			return -- aún cargando: no tocar el stock persistido
		end
		-- Beber solo sirve en partida, de pie y sin haber cerrado: el servidor
		-- no gasta stock en un estado donde la estamina no se usa.
		if player:GetAttribute("EnJuego") ~= true
			or player:GetAttribute("Terminado") == true
			or playerState.EstaCaido(player) then
			return
		end
		local datos = datosJugador(player)
		if datos.bebidas <= 0 then
			remotoBebidaResultado:FireClient(player, { ok = false, mensaje = "Sin bebidas", bebidas = 0 })
			return
		end
		datos.bebidas -= 1
		dataService.Guardar(player, "bebidas", datos.bebidas)
		publicar(player)
		remotoBebidaResultado:FireClient(player, { ok = true, bebidas = datos.bebidas })
		print("[Tienda] " .. player.Name .. " bebió una bebida (" .. datos.bebidas .. " restantes)")
	end)

	-- Atributos para el cliente en cuanto haya datos; si la carga llega después,
	-- AlCargar republica el valor real (publicar no escribe en la caché).
	dataService.AlCargar.Event:Connect(function(player)
		cargados[player] = true
		publicar(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		publicar(player)
	end

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
		cargados[player] = nil
	end)

	print("[Tienda] lista: " .. #TiendaConfig.Catalogo .. " items")
end

return TiendaService
