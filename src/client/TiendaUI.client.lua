-- Tienda de Piñas (plan §7). LocalScript en StarterPlayerScripts; gui contratada con MenuInicio:
-- su botón TIENDA habilita esta gui (PlayerGui.TiendaUI) y nuestro VOLVER re-muestra MenuInicio
-- si EnJuego ~= true, mismo contrato que MenuAjustes. Panel de madera del ADN, sin UIStroke:
-- los textos van sobre madera con contraste alto (los trazos quedan para el HUD sobre el mundo).
-- SIMPLIFICACIÓN fase 5: «ya comprado» no es observable en cliente al arrancar (el servidor aún
-- no envía la lista de comprados; llegará en fase 2 con el TusDatos ampliado). Todo arranca como
-- COMPRAR: si el item ya era del jugador, el servidor responde ok («Equipado») sin cobrar y la
-- tarjeta pasa a EQUIPAR igualmente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TiendaConfig = require(ReplicatedStorage.Shared.Config.TiendaConfig)

local player = Players.LocalPlayer

-- Paleta del ADN (docs/design/design-dna.md)
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21 (panel)
local MARRON_TARJETA = Color3.fromRGB(107, 74, 43) -- #6B4A2B (tarjetas)
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A (acción primaria)
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C (Piñas)
local ROJO_AVISO = Color3.fromRGB(255, 111, 97) -- #FF6F61 (aviso temporal de compra)

local gui = Instance.new("ScreenGui")
gui.Name = "TiendaUI"
gui.Enabled = false
gui.DisplayOrder = 58
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area móvil (mismo patrón que MenuAjustes/HudPinas): respetar la notch
local inset = GuiService:GetGuiInset()
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, inset.Y)
pad.PaddingLeft = UDim.new(0, inset.X)
pad.Parent = gui

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio)
	esquina.Parent = objeto
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(500, 440)
panel.Position = UDim2.new(0.5, -250, 0.5, -220)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = gui
redondear(panel, 16)

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.fromOffset(240, 34)
titulo.Position = UDim2.new(0, 16, 0, 8)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 30
titulo.Text = "TIENDA"
titulo.TextColor3 = CREMA
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.Parent = panel

-- Saldo a la derecha del título: se refresca con el remote Pinas y con el ok de CompraResult.
local saldo = Instance.new("TextLabel")
saldo.Size = UDim2.fromOffset(220, 24)
saldo.Position = UDim2.new(1, -236, 0, 13)
saldo.BackgroundTransparency = 1
saldo.Font = Enum.Font.GothamBold
saldo.TextSize = 20
saldo.Text = "Piñas: 0"
saldo.TextColor3 = AMARILLO
saldo.TextXAlignment = Enum.TextXAlignment.Right
saldo.Parent = panel

-- Aviso temporal bajo el título (2 s) para compras fallidas.
local aviso = Instance.new("TextLabel")
aviso.Size = UDim2.new(1, 0, 0, 16)
aviso.Position = UDim2.new(0, 0, 0, 44)
aviso.BackgroundTransparency = 1
aviso.Font = Enum.Font.GothamBold
aviso.TextSize = 16
aviso.Text = ""
aviso.TextColor3 = ROJO_AVISO
aviso.Parent = panel

local tareaAviso = nil
local function mostrarAviso(texto)
	aviso.Text = texto
	if tareaAviso then
		task.cancel(tareaAviso)
	end
	tareaAviso = task.delay(2, function()
		aviso.Text = ""
		tareaAviso = nil
	end)
end

-- Grid: 8 tarjetas de 230x84 en 2 columnas x 4 filas, SIEMPRE construidas del catálogo.
-- El VOLVER (240x48) cuelga del panel como tablón 12 px por debajo: el panel de 440 ya está
-- lleno con título + aviso + 4 filas de 84, y las medidas del contrato son fijas.
local ANCHO, ALTO = 230, 84
local X_COL1, X_COL2 = 14, 256 -- 14 + 230 + 12 + 230 + 14 = 500
local Y_INICIO, PASO_Y = 66, 92 -- 66 + 4x84 + 3x8 = 426, margen inferior 14

-- Remotes resueltos una vez y ANTES de crear las tarjetas (las closures los capturan; Esperar rinde).
local remoteComprar = Remotes.Esperar(Remotes.Nombres.Comprar)
local remotePinas = Remotes.Esperar(Remotes.Nombres.Pinas)
local remoteResultado = Remotes.Esperar(Remotes.Nombres.CompraResult)

local tarjetas = {} -- id -> registro { item, boton, comprado }
local registroPendiente = nil -- tarjeta del último COMPRAR en vuelo (CompraResult no trae id)

