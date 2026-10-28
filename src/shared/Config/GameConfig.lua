-- Config del slice vertical (plan §3.3: todo por datos)
local Config = {}

Config.Etapa0 = {
	Nombre = "Sendero de prueba",
	CheckpointCada = 80,
	ProteccionInicio = 30, -- studs de ruta sin rocas ni troncos: el spawn siempre es seguro
	RadioProgreso = 25, -- fuera de este radio del sendero no se gana distancia ni checkpoints
	Rocas = {
		IntervaloMin = 2.5,
		IntervaloMax = 5,
		AlturaCaida = 45,
		TamanoMin = 3,
		TamanoMax = 5.5,
		AvisoSeg = 1.8, -- plan §4.3: aviso de 1,5 a 2,5 s
		Danio = 35,
		RadioImpacto = 8,
	},
	Troncos = {
		IntervaloMin = 4,
		IntervaloMax = 7,
		AvisoSeg = 2.0,
		Velocidad = 24, -- studs/s cruzando el sendero
		Danio = 30,
		Largo = 10,
		Diametro = 2.4,
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
	},
}

return Config
