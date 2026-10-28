-- PlayerStateService: Sano -> Caído -> Reanimado/Eliminado (plan §3.4).
-- Servidor autoritativo. En el slice, un golpe de roca derriba directamente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlayerStateService = {}
local estados = {} -- [player] = { caido = bool, deadline = number }
local sonido = Remotes.Crear(Remotes.Nombres.Sonido) -- fase 6: reanimación

-- Señal interna para otros servicios del servidor (plan §4.5: reanimar da puntos)
local reanimado = Instance.new("BindableEvent")
PlayerStateService.Reanimado = reanimado -- (reanimador, jugador)

local hud

local function quitarPrompt(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		local viejo = root:FindFirstChild("Reanimar")
		if viejo then
			viejo:Destroy()
		end
	end
end

function PlayerStateService.Derribar(player, motivo)
	local st = estados[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not st or st.caido or not hum or hum.Health <= 0 then
		return
	end
	st.caido = true
	st.deadline = os.clock() + Config.Etapa0.Caido.SegundosParaReanimar
	hum.PlatformStand = true
	hum.WalkSpeed = 0
	quitarPrompt(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Reanimar"
		prompt.ActionText = "Reanimar"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = 1.5
		prompt.Parent = root
		prompt.Triggered:Connect(function(quien)
			if quien ~= player then
				PlayerStateService.Reanimar(player, quien)
			end
		end)
	end
	print("[Estado] caído:", player.Name, "(" .. tostring(motivo) .. ")")
end

function PlayerStateService.Reanimar(player, reanimador)
	local st = estados[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not st or not st.caido or not hum or hum.Health <= 0 then
		return
	end
	st.caido = false
	hum.PlatformStand = false
	hum.WalkSpeed = 16
	hum.Health = math.max(hum.Health, 60)
	quitarPrompt(char)
	reanimado:Fire(reanimador, player)
	sonido:FireClient(player, { id = "Reanimar", subtitulo = AudioConfig.Efectos.Reanimar.subtitulo })
	print("[Estado] reanimado:", player.Name, "por", reanimador and reanimador.Name or "?")
end

function PlayerStateService.EstaCaido(player)
	local st = estados[player]
	return st ~= nil and st.caido
end

function PlayerStateService.Iniciar()
	hud = Remotes.Crear(Remotes.Nombres.HudEstado)

	Players.PlayerAdded:Connect(function(player)
		estados[player] = { caido = false }
		player.CharacterAdded:Connect(function(char)
			estados[player] = { caido = false }
			local hum = char:WaitForChild("Humanoid")
			hum.BreakJointsOnDeath = false
		end)
	end)

	-- Cuenta atrás del caído + HUD (1 Hz, suficiente para el slice)
	task.spawn(function()
		while true do
			task.wait(1)
			for player, st in estados do
				local char = player.Character
				if st.caido then
					if os.clock() > st.deadline then
						st.caido = false
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if hum then
							hum.Health = 0 -- eliminado; espectador llega en fase 2
						end
					end
					hud:FireClient(player, {
						estado = "CAÍDO",
						restante = math.max(0, math.floor(st.deadline - os.clock())),
					})
				else
					hud:FireClient(player, { estado = "Sano" })
				end
			end
		end
	end)
end

return PlayerStateService
