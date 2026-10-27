-- PuntosService: acumula puntos por reanimar y checkpoints (plan §4.5).
-- Servidor autoritativo: las sumas solo ocurren aquí, escuchando las señales
-- internas de MatchService y PlayerStateService. FinPartida lee con GetPuntos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PuntosService = {}
local puntos = {} -- [player] = número acumulado en la sesión

local remotoPuntos

local function sumar(player, cantidad, motivo)
	puntos[player] = (puntos[player] or 0) + cantidad
	remotoPuntos:FireClient(player, {
		puntos = puntos[player],
		motivo = motivo,
	})
	print("[Puntos] +" .. cantidad .. " a " .. player.Name .. " (" .. motivo .. "): total " .. puntos[player])
end

function PuntosService.Iniciar()
	remotoPuntos = Remotes.Crear(Remotes.Nombres.Puntos) -- el servidor crea, el cliente espera

	local matchService = require(script.Parent.MatchService)
	matchService.CheckpointAlcanzado.Event:Connect(function(player, _indice)
		sumar(player, Config.Etapa0.Puntos.Checkpoint, "checkpoint")
	end)

	local playerState = require(script.Parent.PlayerStateService)
	playerState.Reanimado.Event:Connect(function(reanimador, jugador)
		-- Solo premia a un jugador que reanima a otro (ayudar, no autocurarse)
		if reanimador and reanimador ~= jugador then
			sumar(reanimador, Config.Etapa0.Puntos.Reanimar, "reanimar")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		puntos[player] = nil
	end)
end

function PuntosService.GetPuntos(player)
	return puntos[player] or 0
end

return PuntosService
