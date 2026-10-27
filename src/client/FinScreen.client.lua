-- Pantalla «¡HAS CAÍDO!» (plan §8): aparece al recibir FinPartida y ofrece REINTENTAR.
-- Paleta y estilo: docs/design/design-dna.md. Patrón de GUI reutilizado de Hud.client.lua.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Mini-tokens del ADN (docs/design/design-dna.md)
local MADERA = Color3.fromRGB(62, 42, 24) -- panel oscuro #3E2A18
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8 texto
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A acción primaria
local VERDE_APAGADO = Color3.fromRGB(62, 107, 60) -- #3E6B3C acción primaria en enfriamiento
local ROJO = Color3.fromRGB(224, 69, 58) -- #E0453A peligro/título
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C insignia récord (contraste 8.8:1 sobre madera)
local VELO = Color3.fromRGB(12, 8, 5) -- fondo oscuro semitransparente
local BLANCO = Color3.fromRGB(255, 255, 255)

local ENFRIAMIENTO = 3 -- s de debounce del botón (el servidor además limita)
local ANIMACION = 0.25 -- s, entrada sutil (accesibilidad §8: nada brusco)
local POS_FINAL = UDim2.fromScale(0.5, 0.5)
local INFO_ENTRADA = TweenInfo.new(ANIMACION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local finPartida = Remotes.Esperar(Remotes.Nombres.FinPartida)
local reintentar = Remotes.Esperar(Remotes.Nombres.Reintentar)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "FinPantalla"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- F4 (revisión apple-design): safe area móvil — el velo no cubre la notch.
local insetSuperior = GuiService:GetGuiInset() -- primer Vector2 = inset superior
local rellenoGui = Instance.new("UIPadding")
rellenoGui.PaddingTop = UDim.new(0, insetSuperior.Y)
rellenoGui.Parent = gui

local velo = Instance.new("Frame")
velo.Name = "Velo"
velo.Size = UDim2.fromScale(1, 1)
velo.BackgroundColor3 = VELO
velo.BackgroundTransparency = 0.45
velo.BorderSizePixel = 0
velo.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PanelFin"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = POS_FINAL
panel.Size = UDim2.fromOffset(420, 420) -- 5 líneas + insignia + botón (antes 340)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = velo

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 16)
esquina.Parent = panel

-- F1 (revisión apple-design, P1 móvil): panel escalable. El UISizeConstraint acota
-- el tamaño y el UIScale encoge el conjunto (panel + hijos) en pantallas estrechas.
local restriccionPanel = Instance.new("UISizeConstraint")
restriccionPanel.MaxSize = Vector2.new(420, 420)
restriccionPanel.MinSize = Vector2.new(340, 340)
restriccionPanel.Parent = panel

local escalaPanel = Instance.new("UIScale")
escalaPanel.Parent = panel

-- Player no tiene ViewportSize (doc Roblox gana): la GUI es la fuente del viewport
-- (IgnoreGuiInset=true ⇒ AbsoluteSize = viewport completo).
local function ajustarEscala()
	escalaPanel.Scale = math.clamp(gui.AbsoluteSize.X / 500, 0.75, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -20, 0, 48)
titulo.Position = UDim2.new(0, 10, 0, 18)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.Text = "¡HAS CAÍDO!"
titulo.TextSize = 40
titulo.TextColor3 = ROJO
titulo.Parent = panel

-- Variante centrada del helper etiqueta() de Hud.client.lua
local function etiqueta(y, tamano)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -40, 0, tamano)
	t.Position = UDim2.new(0, 20, 0, y)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = tamano - 4
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextColor3 = CREMA
	t.Parent = panel
	return t
end

-- Insignia de récord (una idea por pantalla): texto amarillo sobre el panel, sin pill extra.
local insignia = Instance.new("TextLabel")
insignia.Size = UDim2.new(1, -40, 0, 32)
insignia.Position = UDim2.new(0, 20, 0, 74)
insignia.BackgroundTransparency = 1
insignia.Font = Enum.Font.GothamBlack
insignia.Text = "¡NUEVO RÉCORD!"
insignia.TextSize = 26
insignia.TextColor3 = AMARILLO
insignia.Visible = false
insignia.Parent = panel

local textoDistancia = etiqueta(116, 28)
local textoTiempo = etiqueta(150, 28)
local textoCheckpoint = etiqueta(184, 28)
local textoRecord = etiqueta(218, 28)
local textoPuntos = etiqueta(252, 28)

local boton = Instance.new("TextButton")
boton.Name = "BotonReintentar"
boton.AnchorPoint = Vector2.new(0.5, 0)
boton.Position = UDim2.new(0.5, 0, 0, 316)
boton.Size = UDim2.fromOffset(300, 56) -- objetivo de toque grande (≥44 px)
boton.BackgroundColor3 = VERDE
boton.BorderSizePixel = 0
boton.Font = Enum.Font.GothamBold
boton.Text = "REINTENTAR"
boton.TextSize = 26
boton.TextColor3 = BLANCO
boton.Parent = panel

local esquinaBoton = Instance.new("UICorner")
esquinaBoton.CornerRadius = UDim.new(0, 12)
esquinaBoton.Parent = boton

local enEnfriamiento = false

local function mostrar(datos)
	local distancia = math.max(0, math.floor(tonumber(datos and datos.distancia) or 0))
	local tiempo = math.max(0, math.floor(tonumber(datos and datos.tiempo) or 0))
	local checkpoint = math.floor(tonumber(datos and datos.checkpoint) or 0)
	local puntos = math.max(0, math.floor(tonumber(datos and datos.puntos) or 0))
	local record = math.max(0, math.floor(tonumber(datos and datos.record) or 0))
	local nuevoRecord = datos ~= nil and datos.nuevoRecord == true

	textoDistancia.Text = ("Distancia: %d m"):format(distancia)
	textoTiempo.Text = ("Tiempo: %02d:%02d"):format(tiempo / 60, tiempo % 60)
	textoCheckpoint.Text = if checkpoint > 0
		then ("Checkpoint: %d"):format(checkpoint)
		else "Checkpoint: —"
	textoRecord.Text = ("Récord: %d m"):format(record)
	textoPuntos.Text = ("Puntos: %d"):format(puntos)
	insignia.Visible = nuevoRecord

	-- Entrada sutil: fundido del velo + panel sube unos píxeles (nunca cambia de tamaño)
	velo.BackgroundTransparency = 1
	panel.Position = UDim2.new(0.5, 0, 0.5, 24)
	gui.Enabled = true
	TweenService:Create(velo, INFO_ENTRADA, { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(panel, INFO_ENTRADA, { Position = POS_FINAL }):Play()
end

boton.Activated:Connect(function()
	if enEnfriamiento then
		return
	end
	enEnfriamiento = true
	boton.Active = false
	boton.AutoButtonColor = false
	boton.Text = "REANUDANDO…" -- F2: feedback visible durante el enfriamiento
	boton.BackgroundColor3 = VERDE_APAGADO
	reintentar:FireServer()
	task.delay(ENFRIAMIENTO, function()
		enEnfriamiento = false
		boton.Active = true
		boton.AutoButtonColor = true
		boton.Text = "REINTENTAR"
		boton.BackgroundColor3 = VERDE
	end)
end)

finPartida.OnClientEvent:Connect(mostrar)

-- Al reaparecer, la pantalla desaparece (gui.Enabled cubre velo y panel de golpe)
player.CharacterAdded:Connect(function()
	gui.Enabled = false
end)

print("[FinScreen] activo")
