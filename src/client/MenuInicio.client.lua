-- Menú de inicio (concepto-ui-pantallas.png): logo, botones en columna y tagline sobre panel de madera.
-- Paleta y estilo: docs/design/design-dna.md. Patrón de GUI reutilizado de FinScreen.client.lua.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Mini-tokens del ADN (docs/design/design-dna.md)
local MADERA_PANEL = Color3.fromRGB(92, 58, 33) -- #5C3A21 panel
local MADERA_VELO = Color3.fromRGB(62, 42, 24) -- #3E2A18 velo de fondo
local MADERA_BOTON = Color3.fromRGB(107, 74, 43) -- #6B4A2B botones secundarios
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8 texto
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A acción primaria (solo JUGAR)
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C subtítulo y avisos
local BLANCO = Color3.fromRGB(255, 255, 255)

local ANIMACION = 0.2 -- s, fundido sutil de entrada (accesibilidad §8 del plan; ≤0,2 s)
local INFO_ENTRADA = TweenInfo.new(ANIMACION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "MenuInicio"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local velo = Instance.new("Frame")
velo.Name = "Velo"
velo.Size = UDim2.fromScale(1, 1)
velo.BackgroundColor3 = MADERA_VELO
velo.BackgroundTransparency = 1 -- funde hasta 0.25 al entrar
velo.BorderSizePixel = 0
velo.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PanelMenu"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(480, 470)
panel.BackgroundColor3 = MADERA_PANEL
panel.BorderSizePixel = 0
panel.Parent = velo

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 18)
esquina.Parent = panel

local function etiqueta(pos, altura, texto, tamano, fuente, color)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -24, 0, altura)
	t.Position = pos
	t.BackgroundTransparency = 1
	t.Font = fuente
	t.Text = texto
	t.TextSize = tamano
	t.TextColor3 = color
	t.Parent = panel
	return t
end

etiqueta(UDim2.new(0, 0, 0, 10), 66, "HEADS UP!", 54, Enum.Font.GothamBlack, CREMA)
etiqueta(UDim2.new(0, 0, 0, 78), 30, "MOUNTAIN MAYHEM", 24, Enum.Font.GothamBlack, AMARILLO)
etiqueta(UDim2.new(0, 0, 1, -24), 20, "No mires solo al frente…", 16, Enum.Font.Gotham, CREMA)

local mensajeSalir = etiqueta(
	UDim2.new(0, 0, 0, 422),
	22,
	"Usa el menú ESC de Roblox para salir",
	16,
	Enum.Font.Gotham,
	AMARILLO
)
mensajeSalir.Visible = false

local function botonMenu(texto, y, color, colorTexto)
	local b = Instance.new("TextButton")
	b.Name = "Boton" .. texto
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Position = UDim2.new(0.5, 0, 0, y)
	b.Size = UDim2.fromOffset(300, 56) -- objetivo de toque grande (≥44 px)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.Text = texto
	b.TextSize = 24
	b.TextColor3 = colorTexto
	b.Parent = panel

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = b
	return b
end

local botonJugar = botonMenu("JUGAR", 116, VERDE, BLANCO)
local botonPersonalizar = botonMenu("PERSONALIZAR", 182, MADERA_BOTON, CREMA)
local botonAjustes = botonMenu("AJUSTES", 248, MADERA_BOTON, CREMA)
local botonTienda = botonMenu("TIENDA", 314, MADERA_BOTON, CREMA)
local botonSalir = botonMenu("SALIR", 380, MADERA_BOTON, CREMA)

-- Aviso de «llega en una fase futura»: cambia el texto y congela el color 1,5 s. Devuelve la acción.
local function avisoFase(boton, textoAviso)
	local textoOriginal = boton.Text
	local marca = 0
	return function()
		marca += 1
		local esta = marca
		boton.Text = textoAviso
		boton.AutoButtonColor = false
		task.delay(1.5, function()
			if marca == esta then
				boton.Text = textoOriginal
				boton.AutoButtonColor = true
			end
		end)
	end
end

-- JUGAR abre la sala de espera; el servidor decide cuándo empieza (Comenzar en LobbyUI).
local avisoJugar = avisoFase(botonJugar, "SALA NO DISPONIBLE")
local abriendoLobby = false

botonJugar.Activated:Connect(function()
	if abriendoLobby then
		return
	end
	abriendoLobby = true
	botonJugar.Text = "ABRIENDO…"
	botonJugar.AutoButtonColor = false
	local lobby = player.PlayerGui:WaitForChild("LobbyUI", 5)
	botonJugar.Text = "JUGAR"
	botonJugar.AutoButtonColor = true
	abriendoLobby = false
	if lobby and lobby:IsA("ScreenGui") then
		lobby.Enabled = true
		gui.Enabled = false -- no se destruye: el VOLVER de LobbyUI re-muestra este menú
		return
	end
	avisoJugar() -- sin lobby no se pone EnJuego ni se inicia nada
end)

local avisoFasePersonalizar = avisoFase(botonPersonalizar, "PERSONALIZAR · fase 4")
botonPersonalizar.Activated:Connect(function()
	local personalizacion = player.PlayerGui:FindFirstChild("Personalizacion")
	if personalizacion then
		personalizacion.Enabled = true
		gui.Enabled = false
		return
	end
	avisoFasePersonalizar()
end)

local parpadearAjustes = avisoFase(botonAjustes, "AJUSTES · fase siguiente")
botonAjustes.Activated:Connect(function()
	local menuAjustes = player.PlayerGui:FindFirstChild("MenuAjustes")
	if menuAjustes then
		menuAjustes.Enabled = true
		gui.Enabled = false -- el VOLVER de MenuAjustes nos re-muestra (contrato); sin tocar EnJuego
		return
	end
	parpadearAjustes()
end)

local parpadearTienda = avisoFase(botonTienda, "TIENDA · fase siguiente")
botonTienda.Activated:Connect(function()
	local tienda = player.PlayerGui:FindFirstChild("TiendaUI")
	if tienda then
		tienda.Enabled = true
		gui.Enabled = false
		return
	end
	parpadearTienda()
end)

local marcaSalir = 0
botonSalir.Activated:Connect(function()
	marcaSalir += 1
	local esta = marcaSalir
	mensajeSalir.Visible = true
	task.delay(2.5, function()
		if marcaSalir == esta then
			mensajeSalir.Visible = false
		end
	end)
end)

-- Entrada sutil: solo funde el velo; el panel aparece sólido con él.
TweenService:Create(velo, INFO_ENTRADA, { BackgroundTransparency = 0.25 }):Play()

print("[MenuInicio] activo")