local function marcarComprado(registro)
	registro.comprado = true
	registro.boton.Text = "EQUIPAR"
end

local function crearTarjeta(item, columna, fila)
	local tarjeta = Instance.new("Frame")
	tarjeta.Name = "Tarjeta_" .. item.id
	tarjeta.Size = UDim2.fromOffset(ANCHO, ALTO)
	tarjeta.Position = UDim2.fromOffset(columna == 1 and X_COL1 or X_COL2, Y_INICIO + (fila - 1) * PASO_Y)
	tarjeta.BackgroundColor3 = MARRON_TARJETA
	tarjeta.BorderSizePixel = 0
	tarjeta.Parent = panel
	redondear(tarjeta, 10)

	local nombre = Instance.new("TextLabel")
	nombre.Size = UDim2.new(1, item.tipo == "camiseta" and -56 or -20, 0, 22)
	nombre.Position = UDim2.new(0, 10, 0, 8)
	nombre.BackgroundTransparency = 1
	nombre.Font = Enum.Font.GothamBold
	nombre.TextSize = 18
	nombre.Text = item.nombre
	nombre.TextColor3 = CREMA
	nombre.TextXAlignment = Enum.TextXAlignment.Left
	nombre.TextTruncate = Enum.TextTruncate.AtEnd
	nombre.Parent = tarjeta

	-- Camisetas: muestra del color en un cuadrado 18x18 redondeado arriba a la derecha.
	if item.tipo == "camiseta" and item.color then
		local muestra = Instance.new("Frame")
		muestra.Size = UDim2.fromOffset(18, 18)
		muestra.Position = UDim2.new(1, -28, 0, 10)
		muestra.BackgroundColor3 = Color3.fromRGB(item.color[1], item.color[2], item.color[3])
		muestra.BorderSizePixel = 0
		muestra.Parent = tarjeta
		redondear(muestra, 6)
	end

	local precio = Instance.new("TextLabel")
	precio.Size = UDim2.fromOffset(120, 20)
	precio.Position = UDim2.new(0, 10, 0, 50) -- centrado con el botón (42..78)
	precio.BackgroundTransparency = 1
	precio.Font = Enum.Font.GothamBold
	precio.TextSize = 16
	precio.Text = ("%d %s"):format(item.precio, TiendaConfig.Moneda)
	precio.TextColor3 = AMARILLO
	precio.TextXAlignment = Enum.TextXAlignment.Left
	precio.Parent = tarjeta

	local boton = Instance.new("TextButton")
	boton.Size = UDim2.fromOffset(100, 36)
	boton.Position = UDim2.new(1, -108, 0, 42)
	boton.BackgroundColor3 = VERDE
	boton.Font = Enum.Font.GothamBlack
	boton.TextSize = 16
	boton.Text = "COMPRAR"
	boton.TextColor3 = CREMA
	boton.Parent = tarjeta
	redondear(boton, 8)

	local registro = { item = item, boton = boton, comprado = false }
	boton.Activated:Connect(function()
		registroPendiente = registro
		remoteComprar:FireServer(item.id)
	end)
	tarjetas[item.id] = registro
end

for i, item in ipairs(TiendaConfig.Catalogo) do
	crearTarjeta(item, (i - 1) % 2 + 1, math.floor((i - 1) / 2) + 1)
end

remotePinas.OnClientEvent:Connect(function(datos)
	saldo.Text = ("Piñas: %d"):format(datos.pinas or 0)
end)

remoteResultado.OnClientEvent:Connect(function(datos)
	if datos.ok == true then
		-- Compra (o re-uso «Equipado») aceptada: tarjeta a EQUIPAR y saldo del payload.
		if registroPendiente then
			marcarComprado(registroPendiente)
			registroPendiente = nil
		end
		if type(datos.pinas) == "number" then
			saldo.Text = ("Piñas: %d"):format(datos.pinas)
		end
	else
		local texto = datos.mensaje
		if type(texto) ~= "string" or texto == "" then
			texto = "Piñas insuficientes"
		end
		mostrarAviso(texto)
		registroPendiente = nil
	end
end)

local volver = Instance.new("TextButton")
volver.Name = "Volver"
volver.Size = UDim2.fromOffset(240, 48)
volver.Position = UDim2.fromOffset(130, 452) -- 12 px bajo el borde inferior del panel
volver.BackgroundColor3 = VERDE
volver.Font = Enum.Font.GothamBlack
volver.TextSize = 22
volver.Text = "VOLVER"
volver.TextColor3 = CREMA
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

print("[TiendaUI] activa")
