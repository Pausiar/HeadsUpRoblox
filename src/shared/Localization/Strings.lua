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
			pinas_ganadas = "Piñas ganadas",
			mejor_equipo = "Mejor del equipo",
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
			ahora_host = "Ahora eres el host",
			servidor_cerrando = "EL SERVIDOR SE ESTÁ CERRANDO", -- ya en mayúsculas: String.upper no cubre «á»
			modo_historia_desc = "Ruta completa con 18 checkpoints.",
			modo_rapida_desc = "Camino aleatorio corto, sin checkpoints.",
			invitar = "Invitar",
			invitar_no_disponible = "No se pudo abrir la invitación",
			carga_cargando = "CARGANDO…",
			carga_tip_sprint = "Esprinta con Shift, pero cuida la estamina.",
			carga_tip_reanimar = "Si alguien cae, acércate y reanímalo.",
			carga_tip_checkpoint = "Cada checkpoint de Historia guarda tu progreso.",
			carga_tip_doble = "El Doble imita el chat: no confíes en todos.",
			carga_tip_pinas = "Las Piñas se ganan caminando y se gastan en la tienda.",
			-- Tutorial del lobby (A1)
			tutorial_titulo = "ASÍ SE JUEGA",
			tutorial_paso = "PASO %d DE %d",
			tutorial_siguiente = "SIGUIENTE",
			tutorial_saltar = "SALTAR",
			tutorial_entendido = "¡ENTENDIDO!",
			tutorial_mover_titulo = "Moverse",
			tutorial_mover_texto = "Usa WASD o el joystick para caminar y trepar por la montaña.",
			tutorial_saltar_titulo = "Saltar y esprintar",
			tutorial_saltar_texto = "ESPACIO para saltar; mantén SHIFT para esprintar. La estamina se agota y se recupera.",
			tutorial_linterna_titulo = "Linterna",
			tutorial_linterna_texto = "Pulsa F para encenderla: es tu única luz en las zonas oscuras.",
			tutorial_caer_titulo = "Caídas y El Doble",
			tutorial_caer_texto = "Si un compañero cae, acércate y reanímalo. Nunca sigas solo a El Doble.",
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
			ranking_solo_puro = "Ranking: solo en Modo Puro",
			si = "SÍ",
			no = "NO",
			comprar = "COMPRAR",
			confirmar_compra = "CONFIRMAR COMPRA",
			equipar = "EQUIPAR",
			activo = "ACTIVO",
			proximamente = "PRÓXIMAMENTE",
			al_publicar = "AL PUBLICAR",
			pinas_insuficientes = "Piñas insuficientes",
			compra_iniciada = "Compra iniciada",
			compra_no_disponible = "Compra no disponible",
			comprobando_pase = "Comprobando pase…",
			-- Resultados de acciones (servidor manda clave + params, fase 11 · E44)
			peticion_invalida = "Petición inválida",
			item_desconocido = "Item desconocido",
			item_no_disponible = "Item no disponible",
			equipado = "Equipado",
			diseno_invalido = "Diseño inválido",
			diseno_guardado = "Diseño guardado",
			compra_invalida = "Compra inválida",
			aviso_no_publicado = "Disponible al publicar el juego",
			no_disponible_version = "No disponible en esta versión",
			abriendo_tienda = "Abriendo tienda…",
			no_estas_caido = "No estás caído",
			partida_terminada = "La partida terminó",
			reanimacion_ya_usada = "Ya usaste tu reanimación en esta partida",
			sin_reanimaciones_ni_pinas = "Sin reanimaciones ni %d Piñas",
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
			g_frases = "G: frases",
			-- Fase 9: meta, tienda de campaña, bebidas y mejoras
			meta = "META",
			has_llegado = "¡HAS LLEGADO A LA META!",
			seguir = "SEGUIR",
			tienda_campamento = "TIENDA DEL CAMPAMENTO",
			bebida = "Bebida energética",
			bebidas = "Bebidas",
			beber = "Beber",
			sin_bebidas = "Sin bebidas",
			bebida_tomada = "¡Bebida tomada!",
			mejoras = "Mejoras",
			nivel = "Nivel",
			maximo = "Máximo",
			descripcion_bebida = "Recupera 1/4 de resistencia",
			descripcion_monedas = "+25% de Piñas al caminar",
			descripcion_aguante = "Cansancio -15% al esprintar",
			-- Nombres de catálogo (tienda de Piñas y de Robux)
			item_sombrero_gorro = "Gorro de lana",
			item_sombrero_copa = "Sombrero de copa",
			item_sombrero_cuernos = "Cuernos vikingos",
			item_sombrero_chef = "Gorro de chef",
			item_camiseta_verde = "Camiseta verde",
			item_camiseta_amarilla = "Camiseta amarilla",
			item_camiseta_roja = "Camiseta roja",
			item_camiseta_azul = "Camiseta azul",
			item_bebida_energetica = "Bebida energética",
			item_mejora_monedas = "Ojo de lince",
			item_mejora_aguante = "Botas ligeras",
			item_ranuras_ropa = "Ranuras de camiseta (3 → 9)",
			item_linterna_pro = "Linterna Pro (+15% de cono)",
			item_botas_agarre = "Botas de agarre (+8% de adherencia)",
			item_mochila_pro = "Mochila Pro (+1 bebida)",
			item_club_montanero = "Club Montañero (suscripción)",
			item_pinas_x2 = "Doble de Piñas (30 min)",
			item_reanimacion_personal = "Reanimación personal",
			item_pack_sombreros = "Pack de sombreros",
			-- Fase 11 · L4: causas de caída, semilla, medallas y frases rápidas
			causa = "Causa",
			caida_arbol = "Te alcanzó un árbol",
			caida_piedra = "Te golpeó una piedra",
			caida_doble = "Te atrapó El Doble",
			caida_vacio = "Caíste al vacío",
			caidas = "Caídas",
			semilla = "Semilla",
			medalla = "Medalla",
			medalla_oro = "ORO",
			medalla_plata = "PLATA",
			medalla_bronce = "BRONCE",
			frases = "Frases",
			frases_titulo = "FRASES RÁPIDAS",
			frase_ayuda = "¡Ayuda!",
			frase_espera = "Espérame",
			frase_vamos = "¡Vamos!",
			frase_cuidado = "¡Cuidado!",
			frase_gracias = "Gracias",
			frase_arriba = "¡Arriba!",
			frase_reanimame = "¡Reanímame!",
			frase_doble = "¡Es El Doble!",
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
			pinas_ganadas = "Pinecones earned",
			mejor_equipo = "Team best",
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
			ahora_host = "You are the host now",
			servidor_cerrando = "THE SERVER IS SHUTTING DOWN",
			modo_historia_desc = "Full route with 18 checkpoints.",
			modo_rapida_desc = "Short random route, no checkpoints.",
			invitar = "Invite",
			invitar_no_disponible = "Couldn't open the invite",
			carga_cargando = "LOADING…",
			carga_tip_sprint = "Sprint with Shift, but watch your stamina.",
			carga_tip_reanimar = "If someone falls, get close and revive them.",
			carga_tip_checkpoint = "Every Story checkpoint saves your progress.",
			carga_tip_doble = "The Double mimics chat: don't trust everyone.",
			carga_tip_pinas = "Pinecones come from walking and buy shop items.",
			-- Lobby tutorial (A1)
			tutorial_titulo = "HOW TO PLAY",
			tutorial_paso = "STEP %d OF %d",
			tutorial_siguiente = "NEXT",
			tutorial_saltar = "SKIP",
			tutorial_entendido = "GOT IT!",
			tutorial_mover_titulo = "Move",
			tutorial_mover_texto = "Use WASD or the joystick to walk and climb the mountain.",
			tutorial_saltar_titulo = "Jump and sprint",
			tutorial_saltar_texto = "SPACE to jump; hold SHIFT to sprint. Stamina drains and refills.",
			tutorial_linterna_titulo = "Flashlight",
			tutorial_linterna_texto = "Press F to turn it on: it's your only light in dark areas.",
			tutorial_caer_titulo = "Falls and El Doble",
			tutorial_caer_texto = "If a teammate falls, get close and revive them. Never follow El Doble alone.",
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
			ranking_solo_puro = "Leaderboard: Pure Mode only",
			si = "YES",
			no = "NO",
			comprar = "BUY",
			confirmar_compra = "CONFIRM PURCHASE",
			equipar = "EQUIP",
			activo = "ACTIVE",
			proximamente = "COMING SOON",
			al_publicar = "WHEN PUBLISHED",
			pinas_insuficientes = "Not enough Pinecones",
			compra_iniciada = "Purchase started",
			compra_no_disponible = "Purchase unavailable",
			comprobando_pase = "Checking pass…",
			-- Action results (server sends key + params, phase 11 · E44)
			peticion_invalida = "Invalid request",
			item_desconocido = "Unknown item",
			item_no_disponible = "Item unavailable",
			equipado = "Equipped",
			diseno_invalido = "Invalid design",
			diseno_guardado = "Design saved",
			compra_invalida = "Invalid purchase",
			aviso_no_publicado = "Available when the game is published",
			no_disponible_version = "Not available in this version",
			abriendo_tienda = "Opening shop…",
			no_estas_caido = "You're not down",
			partida_terminada = "The round is over",
			reanimacion_ya_usada = "You already used your revive this round",
			sin_reanimaciones_ni_pinas = "No revives or %d Pinecones",
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
			g_frases = "G: phrases",
			-- Phase 9: finish, camp shop, drinks and upgrades
			meta = "FINISH",
			has_llegado = "YOU REACHED THE FINISH!",
			seguir = "CONTINUE",
			tienda_campamento = "CAMP SHOP",
			bebida = "Energy drink",
			bebidas = "Drinks",
			beber = "Drink",
			sin_bebidas = "No drinks left",
			bebida_tomada = "Drink down!",
			mejoras = "Upgrades",
			nivel = "Level",
			maximo = "Max",
			descripcion_bebida = "Restores 1/4 stamina",
			descripcion_monedas = "+25% Pinecones from walking",
			descripcion_aguante = "-15% stamina drain",
			-- Catalog names (Pinecone and Robux shops)
			item_sombrero_gorro = "Wool beanie",
			item_sombrero_copa = "Top hat",
			item_sombrero_cuernos = "Viking horns",
			item_sombrero_chef = "Chef hat",
			item_camiseta_verde = "Green shirt",
			item_camiseta_amarilla = "Yellow shirt",
			item_camiseta_roja = "Red shirt",
			item_camiseta_azul = "Blue shirt",
			item_bebida_energetica = "Energy drink",
			item_mejora_monedas = "Lynx eye",
			item_mejora_aguante = "Light boots",
			item_ranuras_ropa = "Shirt slots (3 → 9)",
			item_linterna_pro = "Pro Flashlight (+15% cone)",
			item_botas_agarre = "Grip boots (+8% traction)",
			item_mochila_pro = "Pro Backpack (+1 drink)",
			item_club_montanero = "Mountain Club (subscription)",
			item_pinas_x2 = "Double Pinecones (30 min)",
			item_reanimacion_personal = "Personal revive",
			item_pack_sombreros = "Hat pack",
			-- Phase 11 · L4: fall causes, seed, medals and quick phrases
			causa = "Cause",
			caida_arbol = "A tree got you",
			caida_piedra = "A rock hit you",
			caida_doble = "The Double caught you",
			caida_vacio = "You fell into the void",
			caidas = "Falls",
			semilla = "Seed",
			medalla = "Medal",
			medalla_oro = "GOLD",
			medalla_plata = "SILVER",
			medalla_bronce = "BRONZE",
			frases = "Phrases",
			frases_titulo = "QUICK PHRASES",
			frase_ayuda = "Help!",
			frase_espera = "Wait for me",
			frase_vamos = "Let's go!",
			frase_cuidado = "Watch out!",
			frase_gracias = "Thanks",
			frase_arriba = "Go up!",
			frase_reanimame = "Revive me!",
			frase_doble = "It's the Double!",
		},
	},
}

