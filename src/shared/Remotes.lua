-- Nombres canónicos de remotes (plan §3.3: remotes tipados y validados).
-- El servidor los crea; el cliente los espera. Toda comunicación pasa por aquí.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.Nombres = {
	HudEstado = "HudEstado", -- server -> client: { estado, restante }
	FinPartida = "FinPartida", -- server -> client: { distancia, tiempo, checkpoint, puntos, record, nuevoRecord }
	Reintentar = "Reintentar", -- client -> server: reiniciar partida (limitado)
	Puntos = "Puntos", -- server -> client: { puntos, motivo }
	Ranking = "Ranking", -- server -> client: array de { nombre, puntos, distancia } ordenado por puntos
	Personalizacion = "Personalizacion", -- client -> server: { altura, ancho, cabeza } validado en servidor
	Empezar = "Empezar", -- client -> server: JUGAR; el servidor pone EnJuego (los atributos de cliente no replican)
	TusDatos = "TusDatos", -- server -> client: tabla guardada del jugador tras cargarla del DataStore
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
