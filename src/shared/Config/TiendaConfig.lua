-- Catálogo de la tienda (plan §7: cosméticos primero; precios en Piñas para la v1).
-- Los productos de Robux/ProcessReceipt llegan cuando el place se publique (fase 5 avanzada).
-- Todo item comprado se guarda en DataService ("comprados") y se aplica en cada spawn.
-- Fase 9: la tienda del campamento añade consumibles ("bebida", stock en "bebidas")
-- y mejoras por niveles ("mejora", nivel en "mejoras"); ni unos ni otros se aplican
-- como cosmético: solo cambian atributos del Player.
local TiendaConfig = {}

TiendaConfig.Moneda = "Piñas"

TiendaConfig.Catalogo = {
	-- Sombreros: AccesoriosService los construye con primitivas (plan B sin catálogo externo)
	{ id = "sombrero_gorro",   nombre = "Gorro de lana",      tipo = "sombrero", precio = 50 },
	{ id = "sombrero_copa",    nombre = "Sombrero de copa",   tipo = "sombrero", precio = 80 },
	{ id = "sombrero_cuernos", nombre = "Cuernos vikingos",   tipo = "sombrero", precio = 120 },
	{ id = "sombrero_chef",    nombre = "Gorro de chef",      tipo = "sombrero", precio = 80 },
	-- Colores de camiseta: CustomizationService los aplica a torso y brazos
	{ id = "camiseta_verde",    nombre = "Camiseta verde",    tipo = "camiseta", precio = 20, color = { 76, 140, 74 } },
	{ id = "camiseta_amarilla", nombre = "Camiseta amarilla", tipo = "camiseta", precio = 20, color = { 255, 201, 60 } },
	{ id = "camiseta_roja",     nombre = "Camiseta roja",     tipo = "camiseta", precio = 20, color = { 224, 69, 58 } },
	{ id = "camiseta_azul",     nombre = "Camiseta azul",     tipo = "camiseta", precio = 20, color = { 63, 127, 191 } },
	-- Consumibles: stock persistido; se gastan al beber (Estamina repone el 25 %).
	{ id = "bebida_energetica", nombre = "Bebida energética", tipo = "bebida", precio = 20, maximo = 5, descripcion = "Recupera 1/4 de resistencia al beberla (tecla Q)", descripcionClave = "descripcion_bebida" },
	-- Mejoras por niveles: el precio se lee de precios[nivel + 1] (TiendaService lo cobra).
	{ id = "mejora_monedas", nombre = "Ojo de lince", tipo = "mejora", mejora = "monedas", precios = { 60, 120, 200 }, maximo = 3, descripcion = "+25% de Piñas al caminar por nivel", descripcionClave = "descripcion_monedas" },
	{ id = "mejora_aguante", nombre = "Botas ligeras", tipo = "mejora", mejora = "aguante", precios = { 60, 120, 200 }, maximo = 3, descripcion = "Cansancio -15% al esprintar por nivel", descripcionClave = "descripcion_aguante" },
}

-- Búsqueda por id (helper compartido para TiendaService y la UI)
function TiendaConfig.PorId(id)
	for _, item in ipairs(TiendaConfig.Catalogo) do
		if item.id == id then
			return item
		end
	end
	return nil
end

return TiendaConfig
