-- MedallasRutaConfig: tiers de medallas por rutas completadas (fase 11 · L5b).
-- Pedido: «cada vez que completes x ruta te den una y la puedas flexear», con
-- colores madera → obsidiana. Son visuales del juego (chip del ranking + panel
-- HUD); NO son las insignias de BadgeService de C28 (esas usan IDs externos).
-- El orden de la tabla ES el de desbloqueo; `rutas` son victorias (metas)
-- acumuladas. `brillo`: los 5 tiers altos llevan Stroke/Tone distinto en el chip.
local MedallasRutaConfig = {}

MedallasRutaConfig.Tiers = {
	{ id = "madera", nombre = "Madera", rutas = 1, color = Color3.fromRGB(139, 110, 78), brillo = false },
	{ id = "bronce", nombre = "Bronce", rutas = 3, color = Color3.fromRGB(176, 110, 58), brillo = false },
	{ id = "plata", nombre = "Plata", rutas = 5, color = Color3.fromRGB(192, 192, 192), brillo = false },
	{ id = "oro", nombre = "Oro", rutas = 10, color = Color3.fromRGB(255, 201, 60), brillo = false },
	{ id = "platino", nombre = "Platino", rutas = 20, color = Color3.fromRGB(229, 228, 226), brillo = true },
	{ id = "diamante", nombre = "Diamante", rutas = 35, color = Color3.fromRGB(120, 219, 226), brillo = true },
	{ id = "esmeralda", nombre = "Esmeralda", rutas = 50, color = Color3.fromRGB(80, 200, 120), brillo = true },
	{ id = "rubi", nombre = "Rubí", rutas = 75, color = Color3.fromRGB(224, 17, 95), brillo = true },
	{ id = "obsidiana", nombre = "Obsidiana", rutas = 100, color = Color3.fromRGB(20, 18, 24), brillo = true },
}

-- Tier por id (nil si no existe).
function MedallasRutaConfig.PorId(id)
	if type(id) ~= "string" then
		return nil
	end
	for _, tier in ipairs(MedallasRutaConfig.Tiers) do
		if tier.id == id then
			return tier
		end
	end
	return nil
end

-- Mayor tier alcanzado con `rutas` completadas (nil si aún no llega a madera).
function MedallasRutaConfig.TierDe(rutas)
	local actual
	for _, tier in ipairs(MedallasRutaConfig.Tiers) do
		if rutas >= tier.rutas then
			actual = tier
		else
			break
		end
	end
	return actual
end

return MedallasRutaConfig
