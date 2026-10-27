-- Menú de ajustes (plan §8: overlay, no pausa). Escribe en Settings; CameraController y efectos leen.
-- Contrato con MenuInicio: su AJUSTES habilita esta gui; nuestro VOLVER re-muestra MenuInicio si no estamos en juego.
-- Reutiliza paleta y patrón de Hud.client.lua; ADN visual en docs/design/design-dna.md
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)

local player = Players.LocalPlayer

-- Paleta del ADN
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C
local GRIS = Color3.fromRGB(138, 129, 119) -- #8A8177
local MARRON_OSCURO = Color3.fromRGB(62, 42, 24) -- #3E2A18

local gui = Instance.new("ScreenGui")
gui.Name = "MenuAjustes"
gui.Enabled = false
gui.DisplayOrder = 60
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(460, 420)
panel.Position = UDim2.new(0.5, -230, 0.5, -210)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = gui

local esquinaPanel = Instance.new("UICorner")
esquinaPanel.CornerRadius = UDim.new(0, 16)
esquinaPanel.Parent = panel

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio)
	esquina.Parent = objeto
end

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, 0, 0, 36)
titulo.Position = UDim2.new(0, 0, 0, 14)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 32
titulo.Text = "AJUSTES"
titulo.TextColor3 = CREMA
titulo.Parent = panel

local function etiquetaFila(y, texto)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -48, 0, 22)
	t.Position = UDim2.new(0, 24, 0, y)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 20
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = CREMA
	t.Text = texto
	t.Parent = panel
	return t
end

-- Slider real: pista 300x8 + knob circular arrastrable. El knob vive dentro de un botón
-- invisible de 40x40: área de agarre mayor que el knob, para dedo y puntero.
local function crearSlider(yFila, texto, clave, minimo, maximo, colorKnob)
	etiquetaFila(yFila, texto)

	local pista = Instance.new("Frame")
	pista.Size = UDim2.fromOffset(300, 8)
	pista.Position = UDim2.new(0, 24, 0, yFila + 32)
	pista.BackgroundColor3 = CREMA
	pista.BackgroundTransparency = 0.3
	pista.BorderSizePixel = 0
	pista.Parent = panel
	redondear(pista, 4)

	local valor = Instance.new("TextLabel")
	valor.Size = UDim2.fromOffset(100, 26)
	valor.Position = UDim2.new(0, 336, 0, yFila + 23)
	valor.BackgroundTransparency = 1
	valor.Font = Enum.Font.GothamBold
	valor.TextSize = 20
	valor.TextXAlignment = Enum.TextXAlignment.Right
	valor.TextColor3 = CREMA
	valor.Parent = panel

	local agarre = Instance.new("TextButton")
	agarre.Size = UDim2.fromOffset(40, 40)
	agarre.BackgroundTransparency = 1
	agarre.Text = ""
	agarre.AutoButtonColor = false
	agarre.Parent = pista

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.new(0.5, -10, 0.5, -10)
	knob.BackgroundColor3 = colorKnob
	knob.BorderSizePixel = 0
	knob.Parent = agarre
	redondear(knob, 10) -- círculo

	local function refrescar(v)
		v = math.floor(v)
		local alpha = (v - minimo) / (maximo - minimo)
		agarre.Position = UDim2.new(alpha, -20, 0.5, -20)
		valor.Text = ("%d%%"):format(v)
	end

	local function valorDe(xPantalla)
		local alpha = (xPantalla - pista.AbsolutePosition.X) / math.max(pista.AbsoluteSize.X, 1)
		alpha = math.clamp(alpha, 0, 1)
		return math.floor(minimo + alpha * (maximo - minimo) + 0.5)
	end

	local arrastrando = false
	local function iniciar(input)
		local tipo = input.UserInputType
		if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch then
			arrastrando = true
			Settings.Cambiar(clave, valorDe(input.Position.X))
		end
	end

	agarre.InputBegan:Connect(iniciar)
	pista.InputBegan:Connect(iniciar) -- tocar la pista salta el knob (táctil)
	UserInputService.InputChanged:Connect(function(input)
		local tipo = input.UserInputType
		if arrastrando and (tipo == Enum.UserInputType.MouseMovement or tipo == Enum.UserInputType.Touch) then
			Settings.Cambiar(clave, valorDe(input.Position.X))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local tipo = input.UserInputType
		if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch then
			arrastrando = false
		end
	end)

	Settings.AlCambiar.Event:Connect(function(claveCambiada, v)
		if claveCambiada == clave then
			refrescar(v)
		end
	end)
	refrescar(Settings.Obtener(clave))
end

crearSlider(58, "Sensibilidad", "sensibilidad", 10, 100, VERDE)

-- Nota: los volúmenes solo se guardan en Settings; el audio real se conecta en la fase 6.
etiquetaFila(128, "Reducir efectos")

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(186, 38)
toggle.Position = UDim2.new(0, 250, 0, 120)
toggle.Font = Enum.Font.GothamBlack
toggle.TextSize = 18
toggle.Parent = panel
redondear(toggle, 10)

local function refrescarToggle(activado)
	toggle.Text = activado and "ACTIVADO" or "DESACTIVADO"
	toggle.BackgroundColor3 = activado and VERDE or GRIS
	toggle.TextColor3 = activado and CREMA or MARRON_OSCURO
end

toggle.Activated:Connect(function()
	Settings.Cambiar("reducirEfectos", not Settings.Obtener("reducirEfectos"))
end)
Settings.AlCambiar.Event:Connect(function(clave, v)
	if clave == "reducirEfectos" then
		refrescarToggle(v == true)
	end
end)
refrescarToggle(Settings.Obtener("reducirEfectos") == true)

crearSlider(178, "Volumen música", "volumenMusica", 0, 100, AMARILLO)
crearSlider(238, "Volumen efectos", "volumenEfectos", 0, 100, AMARILLO)

local volver = Instance.new("TextButton")
volver.Size = UDim2.fromOffset(240, 52)
volver.Position = UDim2.new(0, 110, 0, 336)
volver.BackgroundColor3 = VERDE
volver.Font = Enum.Font.GothamBlack
volver.TextSize = 22
volver.TextColor3 = CREMA
volver.Text = "VOLVER"
volver.Parent = panel
redondear(volver, 12)

volver.Activated:Connect(function()
	gui.Enabled = false
	if player:GetAttribute("EnJuego") ~= true then
		local inicio = player.PlayerGui:FindFirstChild("MenuInicio")
		if inicio then
			inicio.Enabled = true
		end
	end
end)

print("[MenuAjustes] activo")
