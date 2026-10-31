-- Empujón (fase 11 · L5b · B10): tecla E empuja al jugador más cercano (≤ 9 studs).
-- El servidor valida todo (EmpujonService): distancia, modo amistoso, caídos y porte.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local TECLA = Enum.KeyCode.E

local function objetivoMasCercano()
	local raiz = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return nil
	end
	local mejor, mejorDist = nil, math.huge
	for _, otro in Players:GetPlayers() do
		if otro ~= player and otro.Character then
			local raizOtro = otro.Character:FindFirstChild("HumanoidRootPart")
			if raizOtro then
				local d = (raizOtro.Position - raiz.Position).Magnitude
				if d < mejorDist then
					mejor, mejorDist = otro, d
				end
			end
		end
	end
	return mejor
end

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado then
		return
	end
	if entrada.KeyCode ~= TECLA then
		return
	end
	if player:GetAttribute("EnJuego") ~= true then
		return
	end
	local objetivo = objetivoMasCercano()
	if objetivo then
		Remotes.Crear(Remotes.Nombres.Empujar):FireServer({ objetivo = objetivo.UserId })
	end
end)

print("[Empujar] activo (E empuja al más cercano)")
