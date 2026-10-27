-- HazardService: rocas que caen (plan §4.3). Patrón Aviso -> Impacto -> Secuela.
-- Aviso 1,5-2,5 s (sombra en el suelo) para que cada golpe sea justo y gracioso.
-- Servidor autoritativo: el daño y el derribo se resuelven aquí.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)

local HazardService = {}
local rng = Random.new()
local playerState

local function sombraDeAviso(pos, radio)
	local disco = Instance.new("Part")
	disco.Name = "AvisoRoca"
	disco.Shape = Enum.PartType.Cylinder
	disco.Size = Vector3.new(0.2, radio * 2, radio * 2)
	disco.CFrame = CFrame.new(pos.X, 0.35, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	disco.Color = Color3.fromRGB(180, 40, 30)
	disco.Material = Enum.Material.Neon
	disco.Transparency = 0.5
	disco.Anchored = true
	disco.CanCollide = false
	disco.Parent = workspace
	return disco
end

function HazardService.SoltarRoca(pos)
	local cfg = Config.Etapa0.Rocas
	local radio = rng:NextNumber(cfg.TamanoMin, cfg.TamanoMax) / 2

	local aviso = sombraDeAviso(pos, radio + 1)

	task.delay(cfg.AvisoSeg, function()
		if aviso.Parent then
			aviso:Destroy()
		end

		local roca = Instance.new("Part")
		roca.Name = "Roca"
		roca.Shape = Enum.PartType.Ball
		roca.Size = Vector3.new(radio * 2, radio * 2, radio * 2)
		roca.CFrame = CFrame.new(pos.X, cfg.AlturaCaida, pos.Z)
		roca.Color = Color3.fromRGB(105, 105, 105)
		roca.Material = Enum.Material.Slate
		roca:SetAttribute("Impactado", false)
		roca.Touched:Connect(function(otra)
			if roca:GetAttribute("Impactado") then
				return
			end
			local char = otra and otra.Parent
			local player = char and Players:GetPlayerFromCharacter(char)
			-- Un caído ya está fuera de combate: no recibe más daño de rocas (plan §4.4)
			if player and not playerState.EstaCaido(player) then
				roca:SetAttribute("Impactado", true)
				local raiz = char:FindFirstChild("HumanoidRootPart")
				if raiz and (raiz.Position - roca.Position).Magnitude <= cfg.RadioImpacto then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						hum:TakeDamage(cfg.Danio)
						playerState.Derribar(player, "roca")
					end
				end
			end
		end)
		roca.Parent = workspace

		-- Secuela: la roca se queda como obstáculo y luego se hunde
		task.delay(6, function()
			if roca.Parent then
				TweenService:Create(
					roca,
					TweenInfo.new(2),
					{ Position = roca.Position - Vector3.new(0, 6, 0), Transparency = 1 }
				):Play()
				task.delay(2.2, function()
					roca:Destroy()
				end)
			end
		end)
	end)
end

function HazardService.Iniciar()
	playerState = require(script.Parent.PlayerStateService)
	local cfg = Config.Etapa0.Rocas

	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(cfg.IntervaloMin, cfg.IntervaloMax))
			local objetivos = {}
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local raiz = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if raiz and hum and hum.Health > 0 and not playerState.EstaCaido(player) then
					table.insert(objetivos, raiz.Position)
				end
			end
			if #objetivos > 0 then
				local objetivo = objetivos[rng:NextInteger(1, #objetivos)]
				local pos = objetivo + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
				HazardService.SoltarRoca(pos)
			end
		end
	end)

	print("[Hazard] rocas activas (aviso 1,8 s)")
end

return HazardService
