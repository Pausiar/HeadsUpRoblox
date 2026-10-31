-- ClimaService (fase 11 · L6, B12): programa eventos de clima autoritativos.
-- Sin daño ni lógica de juego: solo emite el remote Clima; el cliente pinta
-- niebla/ventisca (plan §L6). Solo hay evento si hay jugadores EnJuego: el
-- servidor decide a quién le llega (el fin va a todos para que nadie se quede
-- con niebla pegada si abandona la partida a mitad de evento).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ClimaConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ClimaService = {}

local azar = Random.new()

local nombresTipos = {}
for nombre in pairs(Config.Tipos) do
	table.insert(nombresTipos, nombre)
end

local function jugadoresEnJuego()
	local lista = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("EnJuego") == true then
			table.insert(lista, player)
		end
	end
	return lista
end

function ClimaService.Iniciar()
	local remote = Remotes.Crear(Remotes.Nombres.Clima)

	task.spawn(function()
		while true do
			task.wait(azar:NextNumber(Config.PausaMin, Config.PausaMax))
			local destinatarios = jugadoresEnJuego()
			if #destinatarios > 0 then
				local tipo = nombresTipos[azar:NextInteger(1, #nombresTipos)]
				local duracion = azar:NextInteger(Config.DuracionMin, Config.DuracionMax)
				for _, player in ipairs(destinatarios) do
					remote:FireClient(player, { tipo = tipo, intensidad = 1, duracion = duracion })
				end
				print(("[Clima] evento %s %ds"):format(tipo, duracion))
				task.wait(duracion)
				remote:FireAllClients({
					tipo = Config.Despejado,
					intensidad = 1,
					duracion = Config.Restaurar,
				})
				print("[Clima] despejado")
			end
		end
	end)

	print(("[Clima] servicio activo: evento cada %d-%ds"):format(Config.PausaMin, Config.PausaMax))
end

return ClimaService
