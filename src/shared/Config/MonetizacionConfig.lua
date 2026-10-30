-- Config de monetización Robux (plan §7). Los IDs se crean en el Creator Dashboard
-- y se rellenan aquí al publicar; 0 significa «todavía no existe» y la tienda lo
-- muestra como no disponible. Activo = false evita prompts en Studio.
-- Nada de compras aleatorias de pago en la v1 (plan §7.1/§7.4).
local MonetizacionConfig = {}

MonetizacionConfig.Activo = false
MonetizacionConfig.Moneda = "Robux"
MonetizacionConfig.AvisoNoPublicadoClave = "aviso_no_publicado"
MonetizacionConfig.ModoPuroPorDefecto = false

MonetizacionConfig.Pases = {
	{
		id = "ranuras_ropa",
		nombre = "Ranuras de camiseta (3 → 9)",
		nombreClave = "item_ranuras_ropa",
		tipo = "pase",
		paseId = 0,
		precioRobux = 149,
		efecto = "ranurasRopa",
		valor = 9,
		disponible = true,
	},
	{
		id = "linterna_pro",
		nombre = "Linterna Pro (+15% de cono)",
		nombreClave = "item_linterna_pro",
		tipo = "pase",
		paseId = 0,
		precioRobux = 149,
		efecto = "linternaPro",
		disponible = true,
	},
	{
		id = "botas_agarre",
		nombre = "Botas de agarre (+8% de adherencia)",
		nombreClave = "item_botas_agarre",
		tipo = "pase",
		paseId = 0,
		precioRobux = 149,
		efecto = "botasAgarre",
		-- La v1 no tiene sistema de adherencia: no se vende algo sin efecto.
		disponible = false,
	},
	{
		id = "mochila_pro",
		nombre = "Mochila Pro (+1 bebida)",
		nombreClave = "item_mochila_pro",
		tipo = "pase",
		paseId = 0,
		precioRobux = 199,
		efecto = "mochilaPro",
		-- +1 al tope de bebidas (5 → 6); TiendaService lo aplica y Modo Puro lo anula.
		disponible = true,
	},
	{
		id = "club_montanero",
		nombre = "Club Montañero (suscripción)",
		nombreClave = "item_club_montanero",
		tipo = "suscripcion",
		paseId = 0,
		precioRobux = 0,
		efecto = "club",
		disponible = false, -- validar API de suscripciones antes de venderlo
	},
}

MonetizacionConfig.Productos = {
	{
		id = "pinas_x2",
		nombre = "Doble de Piñas (30 min)",
		nombreClave = "item_pinas_x2",
		tipo = "producto",
		productoId = 0,
		precioRobux = 49,
		efecto = "pinasX2",
		duracion = 1800,
		disponible = true,
	},
	{
		id = "reanimacion_personal",
		nombre = "Reanimación personal",
		nombreClave = "item_reanimacion_personal",
		tipo = "producto",
		productoId = 0,
		precioRobux = 25,
		efecto = "reanimacion",
		usos = 1,
		costoPinas = 100, -- alternativa a gastar stock (plan §7.3)
		limitePorPartida = 1,
		disponible = true,
	},
	{
		id = "pack_sombreros",
		nombre = "Pack de sombreros",
		nombreClave = "item_pack_sombreros",
		tipo = "producto",
		productoId = 0,
		precioRobux = 199,
		efecto = "cosmetico",
		items = { "sombrero_copa", "sombrero_cuernos", "sombrero_chef" },
		disponible = true,
	},
}

local function buscar(id)
	for _, item in ipairs(MonetizacionConfig.Pases) do
		if item.id == id then
			return item
		end
	end
	for _, item in ipairs(MonetizacionConfig.Productos) do
		if item.id == id then
			return item
		end
	end
	return nil
end

function MonetizacionConfig.PorId(id)
	return buscar(id)
end

function MonetizacionConfig.Todos()
	local lista = {}
	for _, item in ipairs(MonetizacionConfig.Pases) do
		table.insert(lista, item)
	end
	for _, item in ipairs(MonetizacionConfig.Productos) do
		table.insert(lista, item)
	end
	return lista
end

return MonetizacionConfig
