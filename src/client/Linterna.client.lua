-- Linterna (plan §5.3): tecla F alterna un SpotLight en la Head del personaje.
-- Sirve para ver en zonas oscuras y prepara el contrajuego contra El Doble (gancho abajo).
-- Solo funciona en partida: mismo contrato del atributo "EnJuego" que Estamina.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local TECLA = Enum.KeyCode.F

-- GANCHO_DELATE (plan §5.3, contrajuego contra El Doble): al integrarlo, el SERVIDOR
-- comprobará si el cono de la linterna de un jugador ilumina al Doble —producto punto
-- entre la dirección del haz (LookVector de la Head, hacia donde apunta el SpotLight
-- con Face Front) y el vector unitario hacia el Doble, dentro del ángulo (35°) y el
-- alcance (40) del cono— y le pondrá un Highlight para delatarlo. No se implementa aquí:
-- la detección es autoritativa del servidor; esta constante es el gancho documentado.
local GANCHO_DELATE = false

-- Etiqueta discreta del atajo, clonada de la de «V: cámara» (CameraController),
-- apilada un escalón más arriba (crema #F5EBD8 al 25%)
local gui = Instance.new("ScreenGui")
gui.Name = "HudLinterna"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local aviso = Instance.new("TextLabel")
aviso.Name = "AvisoLinterna"
aviso.AnchorPoint = Vector2.new(1, 1)
aviso.Position = UDim2.new(1, -16, 1, -38)
aviso.Size = UDim2.fromOffset(120, 24)
aviso.BackgroundTransparency = 1
aviso.Font = Enum.Font.Gotham
aviso.TextSize = 14
aviso.TextTransparency = 0.25
aviso.TextXAlignment = Enum.TextXAlignment.Right
aviso.TextColor3 = Color3.fromRGB(245, 235, 216)
aviso.Text = "F: linterna"
aviso.Parent = gui

local encendida = false

local function crearLuz()
	local cabeza = player.Character and player.Character:FindFirstChild("Head")
	if not cabeza or cabeza:FindFirstChild("Linterna") then
		return
	end
	local luz = Instance.new("SpotLight")
	luz.Name = "Linterna"
	luz.Angle = 35
	luz.Range = 40
	luz.Brightness = 2
	luz.Color = Color3.fromRGB(255, 243, 214) -- blanco cálido #FFF3D6
	luz.Face = Enum.NormalId.Front -- la Head mira por su LookVector: el haz sigue la mirada
	luz.Shadows = true
	luz.Parent = cabeza
end

local function quitarLuz()
	local cabeza = player.Character and player.Character:FindFirstChild("Head")
	local luz = cabeza and cabeza:FindFirstChild("Linterna")
	if luz then
		luz:Destroy()
	end
end

local function alternar()
	if player:GetAttribute("EnJuego") ~= true then
		return
	end
	encendida = not encendida
	if encendida then
		crearLuz()
	else
		quitarLuz()
	end
end

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado then
		return
	end
	if entrada.KeyCode == TECLA then
		alternar()
	end
end)

-- Volver al lobby la apaga (mismo contrato que Estamina)
player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") ~= true then
		encendida = false
		quitarLuz()
	end
end)

-- La linterna sobrevive al respawn: si estaba encendida, re-crearla en la nueva Head
player.CharacterAdded:Connect(function(char)
	if encendida then
		char:WaitForChild("Head", 5)
		crearLuz()
	end
end)

print("[Linterna] activo")
