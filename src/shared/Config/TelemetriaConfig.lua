-- Config de telemetría (plan §9 fase 6). Nombres estables para los embudos y
-- eventos de AnalyticsService; nunca se envían datos personales ni texto libre.
local TelemetriaConfig = {}

TelemetriaConfig.Activo = true

TelemetriaConfig.Eventos = {
	PartidaInicio = "PartidaInicio",
	PartidaFin = "PartidaFin",
	Reanimacion = "Reanimacion",
	Checkpoint = "Checkpoint",
	Rapto = "Rapto",
	Compra = "Compra",
	ReanimacionPersonal = "ReanimacionPersonal",
}

TelemetriaConfig.Economia = {
	Moneda = "Pinas",
	FuentePartida = "Partida",
	SumideroTienda = "Tienda",
}

TelemetriaConfig.Funnel = {
	Nombre = "PrimeraPartida",
	Pasos = {
		{ paso = 1, nombre = "Lobby" },
		{ paso = 2, nombre = "PrimeraEtapa" },
		{ paso = 3, nombre = "PrimerCheckpoint" },
		{ paso = 4, nombre = "PartidaCompletada" },
	},
}

return TelemetriaConfig
