-- HUD mínimo del slice (referencia visual: docs/concept/, ADN en docs/design/design-dna.md)
-- Paleta del ADN: panel marrón #5C3A21, texto crema #F5EBD8, acento verde lima #8BC34A, peligro #E0453A
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HudSlice"
gui.ResetOnSpawn = false
gui.Enabled = false -- solo se enciende con EnJuego (ver aplicarEnJuego)
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area (notch): top va en el Vector2 superior-izquierdo, derecha en el inferior-derecho
local insetSup, insetInf = GuiService:GetGuiInset()
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, insetSup.Y)
padding.PaddingRight = UDim.new(0, insetInf.X)
padding.Parent = gui

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
local deadlineLocal = nil

-- Lobby/menú no son partida: el HUD solo vive con EnJuego. El cronómetro local
-- arranca al entrar a partida para no sumar el tiempo de la sala de espera.
local function aplicarEnJuego()
	local enJuego = player:GetAttribute("EnJuego") == true
	gui.Enabled = enJuego
	if enJuego then
		inicio = os.clock()
		tiempo.Text = "Tiempo: 00:00"
	end
end

player:GetAttributeChangedSignal("EnJuego"):Connect(aplicarEnJuego)
aplicarEnJuego()

Remotes.Esperar(Remotes.Nombres.HudEstado).OnClientEvent:Connect(function(datos)
	if datos.estado == "CAÍDO" then
		deadlineLocal = os.clock() + (datos.restante or 0)
		estado.TextSize = 20
		estado.TextColor3 = Color3.fromRGB(255, 111, 97) -- #FF6F61, contraste ≥ 4.5:1 (revisión apple-design)
	else
		deadlineLocal = nil
		estado.Text = "Sano"
		estado.TextSize = 18
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
	if deadlineLocal then
		estado.Text = ("CAÍDO · %ds"):format(math.max(0, math.ceil(deadlineLocal - os.clock())))
	end
end)

print("[Hud] activo")
