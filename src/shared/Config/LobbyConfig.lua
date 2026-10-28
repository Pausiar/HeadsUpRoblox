-- Config del lobby formal 2–8 (plan §4.1/§9 fase 2). Todo el balance vive aquí.
local LobbyConfig = {}

LobbyConfig.MinJugadores = 2
LobbyConfig.MaxJugadores = 8
LobbyConfig.CuentaAtras = 5 -- s desde que todos están listos hasta el inicio
LobbyConfig.ModoPorDefecto = "historia"
LobbyConfig.Modos = {
	{ id = "historia", nombre = "Historia" },
	{ id = "rapida", nombre = "Ronda rápida" },
}
LobbyConfig.PermitirSoloEnStudio = true -- playtests del MCP con 1 jugador; en vivo exige 2
LobbyConfig.EsperaResultados = 12 -- s entre el fin de partida y la vuelta al lobby
LobbyConfig.EnfriamientoListo = 0.5 -- s entre cambios de listo por jugador
LobbyConfig.EnfriamientoModo = 1 -- s entre cambios de modo
LobbyConfig.EnfriamientoComenzar = 1 -- s entre pulsaciones de EMPEZAR
LobbyConfig.SpawnLobby = Vector3.new(0, 4, 0) -- punto de reunión al volver de una partida

function LobbyConfig.EsModoValido(modo)
	for _, m in ipairs(LobbyConfig.Modos) do
		if m.id == modo then
			return true
		end
	end
	return false
end

return LobbyConfig
