-- ClimaConfig: tipos de clima y ritmo de eventos (fase 11 · L6, B12). Sin lógica.
-- El clima se AÑADE sobre la noche de TerrenoConfig.Ambiente (ClockTime 0.3,
-- AtmosferaBosque): el cliente guarda los valores originales de Lighting y los
-- restaura al terminar cada evento, así la noche nunca queda pisada.
--
-- Nota de documento (AGENTS.md: gana la doc oficial de Roblox): con un
-- Atmosphere en Lighting (lo crea TerrenoService), la niebla clásica
-- FogEnd/FogStart no se renderiza. El efecto visible real viene de
-- Densidad/Bruma (Atmosphere.Density/Haze). FogEnd/FogStart se guardan igual
-- por si un día se quita la Atmosphere y la niebla clásica vuelve a aplicar.
local ClimaConfig = {}

ClimaConfig.Tipos = {
	Ventisca = {
		FogEnd = 120,
		FogStart = 0,
		Brightness = 0.8,
		WindSpeed = 40, -- no es de Lighting: empuje horizontal de la nieve (studs/s²) en el cliente
		Densidad = 0.42, -- Atmosphere.Density
		Bruma = 5, -- Atmosphere.Haze
	},
	Niebla = {
		FogEnd = 180,
		FogStart = 10,
		Brightness = 1.0,
		Densidad = 0.38,
		Bruma = 4,
	},
}

-- Tipo de fin de evento que emite el servidor; el cliente restaura los originales.
ClimaConfig.Despejado = "Despejado"

ClimaConfig.DuracionMin = 20 -- s que dura un evento
ClimaConfig.DuracionMax = 30
ClimaConfig.PausaMin = 60 -- s de calma entre eventos
ClimaConfig.PausaMax = 120
ClimaConfig.Transicion = 4 -- s del tween de entrada en el cliente
ClimaConfig.Restaurar = 2 -- s por defecto del tween de vuelta (el servidor manda su duración)

return ClimaConfig
