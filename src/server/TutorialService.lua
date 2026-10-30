-- Tutorial (fase 11 · A1): el cliente pinta los 4 pasos del lobby; aquí solo se
-- persiste que ya se vio. Sin remoto de lectura: TutorialEstado lleva el flag.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local TutorialService = {}

local dataService
local remotoEstado

local function enviarEstado(player)
	local datos = dataService.Obtener(player)
	if datos.schema == nil then
		return -- perfil aún cargando: AlCargar lo enviará
	end
	remotoEstado:FireClient(player, { visto = datos.tutorialVisto == true })
end

function TutorialService.Iniciar()
	dataService = require(script.Parent.DataService)
	remotoEstado = Remotes.Crear(Remotes.Nombres.TutorialEstado)
	local permitir = RateLimiter.nuevo(2)

	Remotes.Crear(Remotes.Nombres.TutorialVisto).OnServerEvent:Connect(function(player)
		if not permitir(player) then
			return
		end
		local datos = dataService.Obtener(player)
		if datos.tutorialVisto ~= true then
			dataService.Guardar(player, "tutorialVisto", true)
			print("[Tutorial] tutorialVisto guardado para " .. player.Name)
		end
	end)

	dataService.AlCargar.Event:Connect(function(player)
		enviarEstado(player)
		-- Mismo doble envío que LobbyService: el primer FireClient puede llegar
		-- antes de que el cliente conecte OnClientEvent.
		task.delay(2, function()
			if player.Parent then
				enviarEstado(player)
			end
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(enviarEstado, player)
	end

	print("[Tutorial] servicio listo")
end

return TutorialService
