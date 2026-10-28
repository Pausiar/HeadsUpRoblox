-- Botones táctiles compartidos por Estamina, Linterna y CameraController.
-- Una sola fila abajo-centro (56x56, fuera del thumbstick y del salto por defecto).
-- Solo se requiere desde clientes con TouchEnabled; el estilo sigue el ADN visual.
-- shortcut: en pantallas muy estrechas la fila puede rozar la zona del thumbstick;
-- validar en móvil real (pantalla de 320 px) antes del soft launch.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "ControlesTactiles"
gui.ResetOnSpawn = false
gui.DisplayOrder = 40 -- debajo de menús (50+) y HUD (sin orden explícito)
gui.Parent = player:WaitForChild("PlayerGui")

local _, insetInf = GuiService:GetGuiInset()

local fila = Instance.new("Frame")
fila.Name = "Fila"
fila.AnchorPoint = Vector2.new(0.5, 1)
fila.Position = UDim2.new(0.5, 0, 1, -(16 + insetInf.Y))
fila.Size = UDim2.fromOffset(0, 56)
fila.AutomaticSize = Enum.AutomaticSize.X
fila.BackgroundTransparency = 1
fila.Parent = gui

local lista = Instance.new("UIListLayout")
lista.FillDirection = Enum.FillDirection.Horizontal
lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
lista.VerticalAlignment = Enum.VerticalAlignment.Center
lista.Padding = UDim.new(0, 8)
lista.SortOrder = Enum.SortOrder.LayoutOrder
lista.Parent = fila

local Acciones = {}

-- Los rótulos se resuelven por clave y se repintan si cambia el idioma; el módulo
-- se comparte entre Estamina, Linterna y CameraController.
local botones = {}
local escuchaIdioma = false

local function aplicarIdioma()
	for _, registro in ipairs(botones) do
		registro.boton.Text = L(registro.clave)
	end
end

local function asegurarEscuchaIdioma()
	if escuchaIdioma then
		return
	end
	escuchaIdioma = true
	Settings.AlCambiar.Event:Connect(function(clave, valor)
		if clave ~= "idioma" then
			return
		end
		Localization.Establecer(valor)
		aplicarIdioma()
	end)
end

function Acciones.CrearBoton(clave, orden)
	local boton = Instance.new("TextButton")
	boton.Name = "Boton" .. orden
	boton.LayoutOrder = orden
	boton.Size = UDim2.fromOffset(56, 56)
	boton.BackgroundColor3 = MADERA
	boton.BackgroundTransparency = 0.12
	boton.BorderSizePixel = 0
	boton.Font = Enum.Font.GothamBlack
	boton.Text = L(clave)
	boton.TextColor3 = CREMA
	boton.TextScaled = true
	boton.Parent = fila

	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 14)
	esquina.Parent = boton

	-- TextScaled: estos botones no entran en la escala global de texto (Accesibilidad los ignora).
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = 15
	limite.Parent = boton

	table.insert(botones, { boton = boton, clave = clave })
	asegurarEscuchaIdioma()

	return boton
end

return Acciones
