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
local renacer -- asignado en Iniciar() con pcall; nil = multiplicador 1 (sin renacimiento)

local function sumar(player, cantidad, motivo)
	puntos[player] = (puntos[player] or 0) + cantidad
	remotoPuntos:FireClient(player, {
		puntos = puntos[player],
		motivo = motivo,
	})
	print("[Puntos] +" .. cantidad .. " a " .. player.Name .. " (" .. motivo .. "): total " .. puntos[player])
end

-- Renacimiento (L5b): los buffs multiplican SOLO los puntos de base (checkpoint
-- y reanimar), nunca los bonus de meta. require con pcall: si el servicio falta,
-- multiplicador 1 (patrón bengala tolerado).
local function puntosBase(player, base)
	if not renacer then
		return base
	end
	return math.round(base * renacer.MultiplicadorPuntos(player))
end

function PuntosService.Iniciar()
	remotoPuntos = Remotes.Crear(Remotes.Nombres.Puntos) -- el servidor crea, el cliente espera

	local okRen, resRen = pcall(require, script.Parent.RenacimientoService)
	if okRen then
		renacer = resRen
	else
		warn("[Puntos] sin RenacimientoService: los puntos base van sin multiplicador")
	end

	local matchService = require(script.Parent.MatchService)
	matchService.CheckpointAlcanzado.Event:Connect(function(player, _indice)
		sumar(player, puntosBase(player, Config.Etapa0.Puntos.Checkpoint), "checkpoint")
	end)

	local playerState = require(script.Parent.PlayerStateService)
	playerState.Reanimado.Event:Connect(function(reanimador, jugador)
		-- Solo premia a un jugador que reanima a otro (ayudar, no autocurarse)
		if reanimador and reanimador ~= jugador then
			sumar(reanimador, puntosBase(reanimador, Config.Etapa0.Puntos.Reanimar), "reanimar")
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
