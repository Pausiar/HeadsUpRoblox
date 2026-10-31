-- Linterna (plan §5.3): tecla F alterna un SpotLight en la Head del personaje.
-- Sirve para ver en zonas oscuras y prepara el contrajuego contra El Doble (gancho abajo).
-- Solo funciona en partida: mismo contrato del atributo "EnJuego" que Estamina.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer
local TECLA = Enum.KeyCode.F
local BOTON_MANDO = Enum.KeyCode.ButtonB
-- Noche cerrada (fase 9): el haz es la guía principal, así que abre más que el
-- 35º original y llega más lejos; con el pase gana el mismo +15 % de cono.
local ANGULO_BASE = 46
local ANGULO_PRO = 52.9 -- +15 % de cono con el pase (plan §7.2)
local RANGO = 60
local BRILLO = 4
local COLOR_BASE = Color3.fromRGB(255, 243, 214) -- blanco cálido #FFF3D6
local COLOR_PRO = Color3.fromRGB(63, 127, 191) -- azul del ADN #3F7FBF (información/selección)

-- GANCHO_DELATE implementado (B15, plan §5.3 + fase-11 §L6): con la linterna
-- encendida en partida, cada INTERVALO_HAZ (5 Hz) se envía al servidor la
-- dirección del haz como LookVector de la CÁMARA —en 3ª persona la Head no gira
-- con ella: la cámara es hacia donde mira de verdad el jugador—. El receptor
-- (MonsterService, remote LinternaAim) valida y comprueba el cono de delate
-- (clon a ≤25 studs dentro de 35° del haz) y lo ahuyenta: la detección es
-- autoritativa del servidor; el cliente solo informa.
local INTERVALO_HAZ = 0.2 -- 5 Hz, la misma cadencia que limita el receptor

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
aviso.Text = L("f_linterna")
aviso.Parent = gui

local encendida = false
local tienePro = false
local modoPuro = false

-- Linterna Pro: cono más ancho y color propio; en Modo Puro no hay ventaja.
local function aplicarPerfil(luz)
	if tienePro and not modoPuro then
		luz.Angle = ANGULO_PRO
		luz.Color = COLOR_PRO
	else
		luz.Angle = ANGULO_BASE
		luz.Color = COLOR_BASE
	end
end

local function crearLuz()
	local cabeza = player.Character and player.Character:FindFirstChild("Head")
	if not cabeza or cabeza:FindFirstChild("Linterna") then
		return
	end
	local luz = Instance.new("SpotLight")
	luz.Name = "Linterna"
	luz.Range = RANGO
	luz.Brightness = BRILLO
	luz.Face = Enum.NormalId.Front -- la Head mira por su LookVector: el haz sigue la mirada
	luz.Shadows = true
	aplicarPerfil(luz)
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
	if entrada.KeyCode == TECLA or entrada.KeyCode == BOTON_MANDO then
		alternar()
	end
end)

-- Táctil: botón compartido que alterna la linterna igual que F. En móvil el atajo
-- de teclado no se muestra (sería falso).
if UserInputService.TouchEnabled then
	aviso.Visible = false
	local Acciones = require(script.Parent:WaitForChild("Acciones"))
	local boton = Acciones.CrearBoton("linterna", 3)
	local function actualizarVisibilidad()
		boton.Visible = player:GetAttribute("EnJuego") == true
	end
	player:GetAttributeChangedSignal("EnJuego"):Connect(actualizarVisibilidad)
	actualizarVisibilidad()
	boton.Activated:Connect(alternar)
end

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

-- El estado llega del servidor (entrada, compra del pase, Modo Puro). Si la luz
-- ya está encendida se actualiza en vivo; si aún no existe, se crea con el perfil.
local function actualizarEstado()
	local cabeza = player.Character and player.Character:FindFirstChild("Head")
	local luz = cabeza and cabeza:FindFirstChild("Linterna")
	if luz then
		aplicarPerfil(luz)
	elseif encendida then
		crearLuz()
	end
end

local carpetaRemotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local remotoPase = carpetaRemotes and carpetaRemotes:WaitForChild("PaseEstado", 15)
if remotoPase then
	remotoPase.OnClientEvent:Connect(function(datos)
		tienePro = type(datos) == "table" and type(datos.pases) == "table" and datos.pases.linternaPro == true
		modoPuro = type(datos) == "table" and datos.modoPuro == true
		actualizarEstado()
	end)
else
	warn("[Linterna] sin remote PaseEstado: se usa la linterna base")
end

-- B15 (GANCHO_DELATE): envío del haz a 5 Hz mientras alumbra en partida. El
-- servidor limita el remoto a la misma cadencia; aquí no hay que frenar más.
local remotoAim = carpetaRemotes and carpetaRemotes:WaitForChild("LinternaAim", 15)
if remotoAim then
	task.spawn(function()
		while true do
			task.wait(INTERVALO_HAZ)
			if encendida and player:GetAttribute("EnJuego") == true then
				local camara = workspace.CurrentCamera
				if camara then
					remotoAim:FireServer({ direccion = camara.CFrame.LookVector })
				end
			end
		end
	end)
else
	warn("[Linterna] sin remote LinternaAim: el Doble no reacciona al haz")
end

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	aviso.Text = L("f_linterna")
end)

print("[Linterna] activo")
