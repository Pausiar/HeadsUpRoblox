-- TroncoService: troncos rodantes que barren el sendero (plan §4.3). Patrón Aviso -> Impacto -> Secuela.
-- Aviso 2 s (franja en el suelo) y el tronco cruza el ancho del sendero por la X de un jugador.
-- Servidor autoritativo: el tronco se mueve por código (Anchored) y el daño se resuelve aquí.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)

local TroncoService = {}
local rng = Random.new()
local playerState

local function franjaDeAviso(x, ancho)
	local franja = Instance.new("Part")
	franja.Name = "AvisoTronco"
	franja.Size = Vector3.new(2, 0.2, ancho + 6)
	franja.CFrame = CFrame.new(x, 0.35, 0)
	franja.Color = Color3.fromRGB(180, 40, 30)
	franja.Material = Enum.Material.Neon
	franja.Transparency = 0.5
	franja.Anchored = true
	franja.CanCollide = false
	franja.Parent = workspace
	return franja
end

local function lanzarTronco(x)
	local cfg = Config.Etapa0
	local lado = rng:NextInteger(0, 1) == 0 and 1 or -1
	local aviso = franjaDeAviso(x, cfg.Ancho)

	task.delay(cfg.Troncos.AvisoSeg, function()
		if aviso.Parent then
			aviso:Destroy()
		end

		local tronco = Instance.new("Part")
		tronco.Name = "Tronco"
		tronco.Shape = Enum.PartType.Cylinder
		tronco.Size = Vector3.new(cfg.Troncos.Largo, cfg.Troncos.Diametro, cfg.Troncos.Diametro)
		-- Eje del cilindro a lo largo de X (como un rodillo): cruza el sendero rodando en Z
		tronco.CFrame = CFrame.new(x, 1 + cfg.Troncos.Diametro / 2, lado * (cfg.Ancho / 2 + 8))
		tronco.Color = Color3.fromRGB(117, 82, 45)
		tronco.Material = Enum.Material.Wood
		tronco.Anchored = true
		tronco.CanCollide = false
		tronco.Parent = workspace

		local golpeados = {}
		local radioGolpe = cfg.Troncos.Diametro / 2 + 2.5
		local paso = Vector3.new(0, 0, -lado * cfg.Troncos.Velocidad * 0.03)

		-- Movimiento por código con paso fijo; se destruye al salir del sendero
		task.spawn(function()
			while tronco.Parent and math.abs(tronco.Position.Z) <= cfg.Ancho / 2 + 10 do
				tronco.CFrame += paso
				for _, player in Players:GetPlayers() do
					local char = player.Character
					local raiz = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if raiz and hum and hum.Health > 0 and not golpeados[player] and not playerState.EstaCaido(player) then
						local delta = raiz.Position - tronco.Position
						if math.abs(delta.X) <= cfg.Troncos.Largo / 2 and delta.Magnitude < radioGolpe then
							golpeados[player] = true
							hum:TakeDamage(cfg.Troncos.Danio)
							playerState.Derribar(player, "tronco")
						end
					end
				end
				task.wait(0.03)
			end
			if tronco.Parent then
				tronco:Destroy()
			end
		end)
	end)
end

function TroncoService.Iniciar()
	playerState = require(script.Parent.PlayerStateService)
	local cfg = Config.Etapa0.Troncos

	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(cfg.IntervaloMin, cfg.IntervaloMax))
			local objetivos = {}
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local raiz = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if raiz and hum and hum.Health > 0 and not playerState.EstaCaido(player) then
					table.insert(objetivos, raiz.Position.X)
				end
			end
			if #objetivos > 0 then
				lanzarTronco(objetivos[rng:NextInteger(1, #objetivos)])
			end
		end
	end)

	print("[Tronco] troncos rodantes activos")
end

return TroncoService
