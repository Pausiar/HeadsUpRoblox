-- Pantalla de CRÉDITOS: atribución legal CC-BY 4.0 de los 9 modelos de Sketchfab.
-- Fuente de verdad: assets-source/CREDITS.md (actualizar ahí primero y replicar aquí).
-- Los datos son estáticos y legales: van hardcodeados y sin localizar. Patrón de panel,
-- safe area y contrato de VOLVER reutilizados de MenuAjustes.client.lua; ADN visual en
-- docs/design/design-dna.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local MenuCamara = require(script.Parent:WaitForChild("MenuCamara"))

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer

-- Paleta del ADN
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C

-- Atribución CC-BY 4.0: «Modelo — Autor» según assets-source/CREDITS.md.
local SECCIONES = {
	{
		titulo = "MODELOS",
		lineas = {
			"Free Low Poly Forest — purepoly",
			"Low Poly Forest Pack .Free 3D Models — RenderHaven",
			"Free Pack - Tree — PolyOne Studio",
			"Free Pack - Rocks Stylized — PolyOne Studio",
			"Low-Poly Toy Pack (Teddy Bear & Rubber Duck) — Renend Studio",
			"Stylized Mushrooms - Low Poly — Camille Barral",
			"Lowpoly Office Chair — sleepyjoshua",
			"Backpack low-poly — dimaponomar2019",
			"Low poly character (rigged) — Sebastian Lague",
		},
	},
	{ titulo = "TIPOGRAFÍA", lineas = { "Gotham / Montserrat — Roblox" } },
	{ titulo = "EQUIPO", lineas = { "Heads Up! Mountain Mayhem — concepto y desarrollo: Pausiar" } },
}

local gui = Instance.new("ScreenGui")
gui.Name = "CreditosUI"
gui.Enabled = false
gui.DisplayOrder = 58
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
MenuCamara.Vincular(gui)

-- Safe area móvil en los cuatro lados. UIPadding solo aplica a GuiObject, así que el
-- relleno va en un contenedor a pantalla completa y no directamente en el ScreenGui.
local insetSup, insetInf = GuiService:GetGuiInset()
local contenedor = Instance.new("Frame")
contenedor.Name = "SafeArea"
contenedor.Size = UDim2.fromScale(1, 1)
contenedor.BackgroundTransparency = 1
contenedor.Parent = gui

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, insetSup.Y)
pad.PaddingLeft = UDim.new(0, insetSup.X)
pad.PaddingRight = UDim.new(0, insetInf.X)
pad.PaddingBottom = UDim.new(0, insetInf.Y)
pad.Parent = contenedor

-- Panel nominal 500x440, centrado. En pantallas cortas se escala el conjunto con el
-- mismo suelo 0,7 de MenuInicio: 440 * 0,7 = 308 px caben en el móvil apaisado de
-- 338 px, así que VOLVER nunca queda fuera del área táctil y no hace falta scroll exterior.
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(500, 440)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = contenedor

local esquinaPanel = Instance.new("UICorner")
esquinaPanel.CornerRadius = UDim.new(0, 16)
esquinaPanel.Parent = panel

local escala = Instance.new("UIScale")
escala.Parent = panel
local function ajustarEscala()
	local ancho, alto = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	escala.Scale = math.clamp(math.min(ancho / 540, alto / 480), 0.7, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio)
	esquina.Parent = objeto
end

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, 0, 0, 32)
titulo.Position = UDim2.new(0, 0, 0, 10)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 30
titulo.Text = L("creditos")
titulo.TextColor3 = CREMA
titulo.Parent = panel

-- Listado con desplazamiento propio (300 px): los nombres largos de los modelos no caben
-- en fijo. AutomaticCanvasSize + AutomaticSize.Y calculan el lienzo solos, sin contar
-- alturas a mano; el margen derecho de las filas deja sitio a la barra de 4 px.
local lista = Instance.new("ScrollingFrame")
lista.Name = "Lista"
lista.Position = UDim2.new(0, 20, 0, 50)
lista.Size = UDim2.new(1, -40, 0, 300)
lista.BackgroundTransparency = 1
lista.BorderSizePixel = 0
lista.ScrollBarThickness = 4
lista.ScrollBarImageColor3 = CREMA
lista.ScrollingDirection = Enum.ScrollingDirection.Y
lista.CanvasSize = UDim2.fromOffset(0, 0)
lista.AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y
lista.Parent = panel

local orden = Instance.new("UIListLayout")
orden.SortOrder = Enum.SortOrder.LayoutOrder
orden.Padding = UDim.new(0, 2)
orden.Parent = lista

local ordenLinea = 0
for _, seccion in ipairs(SECCIONES) do
	ordenLinea += 1
	local cabecera = Instance.new("TextLabel")
	cabecera.Size = UDim2.new(1, -20, 0, 24)
	cabecera.BackgroundTransparency = 1
	cabecera.Font = Enum.Font.GothamBold
	cabecera.TextSize = 18
	cabecera.TextXAlignment = Enum.TextXAlignment.Left
	cabecera.TextColor3 = AMARILLO
	cabecera.Text = seccion.titulo
	cabecera.LayoutOrder = ordenLinea
	cabecera.Parent = lista
	for _, linea in ipairs(seccion.lineas) do
		ordenLinea += 1
		local fila = Instance.new("TextLabel")
		fila.Size = UDim2.new(1, -20, 0, 0)
		fila.AutomaticSize = Enum.AutomaticSize.Y
		fila.BackgroundTransparency = 1
		fila.Font = Enum.Font.Gotham
		fila.TextSize = 16
		fila.TextWrapped = true
		fila.TextXAlignment = Enum.TextXAlignment.Left
		fila.TextColor3 = CREMA
		fila.Text = linea
		fila.LayoutOrder = ordenLinea
		fila.Parent = lista
	end
end

local pie = Instance.new("TextLabel")
pie.Size = UDim2.new(1, 0, 0, 18)
pie.Position = UDim2.new(0, 0, 0, 354)
pie.BackgroundTransparency = 1
pie.Font = Enum.Font.Gotham
pie.TextSize = 14
pie.Text = "Modelos bajo licencia CC-BY 4.0 · Sketchfab"
pie.TextColor3 = AMARILLO
pie.Parent = panel

local volver = Instance.new("TextButton")
volver.Size = UDim2.fromOffset(240, 52)
volver.AnchorPoint = Vector2.new(0.5, 0)
volver.Position = UDim2.new(0.5, 0, 0, 376)
volver.BackgroundColor3 = VERDE
volver.Font = Enum.Font.GothamBlack
volver.TextSize = 22
volver.TextColor3 = CREMA
volver.Text = L("volver"):upper()
volver.Parent = panel
redondear(volver, 12)

-- Contrato estándar de los menús (igual que MenuAjustes): nos ocultamos y, si no hay
-- partida en curso, re-mostramos MenuInicio. Sin tocar EnJuego.
volver.Activated:Connect(function()
	gui.Enabled = false
	if player:GetAttribute("EnJuego") ~= true then
		local inicio = player.PlayerGui:FindFirstChild("MenuInicio")
		if inicio then
			inicio.Enabled = true
		end
	end
end)

-- La atribución no se traduce, pero título y VOLVER siguen al idioma activo.
local function aplicarTextos()
	titulo.Text = L("creditos")
	volver.Text = L("volver"):upper()
end

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	aplicarTextos()
end)

aplicarTextos()

print("[CreditosUI] activo")
