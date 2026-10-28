-- Config de ropa plan B (plan §6, decisión D7: EditableImage bloqueado hasta
-- verificar la ID de la cuenta). Los diseños se pintan con SurfaceGui + Frames
-- sobre el torso: no necesitan subir imágenes ni assets, y se replican solos.
local RopaConfig = {}

RopaConfig.Modo = "planB" -- "editableImage" llegará tras el spike S1 con ID verificada
RopaConfig.RanurasGratis = 3
RopaConfig.RanurasMax = 9

RopaConfig.Colores = {
	{ id = "verde", nombre = "Verde bosque", rgb = { 76, 140, 74 } },
	{ id = "amarillo", nombre = "Amarillo sol", rgb = { 255, 201, 60 } },
	{ id = "rojo", nombre = "Rojo piña", rgb = { 224, 69, 58 } },
	{ id = "azul", nombre = "Azul cielo", rgb = { 63, 127, 191 } },
	{ id = "crema", nombre = "Crema", rgb = { 245, 235, 216 } },
	{ id = "marron", nombre = "Marrón madera", rgb = { 92, 58, 33 } },
	{ id = "naranja", nombre = "Naranja", rgb = { 230, 126, 34 } },
	{ id = "blanco", nombre = "Blanco", rgb = { 245, 245, 240 } },
}

RopaConfig.Patrones = {
	{ id = "lisa", nombre = "Lisa" },
	{ id = "franjas", nombre = "Franjas" },
	{ id = "cuadros", nombre = "Cuadros" },
	{ id = "estrella", nombre = "Estrella" },
	{ id = "montana", nombre = "Montaña" },
}

RopaConfig.Pegatinas = {
	{ id = "ninguna", nombre = "Ninguna" },
	{ id = "pina", nombre = "Piña" },
	{ id = "roca", nombre = "Roca" },
	{ id = "arbol", nombre = "Árbol" },
	{ id = "huella", nombre = "Huella" },
}

RopaConfig.PorDefecto = {
	patron = "lisa",
	color1 = { 76, 140, 74 },
	color2 = { 245, 235, 216 },
	pegatina = "ninguna",
}

local function porId(lista, id)
	for _, item in ipairs(lista) do
		if item.id == id then
			return item
		end
	end
	return nil
end

function RopaConfig.ColorPorId(id)
	return porId(RopaConfig.Colores, id)
end

function RopaConfig.PatronPorId(id)
	return porId(RopaConfig.Patrones, id)
end

function RopaConfig.PegatinaPorId(id)
	return porId(RopaConfig.Pegatinas, id)
end

return RopaConfig
