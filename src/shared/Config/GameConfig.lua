-- Config del slice vertical (plan §3.3: todo por datos)
local Config = {}

-- E43: estamina y sprint con autoridad del servidor (EstaminaService).
Config.Estamina = {
	Max = 100,
	Drenaje = 20, -- estamina por segundo esprintando (5 s de sprint lleno)
	Regeneracion = 15, -- estamina por segundo al caminar
	VelocidadBase = 16,
	VelocidadSprint = 24,
	UmbralMinimo = 10, -- tras vaciarse, no se vuelve a esprintar hasta recuperar esto
	Bebida = 25, -- 1/4 de la barra por bebida (TiendaService la repone)
	CansancioMinimo = 0.4, -- suelo del multiplicador de las Botas ligeras
	Ritmo = 10, -- Hz de simulación y publicación del estado
}

-- Fase 11 · L4 (B6): medallas por tiempo relativo a la longitud de la ruta.
-- Los umbrales son segundos por cada 1000 studs: Historia (6000) exige 360 s para
-- oro y Ronda rápida (~270) 16 s. Valores iniciales a ajustar con playtests.
Config.Medallas = {
	SegundosPor1000 = { oro = 60, plata = 90, bronce = 120 },
}

Config.Etapa0 = {
	Nombre = "Sendero de prueba",
	CheckpointCada = 260, -- ruta de ~6000 studs: un poste cada ~15 s de marcha
	ProteccionInicio = 45, -- studs de ruta sin peligros: spawn y tienda siempre seguros
	RadioProgreso = 25, -- fuera de este radio del sendero no se gana distancia ni checkpoints

	-- Fase 11 · L5 · B3: refugio a mitad de ruta (plan §4.4/§8: cobijo, tienda y checkpoint)
	Refugio = {
		EnCheckpoint = 9, -- el refugio se asienta en este checkpoint de la ruta
		RadioSinPeligros = 30, -- HazardService no genera peligros a menos de esto del refugio
	},

	-- Fase 11 · L5 · B9: cargar compañeros caídos (plan §4.4)
	Cargar = {
		VelocidadPortador = 10, -- WalkSpeed del portador mientras carga (base 16)
		PortadoresMax = 1, -- plan §4.4: 1 portador (2 permitidos más adelante)
		RadioCarga = 8, -- distancia máxima para iniciar la carga
		Enfriamiento = 1, -- s entre acciones de cargar/soltar
	},

	-- Fase 11 · L5 · B10: empujón amigo (plan §4.4: impulso suave, sin derribo)
	Empujon = {
		Fuerza = 34, -- impulso horizontal aplicado al empujado
		Alcance = 9, -- distancia máxima para empujar
		Enfriamiento = 3, -- s entre empujones por jugador (plan §4.4)
	},
	-- Fase 9: peligros diegéticos. No hay aviso sonoro ni marca en el suelo:
	-- el árbol que cae es el aviso (se ve venir) y las piedras salen de su copa.
	ArbolesQueCaen = {
		-- La ruta dura ~5 min: un evento cada 3,5–6,5 s derribaba al jugador solo
		-- antes de llegar al primer tramo. 8–13 s deja respirar sin quitar peligro.
		IntervaloMin = 8,
		IntervaloMax = 13,
		RadioBusqueda = 32, -- solo se tumban árboles cercanos al objetivo
		RadioDanio = 6,
		Danio = 30,
		DuracionCaida = 0.9, -- s que tarda el pino en tumbarse
		Reaparicion = 7, -- s tumbado antes de enderezarse
		Probabilidad = 0.55, -- el resto de las veces llueven piedras
	},
	Piedras = {
		RadioBusqueda = 40,
		RadioDanio = 2.2,
		Danio = 12,
		CantidadMin = 3,
		CantidadMax = 5,
		RetardoMin = 0.1,
		RetardoMax = 0.55,
	},
	Meta = {
		Distancia = 10, -- studs del final que cuentan como meta
		BonusPinas = 100,
	},
	Caido = {
		SegundosParaReanimar = 30,
	},
	Match = {
		EnfriamientoReintentar = 3, -- s entre peticiones de reinicio por jugador
	},
	Puntos = {
		Reanimar = 50, -- plan §4.5: premiar ayudar más que la velocidad
		Checkpoint = 10,
	},
	Personalizacion = {
		-- Rangos verificados por el spike S5 (spikes/s5-r15-escalado/README.md)
		AlturaMin = 0.9,
		AlturaMax = 1.05,
		AnchoMin = 0.7,
		AnchoMax = 1.3,
		CabezaMin = 0.85,
		CabezaMax = 1.25,
		Enfriamiento = 1, -- s entre aplicaciones
	},
	Doble = {
		-- plan §5: El Doble. Valores iniciales a ajustar en playtests con grupos reales.
		RetardoAparicion = 45, -- s de partida antes de la fase 1 (Observación)
		DuracionObservacion = 20,
		DuracionInfiltracion = 25,
		DuracionAcecho = 20,
		VentanaRescate = 12, -- s para liberar a la víctima durante el rapto
		MaxRaptos = 2, -- plan §5.4: máximo de raptos por partida
		EnfriamientoRetirada = 60, -- plan §5.2 fase 5
		VelocidadDoble = 18,
	},
	ChatFalso = {
		-- plan §5.5: memoria de ~30 frases por jugador, 60% reales / 40% banco curado
		MemoriaPorJugador = 30,
		IntervaloMin = 25,
		IntervaloMax = 60,
		MaxMensajesPorPartida = 6,
		-- Debt fase 9: umbral que hacía falta en Config (antes constante del servicio)
		UmbralSenuelo = 60, -- studs: si nadie está más cerca, el grupo está lejos (§5.3)
	},
}

return Config