-- Devuelve el texto de `clave` en el idioma activo; si falta, cae a español
-- y, si tampoco existe, a la propia clave para no romper la UI.
-- `params` es opcional: se aplica con string.format (p. ej. "%d Piñas").
function Localization.L(clave, params)
	local activo = Localization.Tabla[Localization.Idioma]
	local texto = (activo and activo[clave]) or Localization.Tabla.es[clave] or clave
	if type(params) == "table" then
		local ok, formateado = pcall(string.format, texto, table.unpack(params))
		if ok then
			return formateado
		end
	end
	return texto
end

-- Igual que L pero para un idioma explícito: el servidor traduce la frase de cada
-- receptor sin tocar Localization.Idioma, que es global y compartida.
function Localization.LPara(idioma, clave, params)
	local tabla = Localization.Tabla[idioma] or Localization.Tabla.es
	local texto = tabla[clave] or Localization.Tabla.es[clave] or clave
	if type(params) == "table" then
		local ok, formateado = pcall(string.format, texto, table.unpack(params))
		if ok then
			return formateado
		end
	end
	return texto
end

local CAUSAS = {
	arbol = "caida_arbol",
	piedra = "caida_piedra",
	doble = "caida_doble",
	ElDoble = "caida_doble",
	vacio = "caida_vacio",
}

-- Texto de una causa de caída; nil si la causa falta o no se conoce.
function Localization.Causa(causa, idioma)
	local clave = CAUSAS[causa]
	if not clave then
		return nil
	end
	if idioma then
		return Localization.LPara(idioma, clave)
	end
	return Localization.L(clave)
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
