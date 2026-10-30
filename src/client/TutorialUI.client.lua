-- Tutorial de 4 pasos en el lobby (fase 11 · A1). Se muestra una sola vez por
-- cuenta (TutorialEstado), es saltable y nunca tapa los botones del lobby: es una
-- tarjeta sobre las filas, sin velo, así EMPEZAR sigue disponible.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local MADERA_BOTON = Color3.fromRGB(107, 74, 43) -- #6B4A2B
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 56 -- sobre el lobby (55), bajo la tienda (58)
gui.Parent = player:WaitForChild("PlayerGui")

local insetSup, insetInf = GuiService:GetGuiInset()
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, insetSup.Y)
pad.PaddingLeft = UDim.new(0, insetSup.X)
pad.PaddingRight = UDim.new(0, insetInf.X)
pad.PaddingBottom = UDim.new(0, insetInf.Y)
pad.Parent = gui

local contenedor = Instance.new("Frame")
contenedor.Name = "Tarjeta"
contenedor.AnchorPoint = Vector2.new(0.5, 0)
contenedor.Position = UDim2.new(0.5, 0, 0, 16)
contenedor.Size = UDim2.fromOffset(480, 268)
contenedor.BackgroundColor3 = MADERA
contenedor.BorderSizePixel = 0
contenedor.Visible = false
contenedor.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 14)
esquina.Parent = contenedor

local escala = Instance.new("UIScale")
escala.Parent = contenedor

local function ajustarEscala()
	escala.Scale = math.clamp(math.min(gui.AbsoluteSize.X / 500, gui.AbsoluteSize.Y / 620), 0.7, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local function etiqueta(nombre, posicion, tamano, texto, tamanoTexto, color, fuente)
	local t = Instance.new("TextLabel")
	t.Name = nombre
	t.Position = posicion
	t.Size = tamano
	t.BackgroundTransparency = 1
	t.Font = fuente or Enum.Font.GothamBold
	t.Text = texto
	t.TextSize = tamanoTexto
	t.TextColor3 = color
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = contenedor
	return t
end

local titulo = etiqueta(
	"Titulo",
	UDim2.fromOffset(16, 14),
	UDim2.new(1, -32, 0, 26),
	"", 18, AMARILLO, Enum.Font.GothamBlack
)
local progreso = etiqueta(
	"Progreso",
	UDim2.fromOffset(16, 40),
	UDim2.new(1, -32, 0, 18),
	"", 14, CREMA
)
progreso.TextTransparency = 0.25

local pasoTitulo = etiqueta(
	"PasoTitulo",
	UDim2.fromOffset(16, 66),
	UDim2.new(1, -32, 0, 34),
	"", 22, CREMA, Enum.Font.GothamBlack
)
local texto = etiqueta(
	"Texto",
	UDim2.fromOffset(16, 104),
	UDim2.new(1, -32, 0, 100),
	"", 16, CREMA
)
texto.TextWrapped = true
texto.TextYAlignment = Enum.TextYAlignment.Top

local function boton(nombre, posicion, color)
	local b = Instance.new("TextButton")
	b.Name = nombre
	b.Position = posicion
	b.Size = UDim2.fromOffset(150, 42)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBlack
	b.Text = ""
	b.TextSize = 20 -- 20 px en negrita = texto «grande» WCAG: crema sobre verde (3,44:1) supera 3:1
	b.TextColor3 = CREMA
	b.Parent = contenedor
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	return b
end

local botonSaltar = boton("Saltar", UDim2.fromOffset(16, 214), MADERA_BOTON)
local botonSiguiente = boton("Siguiente", UDim2.fromOffset(314, 214), VERDE)

local visto -- nil = estado desconocido; false = debe verlo; true = ya lo vio
local faseLobby = nil
local paso = 1
local enviado = false

local function lobbyAbierta()
	local lobby = player.PlayerGui:FindFirstChild("LobbyUI")
	return lobby ~= nil and lobby:IsA("ScreenGui") and lobby.Enabled
end

local function pintarPaso()
	local datos = TutorialConfig.Pasos[paso]
	if not datos then
		return
	end
	progreso.Text = L("tutorial_paso", { paso, #TutorialConfig.Pasos })
	pasoTitulo.Text = L(datos.titulo)
	texto.Text = L(datos.texto)
	botonSiguiente.Text = paso >= #TutorialConfig.Pasos and L("tutorial_entendido") or L("tutorial_siguiente")
end

local function actualizar()
	local mostrar = visto == false
		and faseLobby == "esperando"
		and lobbyAbierta()
		and player:GetAttribute("EnJuego") ~= true
	contenedor.Visible = mostrar
end

local function marcarVisto()
	contenedor.Visible = false
	if enviado or visto == true then
		return
	end
	enviado = true
	visto = true
	Remotes.Esperar(Remotes.Nombres.TutorialVisto):FireServer()
end

local function aplicarTextosBase()
	titulo.Text = L("tutorial_titulo")
	botonSaltar.Text = L("tutorial_saltar")
	pintarPaso()
end

botonSaltar.Activated:Connect(marcarVisto)

botonSiguiente.Activated:Connect(function()
	if paso >= #TutorialConfig.Pasos then
		marcarVisto()
	else
		paso += 1
		pintarPaso()
	end
end)

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	aplicarTextosBase()
end)

Remotes.Esperar(Remotes.Nombres.TutorialEstado).OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	visto = datos.visto == true
	actualizar()
end)

Remotes.Esperar(Remotes.Nombres.LobbyEstado).OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" or type(datos.fase) ~= "string" then
		return
	end
	faseLobby = datos.fase
	if faseLobby ~= "esperando" then
		contenedor.Visible = false
	else
		actualizar()
	end
end)

player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") == true then
		marcarVisto() -- empezó la partida sin terminar el tutorial: no lo bloquea ni repite
	else
		actualizar()
	end
end)

task.spawn(function()
	local lobby = player.PlayerGui:WaitForChild("LobbyUI", 15)
	if lobby and lobby:IsA("ScreenGui") then
		lobby:GetPropertyChangedSignal("Enabled"):Connect(actualizar)
	end
end)

aplicarTextosBase()
print("[Tutorial] UI activa")
