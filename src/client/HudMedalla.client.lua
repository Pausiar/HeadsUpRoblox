-- HudMedalla: medalla de ruta equipada + selector para flexear (fase 11 · L5b).
-- Panel pequeño bajo el ranking (misma madera). El chip ES el flexeo: cuadrado
-- del color del tier (design-dna: nada de emoji). El servidor valida y replica;
-- este cliente solo pinta y pide equipar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config.MedallasRutaConfig)

-- mini-tokens (mismos que HudRanking)
local COLOR_PANEL = Color3.fromRGB(62, 42, 24) -- #3E2A18
local COLOR_MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21 (botón tablón)
local COLOR_CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local COLOR_AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C (destacado)
local COLOR_GRIS = Color3.fromRGB(110, 100, 90) -- chip sin medalla / tier bloqueado
local FUENTE = Enum.Font.GothamBold

-- Tono del Stroke para los tiers con brillo (platino → obsidiana).
local function aclarar(color)
	return Color3.new(
		math.min(1, color.R + 0.35),
		math.min(1, color.G + 0.35),
		math.min(1, color.B + 0.35)
	)
end

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HudMedalla"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area: mismo inset que HudRanking (notch en móviles).
local inset = GuiService:GetGuiInset()
local safeArea = Instance.new("UIPadding")
safeArea.PaddingTop = UDim.new(0, inset.Y)
safeArea.PaddingLeft = UDim.new(0, inset.X)
safeArea.Parent = gui

local remotoEstado = Remotes.Esperar(Remotes.Nombres.MedallaRutaEstado)
local remotoEquipar = Remotes.Esperar(Remotes.Nombres.MedallaRutaEquipar)

local estadoJugador = { rutas = 0, tier = nil, equipada = nil }

local panel = Instance.new("Frame")
panel.Name = "PanelMedalla"
panel.Size = UDim2.fromOffset(220, 40)
panel.Position = UDim2.new(0, 20, 0, 192) -- bajo HudRanking (20 + 164 + 8)
panel.BackgroundColor3 = COLOR_PANEL
panel.BorderSizePixel = 0
panel.Parent = gui

local esquinaPanel = Instance.new("UICorner")
esquinaPanel.CornerRadius = UDim.new(0, 12)
esquinaPanel.Parent = panel

local chip = Instance.new("Frame")
chip.Name = "Medalla"
chip.Size = UDim2.fromOffset(24, 24)
chip.Position = UDim2.new(0, 8, 0, 8)
chip.BackgroundColor3 = COLOR_GRIS
chip.BorderSizePixel = 0
chip.Parent = panel
local esquinaChip = Instance.new("UICorner")
esquinaChip.CornerRadius = UDim.new(0, 4)
esquinaChip.Parent = chip
local brilloChip = Instance.new("UIStroke")
brilloChip.Thickness = 1
brilloChip.Enabled = false
brilloChip.Parent = chip

local texto = Instance.new("TextLabel")
texto.Name = "Texto"
texto.Position = UDim2.new(0, 40, 0, 6)
texto.Size = UDim2.fromOffset(118, 28)
texto.BackgroundTransparency = 1
texto.Font = FUENTE
texto.TextColor3 = COLOR_CREMA
texto.TextScaled = true -- la frase completa cabe en 1-2 líneas sea cual sea el tier
texto.TextWrapped = true
texto.TextXAlignment = Enum.TextXAlignment.Left
texto.Parent = panel
local topeTexto = Instance.new("UITextSizeConstraint")
topeTexto.MaxTextSize = 12
topeTexto.Parent = texto

local boton = Instance.new("TextButton")
boton.Name = "Flexear"
boton.Size = UDim2.fromOffset(46, 24)
boton.Position = UDim2.new(1, -54, 0, 8)
boton.BackgroundColor3 = COLOR_MADERA
boton.BorderSizePixel = 0
boton.Font = FUENTE
boton.TextSize = 11
boton.TextColor3 = COLOR_CREMA
boton.Text = "FLEXEAR"
boton.Parent = panel
local esquinaBoton = Instance.new("UICorner")
esquinaBoton.CornerRadius = UDim.new(0, 6)
esquinaBoton.Parent = boton

