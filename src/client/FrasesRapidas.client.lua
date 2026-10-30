-- Frases rápidas (fase 11 · L4/B8): G / ButtonL1 o el botón táctil abre una rejilla
-- de 8 frases de cooperación. El cliente solo manda el id; el servidor valida, aplica
-- el límite de frecuencia, traduce al idioma de cada receptor y filtra el texto.
-- Las frases recibidas se pintan en el chat (ChatRapido) y como burbuja sobre el emisor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local FrasesConfig = require(ReplicatedStorage.Shared.Config.FrasesConfig)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

-- Mini-tokens del ADN (docs/design/design-dna.md)
local MADERA = Color3.fromRGB(62, 42, 24) -- #3E2A18
local MADERA_OSCURA = Color3.fromRGB(92, 58, 33) -- #5C3A21 botón
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C nombre en el chat

local player = Players.LocalPlayer
local remoteFrase = Remotes.Esperar(Remotes.Nombres.FraseRapida)
local remoteChat = Remotes.Esperar(Remotes.Nombres.ChatRapido)
local remoteIdioma = Remotes.Esperar(Remotes.Nombres.IdiomaCliente)

-- Handshake de idioma: el servidor traduce cada frase al idioma del receptor.
local function enviarIdioma()
	remoteIdioma:FireServer(Settings.Obtener("idioma"))
end
enviarIdioma()

local gui = Instance.new("ScreenGui")
gui.Name = "FrasesRapidas"
gui.ResetOnSpawn = false
gui.DisplayOrder = 56
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area inferior (barra de gestos); el panel se ancla sobre la fila de acciones táctiles.
local _, insetInferior = GuiService:GetGuiInset()

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -(84 + insetInferior.Y))
panel.Size = UDim2.fromOffset(320, 252)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 14)
esquina.Parent = panel

-- En pantallas estrechas el panel se encoge hasta 0,7 para seguir cabiendo entero.
local escala = Instance.new("UIScale")
escala.Parent = panel
local function ajustarEscala()
	local ancho = gui.AbsoluteSize.X
	local alto = gui.AbsoluteSize.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	escala.Scale = math.clamp(math.min(ancho / 360, (alto - 96) / 252), 0.7, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -76, 0, 20)
titulo.Position = UDim2.fromOffset(14, 16)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 16
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.TextColor3 = CREMA
titulo.Text = L("frases_titulo")
titulo.Parent = panel

local botonCerrar = Instance.new("TextButton")
botonCerrar.Name = "Cerrar"
botonCerrar.Size = UDim2.fromOffset(44, 44)
botonCerrar.Position = UDim2.new(1, -52, 0, 2)
botonCerrar.BackgroundColor3 = MADERA_OSCURA
botonCerrar.BorderSizePixel = 0
botonCerrar.Font = Enum.Font.GothamBlack
botonCerrar.TextSize = 18
botonCerrar.Text = "X"
botonCerrar.TextColor3 = CREMA
botonCerrar.Selectable = true
botonCerrar.Parent = panel

local esquinaCerrar = Instance.new("UICorner")
esquinaCerrar.CornerRadius = UDim.new(0, 8)
esquinaCerrar.Parent = botonCerrar

local contenedor = Instance.new("Frame")
contenedor.Name = "Rejilla"
contenedor.Size = UDim2.new(1, -20, 0, 194)
contenedor.Position = UDim2.fromOffset(10, 52)
contenedor.BackgroundTransparency = 1
contenedor.Parent = panel

local rejilla = Instance.new("UIGridLayout")
rejilla.CellSize = UDim2.fromOffset(143, 44)
rejilla.CellPadding = UDim2.fromOffset(8, 6)
rejilla.FillDirectionMaxCells = 2
rejilla.SortOrder = Enum.SortOrder.LayoutOrder
rejilla.HorizontalAlignment = Enum.HorizontalAlignment.Center
rejilla.Parent = contenedor

local abierto = false
local enfriamientoHasta = 0
local botones = {}

local function cerrar()
	abierto = false
	panel.Visible = false
	GuiService.SelectedObject = nil
end

-- Aviso de la tecla en el mismo apilado que las pistas de linterna y cámara.
local aviso = Instance.new("TextLabel")
aviso.Name = "AvisoFrases"
aviso.AnchorPoint = Vector2.new(1, 1)
aviso.Position = UDim2.new(1, -16, 1, -62)
aviso.Size = UDim2.fromOffset(120, 24)
aviso.BackgroundTransparency = 1
aviso.Font = Enum.Font.Gotham
aviso.TextSize = 14
aviso.TextTransparency = 0.25
aviso.TextXAlignment = Enum.TextXAlignment.Right
aviso.TextColor3 = CREMA
aviso.Text = L("g_frases")
aviso.Parent = gui

