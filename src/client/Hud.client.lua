-- HUD mínimo del slice (referencia visual: docs/concept/, ADN en docs/design/design-dna.md)
-- Paleta del ADN: panel marrón #5C3A21, texto crema #F5EBD8, acento verde lima #8BC34A, peligro #E0453A
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HudSlice"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "PanelEstado"
panel.Size = UDim2.fromOffset(240, 96)
panel.Position = UDim2.new(1, -260, 0, 20)
panel.BackgroundColor3 = Color3.fromRGB(62, 42, 24)
panel.BorderSizePixel = 0
panel.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 12)
esquina.Parent = panel

local function etiqueta(y, tamano, color)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -20, 0, tamano)
	t.Position = UDim2.new(0, 10, 0, y)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = tamano - 4
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = color
	t.Parent = panel
	return t
end

local distancia = etiqueta(8, 24, Color3.fromRGB(245, 235, 216))
local tiempo = etiqueta(36, 22, Color3.fromRGB(255, 201, 60))
local estado = etiqueta(64, 22, Color3.fromRGB(139, 195, 74))

distancia.Text = "Distancia: 0 m"
tiempo.Text = "Tiempo: 00:00"
estado.Text = "Sano"

local inicio = os.clock()
local restanteCaido = nil

Remotes.Esperar(Remotes.Nombres.HudEstado).OnClientEvent:Connect(function(datos)
	restanteCaido = datos.restante
	if datos.estado == "CAÍDO" then
		estado.Text = ("CAÍDO · %ds"):format(restanteCaido or 0)
		estado.TextColor3 = Color3.fromRGB(224, 69, 58)
	else
		estado.Text = "Sano"
		estado.TextColor3 = Color3.fromRGB(139, 195, 74)
	end
end)

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if raiz then
		distancia.Text = ("Distancia: %d m"):format(math.max(0, math.floor(raiz.Position.X)))
	end
	local seg = math.floor(os.clock() - inicio)
	tiempo.Text = ("Tiempo: %02d:%02d"):format(seg / 60, seg % 60)
end)

print("[Hud] activo")