-- Selector inline: una fila por tier, en orden; clic solo en los alcanzados.
local selector = Instance.new("Frame")
selector.Name = "SelectorMedallas"
selector.Size = UDim2.fromOffset(220, 16 + #Config.Tiers * 30)
selector.Position = UDim2.new(0, 20, 0, 240) -- bajo el panel de medalla
selector.BackgroundColor3 = COLOR_PANEL
selector.BorderSizePixel = 0
selector.Visible = false
selector.Parent = gui
local esquinaSelector = Instance.new("UICorner")
esquinaSelector.CornerRadius = UDim.new(0, 12)
esquinaSelector.Parent = selector

local filas = {}
for i, tier in ipairs(Config.Tiers) do
	local fila = Instance.new("TextButton")
	fila.Name = "Tier_" .. tier.id
	fila.Size = UDim2.new(1, -16, 0, 26)
	fila.Position = UDim2.new(0, 8, 0, 8 + (i - 1) * 30)
	fila.BackgroundTransparency = 1
	fila.Text = ""
	fila.Parent = selector

	local c = Instance.new("Frame")
	c.Size = UDim2.fromOffset(16, 16)
	c.Position = UDim2.new(0, 0, 0, 5)
	c.BackgroundColor3 = COLOR_GRIS
	c.BorderSizePixel = 0
	c.Parent = fila
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 3)
	cc.Parent = c
	local cb = Instance.new("UIStroke")
	cb.Thickness = 1
	cb.Enabled = false
	cb.Parent = c

	local nombre = Instance.new("TextLabel")
	nombre.Size = UDim2.new(1, -100, 1, 0)
	nombre.Position = UDim2.new(0, 24, 0, 0)
	nombre.BackgroundTransparency = 1
	nombre.Font = FUENTE
	nombre.TextSize = 12
	nombre.TextXAlignment = Enum.TextXAlignment.Left
	nombre.TextColor3 = COLOR_CREMA
	nombre.TextTruncate = Enum.TextTruncate.AtEnd
	nombre.Parent = fila

	local estadoFila = Instance.new("TextLabel")
	estadoFila.Size = UDim2.fromOffset(72, 26)
	estadoFila.Position = UDim2.new(1, -72, 0, 0)
	estadoFila.BackgroundTransparency = 1
	estadoFila.Font = FUENTE
	estadoFila.TextSize = 11
	estadoFila.TextXAlignment = Enum.TextXAlignment.Right
	estadoFila.TextColor3 = COLOR_CREMA
	estadoFila.Parent = fila

	filas[i] = { tier = tier, chip = c, brillo = cb, nombre = nombre, estado = estadoFila }

	fila.Activated:Connect(function()
		if estadoJugador.rutas >= tier.rutas then -- solo flexeas lo que ganaste
			remotoEquipar:FireServer({ id = tier.id })
		end
	end)
end

local function pintar()
	local equipadaTier = Config.PorId(estadoJugador.equipada)
	if equipadaTier then
		chip.BackgroundColor3 = equipadaTier.color
		brilloChip.Color = aclarar(equipadaTier.color)
		brilloChip.Enabled = equipadaTier.brillo
		texto.Text = ("Medalla de %s · %d rutas"):format(equipadaTier.nombre, estadoJugador.rutas)
	else
		chip.BackgroundColor3 = COLOR_GRIS
		brilloChip.Enabled = false
		texto.Text = ("Sin medalla · %d rutas"):format(estadoJugador.rutas) -- clave pendiente: "medalla_sin"
	end

	for _, fila in ipairs(filas) do
		local tier = fila.tier
		local alcanzado = estadoJugador.rutas >= tier.rutas
		fila.chip.BackgroundColor3 = alcanzado and tier.color or COLOR_GRIS
		fila.brillo.Color = aclarar(tier.color)
		fila.brillo.Enabled = alcanzado and tier.brillo
		fila.nombre.Text = tier.nombre
		fila.nombre.TextTransparency = alcanzado and 0 or 0.55
		if estadoJugador.equipada == tier.id then
			fila.estado.Text = "equipada" -- clave pendiente: "medalla_equipada"
			fila.estado.TextColor3 = COLOR_AMARILLO
			fila.estado.TextTransparency = 0
		elseif alcanzado then
			fila.estado.Text = ""
		else
			fila.estado.Text = ("%d rutas"):format(tier.rutas) -- clave pendiente: "medalla_rutas"
			fila.estado.TextColor3 = COLOR_CREMA
			fila.estado.TextTransparency = 0.55
		end
	end
end

remotoEstado.OnClientEvent:Connect(function(e)
	if type(e) ~= "table" then
		return
	end
	estadoJugador = {
		rutas = tonumber(e.rutas) or 0,
		tier = type(e.tier) == "string" and e.tier or nil,
		equipada = type(e.equipada) == "string" and e.equipada or nil,
	}
	pintar()
end)

boton.Activated:Connect(function()
	selector.Visible = not selector.Visible
end)

pintar()

print("[HudMedalla] activo")
