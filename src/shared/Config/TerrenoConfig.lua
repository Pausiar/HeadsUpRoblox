-- TerrenoConfig: datos del mundo voxel, sendero y bosque (fase 9). Sin lógica.
-- El mundo es una cordillera de ~6000 studs de ruta que se genera por teselas.
local TerrenoConfig = {}

TerrenoConfig.Mundo = {
	Semilla = 20261028,
	MinX = -500,
	MaxX = 5600,
	MinZ = -2800,
	MaxZ = 2800,
	BaseY = -12,
	TechoY = 110,
	Celda = 4,
	-- Cordillera: picos que el camino rodea o cruza (fase 9: mundo largo)
	Picos = {
		{ X = 300, Z = 0, Radio = 360, Altura = 56 },
		{ X = 1500, Z = -700, Radio = 520, Altura = 78 },
		{ X = 2600, Z = 900, Radio = 480, Altura = 66 },
		{ X = 3700, Z = -800, Radio = 560, Altura = 88 },
		{ X = 4700, Z = 300, Radio = 500, Altura = 60 },
		{ X = 5400, Z = 1400, Radio = 420, Altura = 52 },
	},
	NieveDesde = 66,
	RocaDesde = 44,
	-- Teselas (streaming): lado en studs, banda lateral de mundo visible, ventana
	-- de carga por delante del líder y de descarga por detrás del rezagado.
	Tile = 160,
	RadioVision = 240,
	CargarAdelante = 480,
	DescargarAtras = 520,
	TilesIniciales = 340, -- ruta inicial construida al arrancar (spawn y tienda)
	TilesPorTick = 1, -- teselas construidas por tick del bucle de streaming
	TickStreaming = 0.12, -- s entre ticks
}

TerrenoConfig.Camino = {
	Ancho = 7,
	Corredor = 18,
	Paso = 4,
	SeparacionCinta = 10,
	Grosor = 1.2,
	Color = Color3.fromRGB(139, 110, 78),
}

TerrenoConfig.Bosque = {
	ArbolesPorTile = 90,
	ArbustosPorTile = 24,
	RocasPorTile = 10,
	SeparacionMinima = 5.5,
	DistanciaMinimaCamino = 9,
	PendienteMaxima = 0.9,
	AlturaMaximaArbol = 54,
	AlturaMinima = 12,
	AlturaMaxima = 30,
	MargenTile = 4,
	IntentosPorArbol = 10,
	ProporcionConifera = 0.85,
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
	MargenTile = 4,
}

TerrenoConfig.Rapida = {
	LongitudMin = 220,
	LongitudMax = 320,
	PasoMin = 45,
	PasoMax = 80,
	SeparacionRuta = 45,
	MargenMapa = 120,
	IntentosWaypoint = 40,
	IntentosInicio = 240,
	RadioInicioMin = 120,
	RadioInicioMax = 240,
	GiroMax = 60,
	WaypointsMin = 7,
	WaypointsMax = 10,
}

-- Historia: camino guiado de ~6000 studs que serpentea por la cordillera.
TerrenoConfig.Historia = {
	LongitudObjetivo = 6000,
	PasoMin = 110,
	PasoMax = 190,
	GiroMax = 65, -- grados por tramo
	ProbabilidadRecodo = 0.16, -- recodos cerrados que rompen la recta
	RecodoMin = 80,
	RecodoMax = 145,
	SeparacionMinima = 120, -- studs entre tramos no consecutivos (sin cruces)
	MargenMapa = 160,
	IntentosWaypoint = 40,
	InicioX = 0,
	InicioZ = 0,
}

TerrenoConfig.Claros = {
	-- Plazas planas a la altura de la ruta: inicio (tienda) y meta (victoria).
	Inicio = { Radio = 32, RadioBosque = 36, Transicion = 16 },
	Meta = { Radio = 40, RadioBosque = 46, Transicion = 18 },
	Madriguera = { X = -60, Z = -60, Radio = 14, RadioBosque = 20, Transicion = 6 },
}

-- Noche cerrada (fase 9): luna azulada, niebla baja y linterna (F) como guía.
-- "Se ve relativamente poco" sin quedar ilegible: el sendero, los postes y la
-- meta (antorchas/neón) siguen recortándose en la oscuridad.
TerrenoConfig.Ambiente = {
	ClockTime = 0.3,
	Brillo = 1.15,
	Ambiente = Color3.fromRGB(40, 48, 64),
	AmbienteExterior = Color3.fromRGB(80, 92, 118),
	Exposicion = 0,
	Atmosfera = {
		Densidad = 0.28,
		Bruma = 2.2,
		Color = Color3.fromRGB(34, 40, 56),
		Decaimiento = Color3.fromRGB(16, 20, 30),
		Deslumbramiento = 0.05,
	},
	ColorCorreccion = {
		Saturacion = 0.82,
		Contraste = 1.12,
		Tinte = Color3.fromRGB(190, 205, 230),
	},
	Bloom = {
		Intensidad = 0.55,
		Tamano = 30,
		Umbral = 0.85,
	},
}

return TerrenoConfig
