-- Aviso de apagado del servidor (plan fase 11 · A7): velo y cuenta atrás de 5 s.
-- El servidor manda ServidorCerrando en su BindToClose; aquí solo se pinta.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "CierreServidor"
gui.ResetOnSpawn = false
gui.DisplayOrder = 250 -- por encima de todo: solo aparece cuando el servidor se apaga
gui.IgnoreGuiInset = true -- el velo tapa también la franja superior
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local velo = Instance.new("Frame")
velo.Size = UDim2.fromScale(1, 1)
velo.BackgroundColor3 = Color3.new(0, 0, 0)
velo.BackgroundTransparency = 0.45
velo.BorderSizePixel = 0
velo.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(360, 176)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 14)
esquina.Parent = panel

local escala = Instance.new("UIScale")
escala.Parent = panel

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -32, 0, 66)
titulo.Position = UDim2.fromOffset(16, 12)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 20
titulo.TextWrapped = true
titulo.TextColor3 = AMARILLO
titulo.Text = L("servidor_cerrando")
titulo.Parent = panel

local cuenta = Instance.new("TextLabel")
cuenta.Size = UDim2.new(1, -32, 0, 80)
cuenta.Position = UDim2.fromOffset(16, 82)
cuenta.BackgroundTransparency = 1
cuenta.Font = Enum.Font.GothamBlack
cuenta.TextSize = 44
cuenta.TextColor3 = CREMA
cuenta.Text = ""
cuenta.Parent = panel

-- El aviso ya tapa la pantalla: no hace falta el juego detrás, solo que quepa.
local function ajustarEscala()
	local viewport = gui.AbsoluteSize
	escala.Scale = math.clamp(math.min(viewport.X / 440, viewport.Y / 300), 0.8, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local token = 0

local function mostrar(segundos)
	token += 1
	local mio = token
	local restante = math.max(0, math.floor(segundos + 0.5))
	gui.Enabled = true
	cuenta.Text = ("%d"):format(restante)
	task.spawn(function()
		while restante > 0 and mio == token do
			task.wait(1)
			restante -= 1
			if mio == token then
				cuenta.Text = ("%d"):format(restante)
			end
		end
	end)
end

Remotes.Esperar(Remotes.Nombres.ServidorCerrando).OnClientEvent:Connect(function(datos)
	local segundos = type(datos) == "table" and tonumber(datos.segundos) or 5
	mostrar(segundos or 5)
end)

Settings.AlCambiar.Event:Connect(function(clave)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(Settings.Obtener("idioma"))
	titulo.Text = L("servidor_cerrando")
end)

print("[Cierre] aviso de apagado listo")
