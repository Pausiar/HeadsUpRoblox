-- RankingService: publica cada 2 s el ranking de la partida (plan §4.5).
-- Solo lectura: los datos autoritativos viven en PuntosService y MatchService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RankingService = {}

local INTERVALO = 2 -- segundos entre publicaciones

function RankingService.Iniciar()
	local puntosService = require(script.Parent.PuntosService)
	local matchService = require(script.Parent.MatchService)

	local remotoRanking = Remotes.Crear(Remotes.Nombres.Ranking) -- el servidor crea, el cliente espera

	task.spawn(function()
		while true do
			task.wait(INTERVALO)

			local lista = {}
			for _, player in Players:GetPlayers() do
				table.insert(lista, {
					nombre = player.DisplayName,
					puntos = puntosService.GetPuntos(player),
					distancia = math.round(matchService.ObtenerDistancia(player)),
				})
			end

			-- Desc por puntos; a igualdad, desc por distancia
			table.sort(lista, function(a, b)
				if a.puntos ~= b.puntos then
					return a.puntos > b.puntos
				end
				return a.distancia > b.distancia
			end)

			remotoRanking:FireAllClients(lista) -- la lista vacía también se publica
		end
	end)

	print("[Ranking] activo (cada 2 s)")
end

return RankingService
