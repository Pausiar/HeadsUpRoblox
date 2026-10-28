-- Config de monetización Robux (plan §7). Los IDs se crean en el Creator Dashboard
-- y se rellenan aquí al publicar; 0 significa «todavía no existe» y la tienda lo
-- muestra como no disponible. Activo = false evita prompts en Studio.
-- Nada de compras aleatorias de pago en la v1 (plan §7.1/§7.4).
local MonetizacionConfig = {}

MonetizacionConfig.Activo = false
MonetizacionConfig.Moneda = "Robux"
MonetizacionConfig.AvisoNoPublicado = "Disponible al publicar el juego"
MonetizacionConfig.ModoPuroPorDefecto = false

MonetizacionConfig.Pases = {
	{
		id = "ranuras_ropa",
		nombre = "Ranuras de camiseta (3 → 9)",
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
		tipo = "pase",
		paseId = 0,
		precioRobux = 149,
		efecto = "linternaPro",
		disponible = true,
	},
	{
		id = "botas_agarre",
		nombre = "Botas de agarre (+8% de adherencia)",
		tipo = "pase",
		paseId = 0,
		precioRobux = 149,
		efecto = "botasAgarre",
		-- La v1 no tiene sistema de adherencia: no se vende algo sin efecto.
		disponible = false,
	},
	{
		id = "mochila_pro",
		nombre = "Mochila Pro (+1 espacio de inventario)",
		tipo = "pase",
		paseId = 0,
		precioRobux = 199,
		efecto = "mochilaPro",
		-- No hay sistema de inventario en la v1: no se vende algo sin efecto.
		disponible = false,
	},
	{
		id = "club_montanero",
		nombre = "Club Montañero (suscripción)",
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
