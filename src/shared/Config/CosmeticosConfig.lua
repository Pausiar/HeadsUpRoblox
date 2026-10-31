-- CosmeticosConfig (C30 · plan §L8): piezas procedurales de pago en Piñas.
-- Decisión de estructura: los 8 ids viven TAMBIÉN en TiendaConfig.Catalogo
-- (tipo "cosmetico", campo cosmetico = id) para que la COMPRA pase por el flujo
-- único de TiendaService.procesarCompra; aquí vive la CONSTRUCCIÓN (tipo real
-- mochila/estela + color) y es la lista que pinta la sección COSMÉTICOS de la UI.
-- mochila: caja 1,6 x 2 x 0,8 soldada a la espalda del torso (servidor, patrón
-- de los sombreros de AccesoriosService).
-- estela: Trail SOLO CLIENTE — el servidor publica el atributo "Estela" del
-- personaje y cada cliente construye su Trail local (TiendaUI, plan §L8).
-- Colores del ADN visual (docs/design/design-dna.md).
local CosmeticosConfig = {}

CosmeticosConfig.Catalogo = {
	-- 3 mochilas: verde, roja y azul de la paleta (mismos RGB que las camisetas).
	{ id = "mochila_verde",   nombre = "Mochila verde",   tipo = "mochila", precio = 40, color = { 76, 140, 74 } },
	{ id = "mochila_roja",    nombre = "Mochila roja",    tipo = "mochila", precio = 40, color = { 224, 69, 58 } },
	{ id = "mochila_azul",    nombre = "Mochila azul",    tipo = "mochila", precio = 40, color = { 63, 127, 191 } },
	-- 5 estelas: color y color2 (opcional) definen el gradiente del Trail;
	-- la arcoíris usa una secuencia fija de 5 colores (TiendaUI la conoce por id).
	{ id = "estela_fuego",    nombre = "Estela de fuego", tipo = "estela", precio = 60, color = { 224, 69, 58 }, color2 = { 255, 201, 60 } },
	{ id = "estela_hielo",    nombre = "Estela de hielo", tipo = "estela", precio = 60, color = { 63, 127, 191 }, color2 = { 245, 235, 216 } },
	{ id = "estela_verde",    nombre = "Estela verde",    tipo = "estela", precio = 60, color = { 76, 140, 74 } },
	{ id = "estela_amarilla", nombre = "Estela amarilla", tipo = "estela", precio = 60, color = { 255, 201, 60 } },
	{ id = "estela_arcoiris", nombre = "Estela arcoíris", tipo = "estela", precio = 100, arcoiris = true },
}

-- ids de desequipación que EquiparCosmetico acepta siempre (sin poseer nada).
CosmeticosConfig.Quitar = { mochila = "quitar_mochila", estela = "quitar_estela" }

-- Búsqueda por id (helper compartido, mismo patrón que TiendaConfig.PorId)
function CosmeticosConfig.PorId(id)
	for _, item in ipairs(CosmeticosConfig.Catalogo) do
		if item.id == id then
			return item
		end
	end
	return nil
end

return CosmeticosConfig
