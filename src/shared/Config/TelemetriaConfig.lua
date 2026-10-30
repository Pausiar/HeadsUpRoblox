-- Config de telemetría (plan §9 fase 6). Nombres estables para los embudos y
-- eventos de AnalyticsService; nunca se envían datos personales ni texto libre.
local TelemetriaConfig = {}

TelemetriaConfig.Activo = true

TelemetriaConfig.Eventos = {
	PartidaInicio = "PartidaInicio",
	PartidaFin = "PartidaFin", -- respaldo si el modo no llega en AlTerminar
	PartidaFinHistoria = "PartidaFinHistoria",
	PartidaFinRapida = "PartidaFinRapida",
	Reanimacion = "Reanimacion",
	Checkpoint = "Checkpoint",
	Rapto = "Rapto",
	Compra = "Compra",
	ReanimacionPersonal = "ReanimacionPersonal",
	TiendaAbierta = "TiendaAbierta",
	TiendaPestanaPinas = "TiendaPestanaPinas",
	TiendaPestanaRobux = "TiendaPestanaRobux",
	DatosFallo = "DatosFallo",
}

-- Subconjunto que el cliente puede pedir por el remoto TelemetriaUI: así no puede
-- disparar eventos de servidor (PartidaFin, Compra...) ni inventar nombres.
TelemetriaConfig.EventosUI = {
	[TelemetriaConfig.Eventos.TiendaAbierta] = true,
	[TelemetriaConfig.Eventos.TiendaPestanaPinas] = true,
	[TelemetriaConfig.Eventos.TiendaPestanaRobux] = true,
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
