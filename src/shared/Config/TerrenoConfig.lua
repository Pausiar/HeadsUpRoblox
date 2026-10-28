-- TerrenoConfig: datos del mundo voxel, sendero y bosque (fase 8). Sin lógica.
local TerrenoConfig = {}

TerrenoConfig.Mundo = {
	Semilla = 20261028,
	MinX = -120,
	MaxX = 500,
	MinZ = -280,
	MaxZ = 280,
	BaseY = -8,
	TechoY = 96,
	Celda = 4,
	Centro = Vector2.new(300, 0),
	RadioMontana = 330,
	AlturaMontana = 58,
	-- Segundo pico de fondo: fuera del alcance de las rutas (los jugadores no lo escalan)
	CentroSecundario = Vector2.new(540, 200),
	RadioSecundario = 160,
	AlturaSecundaria = 100,
	NieveDesde = 60,
	RocaDesde = 42,
}

TerrenoConfig.Camino = {
	Ancho = 7,
	Corredor = 18,
	Paso = 4,
	SeparacionCinta = 6,
	Grosor = 1.2,
	Color = Color3.fromRGB(139, 110, 78),
}

TerrenoConfig.Bosque = {
	Arboles = 460,
	Arbustos = 320,
	Rocas = 150,
	SeparacionMinima = 5.5,
	DistanciaMinimaCamino = 10,
	PendienteMaxima = 0.9,
	AlturaMaximaArbol = 46,
	AlturaMinima = 11,
	AlturaMaxima = 28,
	MargenMapa = 12,
	IntentosPorArbol = 12,
	ProporcionConifera = 0.65,
	AlturaMinimaArbusto = 0.8,
	AlturaMaximaArbusto = 1.7,
	Colores = {
		Tronco = Color3.fromRGB(92, 58, 33),
		Conifera = Color3.fromRGB(38, 82, 46),
		Hoja = Color3.fromRGB(66, 112, 54),
		Arbusto = Color3.fromRGB(80, 128, 60),
		Roca = Color3.fromRGB(110, 106, 100),
	},
}

TerrenoConfig.Rocas = {
	TamanoMin = 2,
	TamanoMax = 5.5,
	MargenMapa = 12,
}

TerrenoConfig.Rapida = {
	LongitudMin = 220,
	LongitudMax = 320,
	PasoMin = 45,
	PasoMax = 80,
	SeparacionRuta = 45,
	MargenMapa = 90,
	IntentosWaypoint = 40,
	IntentosInicio = 240,
	RadioInicioMin = 120,
	RadioInicioMax = 240,
	GiroMax = 60,
	WaypointsMin = 7,
	WaypointsMax = 10,
}

TerrenoConfig.Claros = {
	Inicio = { X = 0, Z = 0, Radio = 24, RadioBosque = 24, Y = 2, Transicion = 8 },
	Madriguera = { X = -60, Z = -60, Radio = 14, RadioBosque = 20, Y = 0, Transicion = 6 },
}

TerrenoConfig.Historia = {
	Waypoints = {
		Vector3.new(0, 0, 0),
		Vector3.new(30, 0, 10),
		Vector3.new(65, 0, -12),
		Vector3.new(100, 0, 22),
		Vector3.new(135, 0, -8),
		Vector3.new(175, 0, 18),
		Vector3.new(215, 0, -18),
		Vector3.new(255, 0, 10),
		Vector3.new(295, 0, -12),
		Vector3.new(340, 0, 0),
	},
}

TerrenoConfig.Ambiente = {
	ClockTime = 16.8,
	Brillo = 2.4,
	Ambiente = Color3.fromRGB(105, 115, 118),
	AmbienteExterior = Color3.fromRGB(142, 152, 138),
	Exposicion = 0.1,
	Atmosfera = {
		Densidad = 0.32,
		Bruma = 3,
		Color = Color3.fromRGB(188, 202, 204),
		Decaimiento = Color3.fromRGB(96, 108, 110),
		Deslumbramiento = 0.15,
	},
	ColorCorreccion = {
		Saturacion = 1,
		Contraste = 1.06,
		Tinte = Color3.fromRGB(255, 248, 236),
	},
	Bloom = {
		Intensidad = 0.25,
		Tamano = 24,
		Umbral = 0.95,
	},
}

return TerrenoConfig
