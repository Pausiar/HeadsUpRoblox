-- Nombres canónicos de remotes (plan §3.3: remotes tipados y validados).
-- El servidor los crea; el cliente los espera. Toda comunicación pasa por aquí.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.Nombres = {
	HudEstado = "HudEstado", -- server -> client: { estado, restante }
	FinPartida = "FinPartida", -- server -> client: { distancia, tiempo, checkpoint, puntos, record, nuevoRecord, victoria? }
	Reintentar = "Reintentar", -- client -> server: reiniciar partida (limitado)
	Puntos = "Puntos", -- server -> client: { puntos, motivo }
	Ranking = "Ranking", -- server -> client: array de { nombre, puntos, distancia } ordenado por puntos
	Personalizacion = "Personalizacion", -- client -> server: { altura, ancho, cabeza } validado en servidor
	TusDatos = "TusDatos", -- server -> client: tabla guardada del jugador tras cargarla del DataStore
	ChatFalso = "ChatFalso", -- server -> client: { nick, texto } de El Doble (filtrado por receptor)
	Pinas = "Pinas", -- server -> client: { pinas, ganadas } al caminar y al cerrar una partida
	Comprar = "Comprar", -- client -> server: { id } del catálogo (TiendaConfig)
	CompraResult = "CompraResult", -- server -> client: { ok, clave, params?, pinas, bebidas?/mejoras? }
	BeberBebida = "BeberBebida", -- client -> server: gastar una bebida comprada (limitado)
	BebidaResult = "BebidaResult", -- server -> client: { ok, clave, params?, bebidas }

	-- Fase 2: lobby formal y ranking de amigos
	LobbyEstado = "LobbyEstado", -- server -> client: { fase, jugadores, modo, min, max, cuenta, host, puedeEmpezar, mensaje? }
	Listo = "Listo", -- client -> server: boolean (cambiar estado de listo)
	CambiarModo = "CambiarModo", -- client -> server: "historia" | "rapida" (solo host)
	Comenzar = "Comenzar", -- client -> server: forzar inicio (solo host, todos listos)
	RankingAmigos = "RankingAmigos", -- server -> client: { fuente, entradas = { { nombre, distancia, tu } }, mensaje? }
	PedirRankingAmigos = "PedirRankingAmigos", -- client -> server: solicitar ranking (limitado)

	-- Fase 4: ropa plan B (patrones sin EditableImage, decisión D7)
	GuardarRopa = "GuardarRopa", -- client -> server: { ranura, patron, color1, color2, pegatina }
	PedirRopa = "PedirRopa", -- client -> server: solicitar estado actual de ropa
	RopaEstado = "RopaEstado", -- server -> client: { activa, ranurasDesbloqueadas, disenos }
	RopaResult = "RopaResult", -- server -> client: { ok, clave, params? }

	-- Fase 5: monetización Robux (los IDs viven en MonetizacionConfig; 0 = sin publicar)
	ComprarRobux = "ComprarRobux", -- client -> server: { id } de MonetizacionConfig
	RobuxResult = "RobuxResult", -- server -> client: { ok, clave, params?, id }
	PaseEstado = "PaseEstado", -- server -> client: { pases, reanimaciones, pinasX2Hasta, modoPuro, activo }
	ReclamarPase = "ReclamarPase", -- client -> server: id del pase tras PromptGamePassPurchaseFinished; el servidor revalida posesión
	ReanimarPersonal = "ReanimarPersonal", -- client -> server: gastar una reanimación personal
	ReanimarResult = "ReanimarResult", -- server -> client: { ok, clave, params? }
	ModoPuro = "ModoPuro", -- client -> server: boolean (modo Puro: sin ventajas ni reanimaciones de pago)

	-- Fase 6: audio y subtítulos (el cliente decide volumen y presentación)
	Sonido = "Sonido", -- server -> client: { id, posicion?, subtitulo? }

	-- Fase 11 · E43: estamina autoritativa en el servidor
	Sprint = "Sprint", -- client -> server: boolean, intención de esprintar (limitado)
	EstaminaEstado = "EstaminaEstado", -- server -> client: { estamina, max, esprintando, bloqueado }
}

function Remotes.Crear(nombre)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	assert(folder, "Remotes: falta la carpeta Remotes en ReplicatedStorage")
	local r = folder:FindFirstChild(nombre)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = nombre
		r.Parent = folder
	end
	return r
end

function Remotes.Esperar(nombre)
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(nombre)
end

return Remotes
