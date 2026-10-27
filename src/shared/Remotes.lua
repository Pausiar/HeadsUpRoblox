-- Nombres canónicos de remotes (plan §3.3: remotes tipados y validados).
-- El servidor los crea; el cliente los espera. Toda comunicación pasa por aquí.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.Nombres = {
	HudEstado = "HudEstado", -- server -> client: { estado, restante }
	FinPartida = "FinPartida", -- server -> client: { distancia, tiempo, checkpoint }
	Reintentar = "Reintentar", -- client -> server: reiniciar partida (limitado)
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
