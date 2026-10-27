-- Tabla de localización ES/EN (plan §8): todo el texto visible del juego vive aquí.
-- NOTA: los textos con formato ("Puntos: %d", "%02d:%02d", "+%d") NO van aquí:
-- son literales de formato con números interpolados y se quedan en cada UI,
-- que compone `L("puntos") .. ": " .. ("%d"):format(valor)` o equivalente.
local RunService = game:GetService("RunService")

local Localization = {
	Idioma = "es",
	Soportados = { "es", "en" },
	Tabla = {
		es = {
			-- Menú principal
			titulo = "Heads Up! Mountain Mayhem",
			tagline = "Sube la montaña, cae, ríe",
			subtitulo = "Aventura cooperativa para 2-8 jugadores",
			jugar = "Jugar",
			personalizar = "Personalizar",
			ajustes = "Ajustes",
			salir = "Salir",
			salir_hint = "Toca otra vez para salir",
			en_construccion = "En construcción",
			camara_atajo = "Cámara de atajo",
			volver = "Volver",
			-- Fin de partida
			has_caido = "¡HAS CAÍDO!",
			nuevo_record = "¡NUEVO RÉCORD!",
			reintentar = "REINTENTAR",
			puntos = "Puntos",
			distancia = "Distancia",
			tiempo = "Tiempo",
			record = "Récord",
			checkpoint = "Checkpoint",
			checkpoint_sin = "sin checkpoint",
			-- HUD de estado
			sano = "Sano",
			caido = "CAÍDO",
			-- Ranking
			ranking = "Ranking",
			sin_jugadores = "Sin jugadores",
			tu = "Tú",
			-- Ajustes
			volumen_musica = "Volumen de la música",
			volumen_efectos = "Volumen de los efectos",
			sensibilidad = "Sensibilidad",
			reducir_efectos = "Reducir efectos",
			activado = "Activado",
			desactivado = "Desactivado",
		},
		en = {
			-- Main menu
			titulo = "Heads Up! Mountain Mayhem",
			tagline = "Climb the mountain, fall, laugh",
			subtitulo = "Co-op adventure for 2-8 players",
			jugar = "Play",
			personalizar = "Customize",
			ajustes = "Settings",
			salir = "Quit",
			salir_hint = "Tap again to quit",
			en_construccion = "Under construction",
			camara_atajo = "Shortcut camera",
			volver = "Back",
			-- End screen
			has_caido = "YOU FELL!",
			nuevo_record = "NEW RECORD!",
			reintentar = "RETRY",
			puntos = "Points",
			distancia = "Distance",
			tiempo = "Time",
			record = "Best",
			checkpoint = "Checkpoint",
			checkpoint_sin = "no checkpoint",
			-- Status HUD
			sano = "Healthy",
			caido = "DOWN",
			-- Ranking
			ranking = "Leaderboard",
			sin_jugadores = "No players",
			tu = "You",
			-- Settings
			volumen_musica = "Music volume",
			volumen_efectos = "SFX volume",
			sensibilidad = "Sensitivity",
			reducir_efectos = "Reduce effects",
			activado = "On",
			desactivado = "Off",
		},
	},
}

-- Devuelve el texto de `clave` en el idioma activo; si falta, cae a español
-- y, si tampoco existe, a la propia clave para no romper la UI.
function Localization.L(clave)
	local activo = Localization.Tabla[Localization.Idioma]
	return (activo and activo[clave]) or Localization.Tabla.es[clave] or clave
end

-- Cambia el idioma activo si está en Soportados. Devuelve true si se aplicó.
function Localization.Establecer(idioma)
	for _, soportado in ipairs(Localization.Soportados) do
		if soportado == idioma then
			Localization.Idioma = idioma
			return true
		end
	end
	return false
end

-- Verificación de paridad de claves solo en Studio: ES y EN deben tener exactamente
-- las mismas claves (aviso suave, sin romper la sesión de edición).
if RunService:IsStudio() then
	for _, idioma in ipairs(Localization.Soportados) do
		for clave in pairs(Localization.Tabla.es) do
			if Localization.Tabla[idioma][clave] == nil then
				warn(("[Localization] falta la clave '%s' en el idioma '%s'"):format(clave, idioma))
			end
		end
	end
end

return Localization
