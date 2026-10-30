-- QATestHumo: humo de Studio de la partida completa (fase 11 · E49). Main no lo arranca;
-- se invoca con un Script temporal (MCP) y recorre lobby → partida → meta → resultados
-- → reintento → lobby. En un servidor publicado se niega a ejecutar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyConfig = require(ReplicatedStorage.Shared.Config.LobbyConfig)
local LobbyService = require(script.Parent.LobbyService)
local MatchService = require(script.Parent.MatchService)
local StageService = require(script.Parent.StageService)

local QATestHumo = {}

local ESPERA = 15 -- s máximos para cada transición del servidor

local function esperar(condicion, segundos)
	local limite = os.clock() + (segundos or ESPERA)
	repeat
		if condicion() then
			return true
		end
		task.wait(0.2)
	until os.clock() >= limite
	return condicion()
end

local function vivo(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

function QATestHumo.Ejecutar()
	if not RunService:IsStudio() then
		return false, "solo Studio"
	end
	local player = Players:GetPlayers()[1]
	if not player then
		return false, "sin jugador"
	end

	local fallos = {}
	local function revisar(nombre, ok)
		if not ok then
			table.insert(fallos, nombre)
		end
	end

	local checkpoints = 0
	local conexion = MatchService.CheckpointAlcanzado.Event:Connect(function(quien)
		if quien == player then
			checkpoints += 1
		end
	end)
	local roster = { player }

	-- 1) Lobby: el jugador está dentro y la fase es la de espera
	revisar("ruta con checkpoints", StageService.TotalCheckpoints > 0)
	revisar("lobby esperando", esperar(function()
		return LobbyService.GetFase() == "esperando"
	end))
	revisar("participante", table.find(LobbyService.GetParticipantes(), player) ~= nil)
	revisar("fuera de partida", player:GetAttribute("EnJuego") ~= true)

	-- 2) Inicio: la misma llamada que usan el botón del host y REINTENTAR
	revisar("inicio", MatchService.IniciarPartida(roster, "historia", nil) == true)
	revisar("fase partida", LobbyService.GetFase() == "partida")
	revisar("EnJuego", player:GetAttribute("EnJuego") == true)

	-- 3) Meta sin recorrer la ruta: el bucle de 1 Hz cierra checkpoints y meta
	revisar("salto a meta", MatchService._ProbarAvanzarRuta(player) == true)
	revisar("meta", esperar(function()
		return player:GetAttribute("Terminado") == true
	end))
	revisar("resultados", esperar(function()
		return LobbyService.GetFase() == "resultados"
	end))
	revisar("checkpoints 1", checkpoints >= StageService.TotalCheckpoints)

	-- 4) Reintento: cancela la vuelta al lobby y reinicia la misma partida
	revisar("reintento", MatchService.IniciarPartida(roster, "historia", MatchService.GetSemilla(), true) == true)
	revisar("fase partida 2", LobbyService.GetFase() == "partida")
	revisar("reintento limpio", player:GetAttribute("Terminado") == false)
	revisar("vivo tras reintento", esperar(function()
		return vivo(player)
	end))
	revisar("salto a meta 2", MatchService._ProbarAvanzarRuta(player) == true)
	revisar("meta 2", esperar(function()
		return player:GetAttribute("Terminado") == true
	end))
	revisar("checkpoints 2", checkpoints >= 2 * StageService.TotalCheckpoints)

	-- 5) Vuelta automática: el servidor queda como al arrancar
	revisar("vuelta al lobby", esperar(function()
		return LobbyService.GetFase() == "esperando"
	end, LobbyConfig.EsperaResultados + 10))
	revisar("lobby limpio", player:GetAttribute("EnJuego") == false and not MatchService.EstaEnPartida())

	conexion:Disconnect()

	if #fallos > 0 then
		warn("[QA-HUMO] FALLOS: " .. table.concat(fallos, ", "))
		return false, fallos
	end
	print(("[QA-HUMO] OK lobby -> partida -> meta (%d checkpoints) -> resultados -> reintento -> lobby"):format(checkpoints))
	return true
end

return QATestHumo
