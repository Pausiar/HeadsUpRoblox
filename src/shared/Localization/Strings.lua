-- Tabla de localización ES/EN (plan §8): todo el texto visible del juego vive aquí.
-- NOTA: los textos con formato ("Puntos: %d", "%02d:%02d", "+%d") NO van aquí:
-- son literales de formato con números interpolados y se quedan en cada UI,
-- que compone `L("puntos") .. ": " .. ("%d"):format(valor)` o equivalente.
-- Los valores que solo se usan como rótulo de botón se guardan ya en mayúsculas:
-- `string.upper` de Luau no convierte acentos (ó, ñ) y rompería «PIÑAS» o «SÍ».
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
			lema = "No mires solo al frente…",
			salir_ayuda = "Usa el menú ESC de Roblox para salir",
			sala_no_disponible = "SALA NO DISPONIBLE",
			abriendo = "ABRIENDO…",
			personalizar_fase = "PERSONALIZAR · fase 4",
			ajustes_fase = "AJUSTES · fase siguiente",
			tienda_fase = "TIENDA · fase siguiente",
			tienda = "Tienda",
			-- Fin de partida
			has_caido = "¡HAS CAÍDO!",
			nuevo_record = "¡NUEVO RÉCORD!",
			reintentar = "REINTENTAR",
			reanudando = "REANUDANDO…",
			puntos = "Puntos",
			distancia = "Distancia",
			tiempo = "Tiempo",
			record = "Récord",
			checkpoint = "Checkpoint",
			checkpoint_sin = "sin checkpoint",
			-- HUD de estado
			sano = "Sano",
			caido = "CAÍDO",
			pts = "pts",
			pinas = "Piñas",
			pinas_tab = "PIÑAS",
			-- Ranking
			ranking = "Ranking",
			sin_jugadores = "Sin jugadores",
			tu = "Tú",
			tu_etiqueta = "TÚ",
			-- Ajustes
			volumen_musica = "Volumen de la música",
			volumen_efectos = "Volumen de los efectos",
			sensibilidad = "Sensibilidad",
			reducir_efectos = "Reducir efectos",
			activado = "Activado",
			desactivado = "Desactivado",
			tamano_texto = "Tamaño de texto",
			subtitulos = "Subtítulos",
			-- Lobby
			sala_espera = "SALA DE ESPERA",
			jugadores_listos = "jugadores · todos listos para empezar",
			historia = "HISTORIA",
			ronda_rapida = "RONDA RÁPIDA",
			host = "HOST",
			listo = "Listo",
			esperando = "Esperando",
			cancelar = "Cancelar",
			empezar = "Empezar",
			conectando = "Conectando con la sala…",
			faltan_jugadores = "Faltan jugadores o listos",
			ranking_no_disponible = "Ranking no disponible",
			empieza_en = "EMPIEZA EN",
			empieza_breve = "EMPIEZA EN BREVE…",
			jugador = "Jugador",
			-- Ranking de amigos
			amigos = "Amigos",
			ranking_amigos = "RANKING DE AMIGOS",
			ranking_amigos_sub = "Tu mejor distancia y la de tus amigos",
			ranking_global = "Sin amigos disponibles: top global",
			cargando = "Cargando…",
			sin_marcas = "Aún no hay marcas. ¡Juega una partida!",
			sin_respuesta = "Sin respuesta del servidor. Inténtalo de nuevo.",
			error_ranking = "No se pudo cargar el ranking. Inténtalo de nuevo.",
			ranking_no_disponible_ahora = "Ranking no disponible ahora mismo.",
			cerrar = "Cerrar",
			-- Personalización
			personalizacion = "PERSONALIZACIÓN",
			cuerpo = "Cuerpo",
			ropa = "Ropa",
			altura = "Altura",
			ancho = "Ancho",
			cabeza = "Cabeza",
			aleatorio = "Aleatorio",
			ranura = "Ranura",
			de = "de",
			ranuras_todas = "ranuras · todas desbloqueadas",
			ranuras_extra = "ranuras · las extra llegan con el pase",
			patron = "Patrón",
			pegatina = "Pegatina",
			color_1 = "Color 1",
			color_2 = "Color 2",
			guardar = "Guardar",
			guardado = "GUARDADO",
			cargando_ropa = "Cargando ropa…",
			no_guardar = "No se pudo guardar",
			-- Tienda
			robux = "ROBUX",
			reanimaciones = "Reanimaciones",
			pinas_x2 = "Piñas x2",
			modo_puro = "Modo Puro",
			si = "SÍ",
			no = "NO",
			comprar = "COMPRAR",
			equipar = "EQUIPAR",
			activo = "ACTIVO",
			proximamente = "PRÓXIMAMENTE",
			al_publicar = "AL PUBLICAR",
			pinas_insuficientes = "Piñas insuficientes",
			compra_iniciada = "Compra iniciada",
			compra_no_disponible = "Compra no disponible",
			comprobando_pase = "Comprobando pase…",
			-- Reanimación personal
			reanimacion_personal = "REANIMACIÓN PERSONAL",
			una_reanimacion = "1 reanimación personal",
			reanimaciones_personales = "reanimaciones personales",
			modo_puro_sin_reanimacion = "Modo Puro: sin reanimación de pago",
			reanimando = "REANIMANDO…",
			reanimarme = "REANIMARME",
			reanimado = "REANIMADO",
			no_reanimar = "No se pudo reanimar",
			sin_respuesta_servidor = "Sin respuesta del servidor",
			-- Chat y controles táctiles
			chat_imitador = "Un imitador puede escribir en este chat. No confíes solo en los mensajes.",
			sprint = "Sprint",
			linterna = "Linterna",
			camara = "Cámara",
			sprint_shift = "Sprint: Shift",
			f_linterna = "F: linterna",
			v_camara = "V: cámara",
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
			lema = "Don't just look ahead…",
			salir_ayuda = "Use Roblox's ESC menu to quit",
			sala_no_disponible = "ROOM UNAVAILABLE",
			abriendo = "OPENING…",
			personalizar_fase = "CUSTOMIZE · phase 4",
			ajustes_fase = "SETTINGS · next phase",
			tienda_fase = "SHOP · next phase",
			tienda = "Shop",
			-- End screen
			has_caido = "YOU FELL!",
			nuevo_record = "NEW RECORD!",
			reintentar = "RETRY",
			reanudando = "RESUMING…",
			puntos = "Points",
			distancia = "Distance",
			tiempo = "Time",
			record = "Best",
			checkpoint = "Checkpoint",
			checkpoint_sin = "no checkpoint",
			-- Status HUD
			sano = "Healthy",
			caido = "DOWN",
			pts = "pts",
			pinas = "Pinecones",
			pinas_tab = "PINECONES",
			-- Ranking
			ranking = "Leaderboard",
			sin_jugadores = "No players",
			tu = "You",
			tu_etiqueta = "YOU",
			-- Settings
			volumen_musica = "Music volume",
			volumen_efectos = "SFX volume",
			sensibilidad = "Sensitivity",
			reducir_efectos = "Reduce effects",
			activado = "On",
			desactivado = "Off",
			tamano_texto = "Text size",
			subtitulos = "Subtitles",
			-- Lobby
			sala_espera = "WAITING ROOM",
			jugadores_listos = "players · everyone ready to start",
			historia = "STORY",
			ronda_rapida = "QUICK ROUND",
			host = "HOST",
			listo = "Ready",
			esperando = "Waiting",
			cancelar = "Cancel",
			empezar = "Start",
			conectando = "Connecting to the room…",
			faltan_jugadores = "Waiting for players or ready checks",
			ranking_no_disponible = "Leaderboard unavailable",
			empieza_en = "STARTS IN",
			empieza_breve = "STARTING SOON…",
			jugador = "Player",
			-- Friends leaderboard
			amigos = "Friends",
			ranking_amigos = "FRIENDS LEADERBOARD",
			ranking_amigos_sub = "Your best distance and your friends' best",
			ranking_global = "No friends available: global top",
			cargando = "Loading…",
			sin_marcas = "No records yet. Play a round!",
			sin_respuesta = "No response from the server. Try again.",
			error_ranking = "Couldn't load the leaderboard. Try again.",
			ranking_no_disponible_ahora = "Leaderboard unavailable right now.",
			cerrar = "Close",
			-- Customization
			personalizacion = "CUSTOMIZATION",
			cuerpo = "Body",
			ropa = "Clothes",
			altura = "Height",
			ancho = "Width",
			cabeza = "Head",
			aleatorio = "Random",
			ranura = "Slot",
			de = "of",
			ranuras_todas = "slots · all unlocked",
			ranuras_extra = "slots · extra ones come with the pass",
			patron = "Pattern",
			pegatina = "Sticker",
			color_1 = "Color 1",
			color_2 = "Color 2",
			guardar = "Save",
			guardado = "SAVED",
			cargando_ropa = "Loading clothes…",
			no_guardar = "Couldn't save",
			-- Shop
			robux = "ROBUX",
			reanimaciones = "Revives",
			pinas_x2 = "Pinecones x2",
			modo_puro = "Pure Mode",
			si = "YES",
			no = "NO",
			comprar = "BUY",
			equipar = "EQUIP",
			activo = "ACTIVE",
			proximamente = "COMING SOON",
			al_publicar = "WHEN PUBLISHED",
			pinas_insuficientes = "Not enough Pinecones",
			compra_iniciada = "Purchase started",
			compra_no_disponible = "Purchase unavailable",
			comprobando_pase = "Checking pass…",
			-- Personal revive
			reanimacion_personal = "PERSONAL REVIVE",
			una_reanimacion = "1 personal revive",
			reanimaciones_personales = "personal revives",
			modo_puro_sin_reanimacion = "Pure Mode: no paid revive",
			reanimando = "REVIVING…",
			reanimarme = "REVIVE ME",
			reanimado = "REVIVED",
			no_reanimar = "Couldn't revive",
			sin_respuesta_servidor = "No response from the server",
			-- Chat and touch controls
			chat_imitador = "An imitator can type in this chat. Don't trust messages alone.",
			sprint = "Sprint",
			linterna = "Flashlight",
			camara = "Camera",
			sprint_shift = "Sprint: Shift",
			f_linterna = "F: flashlight",
			v_camara = "V: camera",
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