local function abrir()
	if player:GetAttribute("EnJuego") ~= true then
		return
	end
	abierto = true
	panel.Visible = true
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = botones[1] and botones[1].boton or nil
	end
end

local function alternar()
	if abierto then
		cerrar()
	else
		abrir()
	end
end

-- Espejo local del límite del servidor (2 s): evita dobles envíos por doble toque.
local function enviar(id)
	if os.clock() < enfriamientoHasta then
		return
	end
	enfriamientoHasta = os.clock() + FrasesConfig.Enfriamiento
	cerrar()
	remoteFrase:FireServer(id)
end

for i, id in ipairs(FrasesConfig.Frases) do
	local boton = Instance.new("TextButton")
	boton.Name = "Frase" .. id
	boton.LayoutOrder = i
	boton.Size = UDim2.fromOffset(143, 44)
	boton.BackgroundColor3 = MADERA_OSCURA
	boton.BorderSizePixel = 0
	boton.Font = Enum.Font.GothamBold
	boton.TextSize = 16
	boton.TextWrapped = true
	boton.TextColor3 = CREMA
	boton.Text = L("frase_" .. id)
	boton.Selectable = true
	boton.Parent = contenedor

	local redondeo = Instance.new("UICorner")
	redondeo.CornerRadius = UDim.new(0, 10)
	redondeo.Parent = boton

	boton.Activated:Connect(function()
		enviar(id)
	end)
	table.insert(botones, { boton = boton, id = id })
end

botonCerrar.Activated:Connect(cerrar)

local TECLAS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
}

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado then
		return
	end
	if entrada.KeyCode == Enum.KeyCode.G or entrada.KeyCode == Enum.KeyCode.ButtonL1 then
		alternar()
		return
	end
	if not abierto then
		return
	end
	local indice = TECLAS[entrada.KeyCode]
	local registro = indice and botones[indice]
	if registro then
		enviar(registro.id)
	end
end)

player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") ~= true then
		cerrar()
	end
end)

-- Táctil: el botón «Frases» de la fila compartida sustituye al atajo G.
if UserInputService.TouchEnabled then
	aviso.Visible = false
	local Acciones = require(script.Parent:WaitForChild("Acciones"))
	local botonFrase = Acciones.CrearBoton("frases", 4)
	local function actualizarVisibilidad()
		botonFrase.Visible = player:GetAttribute("EnJuego") == true
	end
	player:GetAttributeChangedSignal("EnJuego"):Connect(actualizarVisibilidad)
	actualizarVisibilidad()
	botonFrase.Activated:Connect(alternar)
end

-- Pintado en el chat: mismo patrón que ChatMimicView (canal RBXGeneral + burbuja).
-- El texto llega YA filtrado por receptor; aquí solo se escapa para RichText.
local canales = TextChatService:WaitForChild("TextChannels", 10)
local canal = canales and canales:WaitForChild("RBXGeneral", 10)
if not canal then
	warn("[Frases] sin canal RBXGeneral: las frases no se pintan en el chat")
end

local function escapar(texto)
	return (tostring(texto):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

remoteChat.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" or type(datos.texto) ~= "string" or datos.texto == "" then
		return
	end
	local nombre = type(datos.nombre) == "string" and datos.nombre or ""
	if canal then
		canal:DisplaySystemMessage(('<font color="#FFC93C"><b>[%s]:</b></font> <font color="#F5EBD8">%s</font>'):format(
			escapar(nombre),
			escapar(datos.texto)
		))
	end
	if TextChatService.DisplayBubble and type(datos.usuario) == "number" then
		local emisor = Players:GetPlayerByUserId(datos.usuario)
		local cabeza = emisor and emisor.Character and emisor.Character:FindFirstChild("Head")
		if cabeza then
			TextChatService:DisplayBubble(cabeza, datos.texto)
		end
	end
end)

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	titulo.Text = L("frases_titulo")
	aviso.Text = L("g_frases")
	for _, registro in ipairs(botones) do
		registro.boton.Text = L("frase_" .. registro.id)
	end
	enviarIdioma()
end)

print("[Frases] activo (G / L1 / botón táctil)")
