-- Config del slice vertical (plan §3.3: todo por datos)
local Config = {}

Config.Etapa0 = {
	Nombre = "Sendero de prueba",
	Longitud = 220,
	Ancho = 14,
	CheckpointCada = 80,
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
}

return Config
