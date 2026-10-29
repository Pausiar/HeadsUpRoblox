-- CameraController (plan §3.5): tercera persona por defecto, tecla V (o R3) alterna a
-- primera persona con viewmodel mínimo de brazos (madera #5C3A21) y balanceo sutil al
-- caminar. La sensibilidad de Ajustes se aplica al ratón con MouseDeltaSensitivity.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer
local TERCERA = Enum.CameraMode.Classic
local PRIMERA = Enum.CameraMode.LockFirstPerson
local TECLA = Enum.KeyCode.V
local BOTON_MANDO = Enum.KeyCode.ButtonR3

-- Ajustes 10-100 %: 50 % es la sensibilidad por defecto del motor (1.0).
local sensibilidad = tonumber(Settings.Obtener("sensibilidad")) or 50
local function aplicarSensibilidad()
	UserInputService.MouseDeltaSensitivity = math.clamp(sensibilidad / 50, 0.2, 2)
end
aplicarSensibilidad()

-- Etiqueta discreta del atajo (esquina inferior derecha, crema #F5EBD8)
local gui = Instance.new("ScreenGui")
gui.Name = "HudCamara"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local aviso = Instance.new("TextLabel")
aviso.Name = "AvisoCamara"
aviso.AnchorPoint = Vector2.new(1, 1)
aviso.Position = UDim2.new(1, -16, 1, -14)
aviso.Size = UDim2.fromOffset(120, 24)
aviso.BackgroundTransparency = 1
aviso.Font = Enum.Font.Gotham
aviso.TextSize = 14
aviso.TextTransparency = 0.25
aviso.TextXAlignment = Enum.TextXAlignment.Right
aviso.TextColor3 = Color3.fromRGB(245, 235, 216)
aviso.Text = L("v_camara")
aviso.Parent = gui

-- Accesibilidad §8: sin balanceo si se activa "reducirEfectos" (actualización en vivo)
local reducirEfectos = Settings.Obtener("reducirEfectos") == true
Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave == "reducirEfectos" then
		reducirEfectos = valor == true
	elseif clave == "sensibilidad" then
		sensibilidad = tonumber(valor) or sensibilidad
		aplicarSensibilidad()
	elseif clave == "idioma" then
		Localization.Establecer(valor)
		aviso.Text = L("v_camara")
	end
end)

local function carpetaActual()
	local camara = workspace.CurrentCamera
	return camara and camara:FindFirstChild("ViewmodelArms"), camara
end

local function crearViewmodel()
	local camara = workspace.CurrentCamera
	if not camara or camara:FindFirstChild("ViewmodelArms") then
		return
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = "ViewmodelArms"

	local ancla = Instance.new("Part")
	ancla.Name = "Ancla"
	ancla.Size = Vector3.new(0.2, 0.2, 0.2)
	ancla.Transparency = 1
	ancla.Anchored = true
	ancla.CanCollide = false
	ancla.CanQuery = false
	ancla.CanTouch = false
	ancla.CastShadow = false
	ancla.Massless = true
	ancla.CFrame = camara.CFrame
	ancla.Parent = carpeta

	local function brazo(nombre, lado)
		local part = Instance.new("Part")
		part.Name = nombre
		part.Size = Vector3.new(0.35, 0.35, 1.1)
		part.Color = Color3.fromRGB(92, 58, 33) -- madera oscura #5C3A21
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		-- Abajo a cada lado, ligeramente inclinados hacia el centro
		part.CFrame = ancla.CFrame
			* CFrame.new(0.8 * lado, -0.6, -1.05)
			* CFrame.Angles(math.rad(-12), math.rad(-5 * lado), math.rad(6 * lado))
		part.Parent = carpeta
		local soldadura = Instance.new("WeldConstraint")
		soldadura.Part0 = ancla
		soldadura.Part1 = part
		soldadura.Parent = part
	end
	brazo("BrazoIzquierdo", -1)
	brazo("BrazoDerecho", 1)

	carpeta.Parent = camara
end

local function destruirViewmodel()
	local carpeta = carpetaActual()
	if carpeta then
		carpeta:Destroy()
	end
end

local primeraPersona = false
local menuAbierto = (tonumber(player:GetAttribute("MenusAbiertos")) or 0) > 0
local zoomMinGuardado = nil

-- Primera persona + panel abierto = ratón centrado y botones muertos. Mientras haya un
-- panel (tienda, reanimar, resultados…) se sale a 3.ª persona y se fuerza el zoom fuera
-- del umbral de 1.ª persona; al cerrarlo se restaura el modo elegido.
local function aplicarModo()
	local suspendido = primeraPersona and menuAbierto
	if suspendido then
		if not zoomMinGuardado then
			zoomMinGuardado = player.CameraMinZoomDistance
		end
		player.CameraMinZoomDistance = 8
	elseif zoomMinGuardado then
		player.CameraMinZoomDistance = zoomMinGuardado
		zoomMinGuardado = nil
	end
	player.CameraMode = (primeraPersona and not menuAbierto) and PRIMERA or TERCERA
	if primeraPersona and not menuAbierto then
		crearViewmodel()
	else
		destruirViewmodel()
	end
end

local function cambiarModo(primera)
	primeraPersona = primera
	aplicarModo()
end

player:GetAttributeChangedSignal("MenusAbiertos"):Connect(function()
	menuAbierto = (tonumber(player:GetAttribute("MenusAbiertos")) or 0) > 0
	aplicarModo()
end)

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado then
		return
	end
	if entrada.KeyCode == TECLA or entrada.KeyCode == BOTON_MANDO then
		cambiarModo(not primeraPersona)
	end
end)

-- Táctil: botón compartido que alterna 3ª/1ª persona igual que V. El atajo de teclado
-- no se muestra en móvil; la cámara funciona también en el lobby.
if UserInputService.TouchEnabled then
	aviso.Visible = false
	local Acciones = require(script.Parent:WaitForChild("Acciones"))
	local boton = Acciones.CrearBoton("camara", 4)
	boton.Activated:Connect(function()
		cambiarModo(not primeraPersona)
	end)
end

-- La cámara se recrea al respawn: reaplicar el modo (viewmodel y suspensión incluidos)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(aplicarModo)

-- Balanceo sutil: se mueve solo el ancla (los brazos van soldados a ella)
local fase = 0
RunService.RenderStepped:Connect(function(dt)
	local carpeta, camara = carpetaActual()
	if not carpeta then
		return
	end
	local ancla = carpeta:FindFirstChild("Ancla")
	if not ancla then
		return
	end
	local base = camara.CFrame
	if not reducirEfectos then
		local char = player.Character
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		local vel = raiz and raiz.AssemblyLinearVelocity or Vector3.zero
		local velocidad = Vector3.new(vel.X, 0, vel.Z).Magnitude
		fase += dt * (4 + velocidad * 0.9)
		local amplitud = math.min(velocidad / 16, 1) * 0.06
		base = base * CFrame.new(math.cos(fase * 0.5) * amplitud, math.abs(math.sin(fase)) * amplitud, 0)
	end
	ancla.CFrame = base
end)

print("[CameraController] activo")
