-- FrasesConfig: frases rápidas de cooperación (fase 11 · L4/B8). Sin lógica.
-- Solo ids: el texto vive en Localization.Strings (frase_<id>) para ES/EN.
local FrasesConfig = {}

FrasesConfig.Frases = {
	"ayuda",
	"espera",
	"vamos",
	"cuidado",
	"gracias",
	"arriba",
	"reanimame",
	"doble",
}

FrasesConfig.Enfriamiento = 2 -- s entre frases por jugador (servidor)
FrasesConfig.EnfriamientoIdioma = 0.5 -- s entre avisos de idioma por jugador

return FrasesConfig
