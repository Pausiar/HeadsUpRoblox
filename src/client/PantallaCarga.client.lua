-- Pantalla de carga (plan fase 11 · A2): se cierra con el personaje listo + 2 s,
-- con tope de 8 s para no tapar nunca el lobby. Consejos de CargaConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CargaConfig = require(ReplicatedStorage.Shared.Config.CargaConfig)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "PantallaCarga"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 240 -- debajo del aviso de cierre (250)
gui.Parent = player:WaitForChild("PlayerGui")

local fondo = Instance.new("Frame")
fondo.Size = UDim2.fromScale(1, 1)
fondo.BackgroundColor3 = MADERA
fondo.BorderSizePixel = 0
fondo.Parent = gui

local titulo = Instance.new("TextLabel")
titulo.AnchorPoint = Vector2.new(0.5, 0.5)
titulo.Position = UDim2.fromScale(0.5, 0.34)
titulo.Size = UDim2.new(1, -48, 0, 64)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 46
titulo.TextColor3 = CREMA
titulo.Text = "HEADS UP!"
titulo.Parent = fondo

local subtitulo = Instance.new("TextLabel")
subtitulo.AnchorPoint = Vector2.new(0.5, 0.5)
subtitulo.Position = UDim2.fromScale(0.5, 0.43)
subtitulo.Size = UDim2.new(1, -48, 0, 28)
subtitulo.BackgroundTransparency = 1
subtitulo.Font = Enum.Font.GothamBlack
subtitulo.TextSize = 18
subtitulo.TextColor3 = AMARILLO
subtitulo.Text = "MOUNTAIN MAYHEM"
subtitulo.Parent = fondo

local consejo = Instance.new("TextLabel")
consejo.AnchorPoint = Vector2.new(0.5, 0.5)
consejo.Position = UDim2.fromScale(0.5, 0.62)
consejo.Size = UDim2.new(1, -80, 0, 96)
consejo.BackgroundTransparency = 1
consejo.Font = Enum.Font.GothamBold
consejo.TextSize = 22
consejo.TextWrapped = true
consejo.TextColor3 = CREMA
consejo.Text = ""
consejo.Parent = fondo

local cargando = Instance.new("TextLabel")
cargando.AnchorPoint = Vector2.new(0.5, 1)
cargando.Position = UDim2.new(0.5, 0, 1, -32)
cargando.Size = UDim2.new(1, -48, 0, 24)
cargando.BackgroundTransparency = 1
cargando.Font = Enum.Font.GothamBold
cargando.TextSize = 16
cargando.TextColor3 = AMARILLO
cargando.Text = L("carga_cargando")
cargando.Parent = fondo

TweenService:Create(
	cargando,
	TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
	{ TextTransparency = 0.55 }
):Play()

local oculto = false

local function ocultar()
	if oculto then
		return
	end
	oculto = true
	gui.Enabled = false
end

local indice = 1
local function pintarConsejo()
	consejo.Text = L(CargaConfig.Consejos[indice])
end
pintarConsejo()

task.spawn(function()
	while not oculto do
		task.wait(CargaConfig.SegundosPorConsejo)
		if oculto then
			break
		end
		indice = indice % #CargaConfig.Consejos + 1
		pintarConsejo()
	end
end)

task.delay(CargaConfig.MaximoVisible, ocultar)

local function alPersonajeListo()
	task.delay(CargaConfig.EsperaTrasPersonaje, ocultar)
end
if player.Character then
	alPersonajeListo()
else
	player.CharacterAdded:Connect(alPersonajeListo)
end

print("[Carga] pantalla activa")
