-- HUD de puntos (referencia visual: docs/concept/, ADN en docs/design/design-dna.md)
-- Mismo patrón que Hud.client.lua: panel de madera arriba a la derecha, etiqueta GothamBold.
-- Popups «+N» flotantes con un pool fijo de 4 etiquetas reutilizables (round-robin, nada que destruir).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Mini-tokens de la paleta (ADN: docs/design/design-dna.md)
local MADERA_OSCURA = Color3.fromRGB(62, 42, 24) -- #3E2A18 (panel)
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C (puntos / checkpoint)
local VERDE_LIMA = Color3.fromRGB(139, 195, 74) -- #8BC34A (positivo: reanimar)
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8 (reserva de texto)

local MAX_POPUPS = 4
local SUBIDA = 30 -- px que sube cada popup
local PASO = 26 -- separación vertical por índice de slot
local DURACION = 1 -- s de vida del popup
local POPUP_X = -250 -- alineado con el texto del contador (inset de 10 px)
local POPUP_BASE_Y = 124 -- base del popup, justo sobre el panel de puntos

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HudPuntos"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area: inset superior-izquierdo para no salirse bajo la notch en móviles (P1 apple-design).
local inset = GuiService:GetGuiInset()
local safeArea = Instance.new("UIPadding")
safeArea.PaddingTop = UDim.new(0, inset.Y)
safeArea.PaddingLeft = UDim.new(0, inset.X)
safeArea.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PanelPuntos"
panel.Size = UDim2.fromOffset(240, 40)
panel.Position = UDim2.new(1, -260, 0, 128) -- bajo el panel del HUD (240x96 en y=20)
panel.BackgroundColor3 = MADERA_OSCURA
panel.BorderSizePixel = 0
panel.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 10)
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

local contador = etiqueta(6, 28, AMARILLO)
contador.Text = "Puntos: 0"

-- Pool de popups: 4 TextLabels creados una vez; reutilizar en vez de crear/destruir por evento.
local popups = {}
for i = 1, MAX_POPUPS do
	local p = Instance.new("TextLabel")
	p.Name = "Popup" .. i
	p.Size = UDim2.fromOffset(230, 26)
	p.AnchorPoint = Vector2.new(0, 1) -- anclado por su base para que suba limpio
	p.Position = UDim2.new(1, POPUP_X, 0, POPUP_BASE_Y - (i - 1) * PASO)
	p.BackgroundTransparency = 1
	p.Font = Enum.Font.GothamBold
	p.TextSize = 22
	p.TextXAlignment = Enum.TextXAlignment.Left
	p.TextTransparency = 1
	p.ZIndex = 2
	p.Parent = gui
	popups[i] = { label = p, tween = nil }
end

local siguiente = 1 -- round-robin: si hay más de 4, se reutiliza el slot más viejo

local function lanzarPopup(ganados, color)
	local i = siguiente
	siguiente = siguiente % MAX_POPUPS + 1
	local p = popups[i]
	if p.tween then
		p.tween:Cancel()
	end
	local base = POPUP_BASE_Y - (i - 1) * PASO -- offset Y por índice: se empujan hacia arriba
	local label = p.label
	label.Text = ("+%d"):format(ganados)
	label.TextColor3 = color
	label.TextTransparency = 0
	label.Position = UDim2.new(1, POPUP_X, 0, base)
	p.tween = TweenService:Create(label, TweenInfo.new(DURACION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, POPUP_X, 0, base - SUBIDA),
		TextTransparency = 1,
	})
	p.tween:Play()
end

local totalAnterior = 0

Remotes.Esperar(Remotes.Nombres.Puntos).OnClientEvent:Connect(function(datos)
	local total = datos.puntos or 0
	local ganados = total - totalAnterior
	totalAnterior = total
	contador.Text = ("Puntos: %d"):format(total)
	if ganados <= 0 then
		return -- sin puntos nuevos, sin popup
	end
	local color = (datos.motivo == "reanimar") and VERDE_LIMA or AMARILLO
	lanzarPopup(ganados, color)
end)

print("[HudPuntos] activo")
