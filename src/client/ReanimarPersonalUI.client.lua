-- Reanimación personal (plan §7.3): panel flotante abajo-centro, visible solo
-- mientras HudEstado diga «CAÍDO». Ofrece el stock comprado o el coste en Piñas;
-- el servidor decide y responde ReanimarResult (límite 1 por partida, Modo Puro).
-- Paleta y patrones: docs/design/design-dna.md y Hud.client.lua.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MonetizacionConfig = require(ReplicatedStorage.Shared.Config.MonetizacionConfig)

local player = Players.LocalPlayer

-- Paleta del ADN (docs/design/design-dna.md)
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21 (panel)
local MADERA_OSCURA = Color3.fromRGB(62, 42, 24) -- #3E2A18 (aviso y botón deshabilitado)
local MARRON_TARJETA = Color3.fromRGB(107, 74, 43) -- #6B4A2B (botón en enfriamiento)
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A (acción primaria)
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C (Piñas)
local ROJO_ACLARADO = Color3.fromRGB(255, 160, 143) -- #FFA08F (error legible sobre madera)

-- Remotes resueltos antes de construir la UI: Esperar puede rendir.
local remoteHudEstado = Remotes.Esperar(Remotes.Nombres.HudEstado)
local remotePaseEstado = Remotes.Esperar(Remotes.Nombres.PaseEstado)
local remoteReanimar = Remotes.Esperar(Remotes.Nombres.ReanimarPersonal)
local remoteReanimarResultado = Remotes.Esperar(Remotes.Nombres.ReanimarResult)

local gui = Instance.new("ScreenGui")
gui.Name = "ReanimarPersonalUI"
gui.Enabled = false
gui.DisplayOrder = 57
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area: el panel vive abajo, así que el inset inferior es el que manda.
local insetSuperior, insetInferior = GuiService:GetGuiInset()
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, insetSuperior.Y)
pad.PaddingBottom = UDim.new(0, insetInferior.Y)
pad.PaddingLeft = UDim.new(0, insetSuperior.X)
pad.PaddingRight = UDim.new(0, insetInferior.X)
pad.Parent = gui

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio)
	esquina.Parent = objeto
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -12)
panel.Size = UDim2.fromOffset(320, 132)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = gui
redondear(panel, 14)

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, 0, 0, 22)
titulo.Position = UDim2.fromOffset(0, 7)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 19
titulo.Text = "REANIMACIÓN PERSONAL"
titulo.TextColor3 = CREMA
titulo.Parent = panel

-- Subtítulo: stock, coste en Piñas o error del servidor (dos líneas como máximo).
local subtitulo = Instance.new("TextLabel")
subtitulo.Name = "Subtitulo"
subtitulo.Size = UDim2.new(1, -28, 0, 34)
subtitulo.Position = UDim2.fromOffset(14, 32)
subtitulo.BackgroundTransparency = 1
subtitulo.Font = Enum.Font.GothamBold
subtitulo.TextSize = 14
subtitulo.Text = ""
subtitulo.TextColor3 = AMARILLO
subtitulo.TextWrapped = true
subtitulo.TextYAlignment = Enum.TextYAlignment.Center
subtitulo.Parent = panel

local boton = Instance.new("TextButton")
boton.Name = "Reanimarme"
boton.Size = UDim2.new(1, -32, 0, 48)
boton.Position = UDim2.fromOffset(16, 72)
boton.BackgroundColor3 = VERDE
boton.BorderSizePixel = 0
boton.Font = Enum.Font.GothamBlack
boton.TextSize = 20
boton.Text = "REANIMARME"
boton.TextColor3 = CREMA
boton.TextWrapped = true -- el texto de Modo Puro ocupa dos líneas sin recortarse
boton.Parent = panel
redondear(boton, 12)

-- Aviso breve de éxito: aparece en el mismo sitio cuando el panel se oculta.
local aviso = Instance.new("Frame")
aviso.Name = "Aviso"
aviso.AnchorPoint = Vector2.new(0.5, 1)
aviso.Position = UDim2.new(0.5, 0, 1, -12)
aviso.Size = UDim2.fromOffset(220, 44)
aviso.BackgroundColor3 = MADERA_OSCURA
aviso.BorderSizePixel = 0
aviso.Visible = false
aviso.Parent = gui
redondear(aviso, 10)

local avisoTexto = Instance.new("TextLabel")
avisoTexto.Size = UDim2.fromScale(1, 1)
avisoTexto.BackgroundTransparency = 1
avisoTexto.Font = Enum.Font.GothamBlack
avisoTexto.TextSize = 20
avisoTexto.Text = "REANIMADO"
avisoTexto.TextColor3 = CREMA
avisoTexto.Parent = aviso

-- Coste de respaldo (100 Piñas) si el catálogo aún no trae costoPinas.
local itemReanimacion = MonetizacionConfig.PorId("reanimacion_personal")
local costoConfig = itemReanimacion and tonumber(itemReanimacion.costoPinas)
local COSTO = costoConfig and costoConfig > 0 and math.floor(costoConfig) or 100

local stock = 0
local modoPuro = false
local caido = false
local reanimando = false
local cooldownHasta = 0
local tokenEnfriamiento = 0
local tokenError = 0
local mensajeError = nil
local tokenAviso = 0
local ignorarCaidoHasta = 0
local intento = 0

local function actualizarSubtitulo()
	subtitulo.TextColor3 = AMARILLO
	if mensajeError then
		subtitulo.Text = mensajeError
		subtitulo.TextColor3 = ROJO_ACLARADO
		return
	end
	if modoPuro then
		subtitulo.Text = "" -- el aviso de Puro va en el botón
		return
	end
	if stock > 0 then
		subtitulo.Text = stock == 1 and "1 reanimación personal"
			or ("%d reanimaciones personales"):format(stock)
	else
		subtitulo.Text = ("%d Piñas"):format(COSTO)
	end
end

local function actualizarBoton()
	local listo = caido and not modoPuro and not reanimando and os.clock() >= cooldownHasta
	if modoPuro then
		boton.Text = "Modo Puro: sin reanimación de pago"
		boton.TextSize = 14
		boton.BackgroundColor3 = MADERA_OSCURA
		boton.TextColor3 = CREMA
		boton.TextTransparency = 0
	else
		boton.TextSize = 20
		boton.Text = reanimando and "REANIMANDO…" or "REANIMARME"
		boton.BackgroundColor3 = listo and VERDE or MARRON_TARJETA
		boton.TextColor3 = CREMA
		boton.TextTransparency = listo and 0 or 0.4
	end
	boton.Active = listo
	boton.Selectable = listo
	boton.AutoButtonColor = listo
end

local function refrescar()
	actualizarSubtitulo()
	actualizarBoton()
end

local function mostrarError(texto)
	mensajeError = type(texto) == "string" and texto ~= "" and texto or "No se pudo reanimar"
	tokenError += 1
	local token = tokenError
	refrescar()
	task.delay(2, function()
		if token == tokenError then
			mensajeError = nil
			refrescar()
		end
	end)
end

local function enfriar(segundos)
	cooldownHasta = math.max(cooldownHasta, os.clock() + segundos)
	tokenEnfriamiento += 1
	local token = tokenEnfriamiento
	refrescar()
	task.delay(segundos + 0.05, function() -- margen para que os.clock() haya superado el corte
		if token == tokenEnfriamiento then
			refrescar()
		end
	end)
end

local function mostrarAviso(texto)
	tokenAviso += 1
	local token = tokenAviso
	panel.Visible = false
	avisoTexto.Text = texto
	aviso.Visible = true
	gui.Enabled = true
	task.delay(1.6, function()
		if token ~= tokenAviso then
			return
		end
		aviso.Visible = false
		if not caido then
			gui.Enabled = false
		end
	end)
end

local function ocultarTodo()
	tokenAviso += 1
	caido = false
	panel.Visible = false
	aviso.Visible = false
	gui.Enabled = false
end

local function mostrarPanel()
	tokenAviso += 1 -- si había un aviso de éxito, se cancela
	aviso.Visible = false
	panel.Visible = true
	gui.Enabled = true
	refrescar()
end

-- HudEstado llega a 1 Hz: abre con CAÍDO y cierra con Sano o al salir de partida.
remoteHudEstado.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	local ahoraCaido = datos.estado == "CAÍDO"
	if ahoraCaido and os.clock() < ignorarCaidoHasta then
		return -- el servidor aún no ha publicado el Sano tras reanimar
	end
	if ahoraCaido then
		if not caido then
			caido = true
			mostrarPanel()
		end
	elseif caido then
		caido = false
		panel.Visible = false
		if not aviso.Visible then
			gui.Enabled = false
		end
	end
end)

remotePaseEstado.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	stock = math.max(0, math.floor(tonumber(datos.reanimaciones) or 0))
	modoPuro = datos.modoPuro == true
	refrescar()
end)

boton.Activated:Connect(function()
	if not caido or modoPuro or reanimando or os.clock() < cooldownHasta then
		return
	end
	reanimando = true
	intento += 1
	local mio = intento
	enfriar(1)
	remoteReanimar:FireServer()
	task.delay(2, function()
		if mio ~= intento or not reanimando then
			return
		end
		reanimando = false
		mostrarError("Sin respuesta del servidor")
		enfriar(1)
	end)
end)

remoteReanimarResultado.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	reanimando = false
	intento += 1
	if datos.ok == true then
		caido = false
		ignorarCaidoHasta = os.clock() + 1.5
		mensajeError = nil
		tokenError += 1
		mostrarAviso("REANIMADO")
	else
		local texto = type(datos.mensaje) == "string" and datos.mensaje or "No se pudo reanimar"
		mostrarError(texto)
		enfriar(1)
	end
end)

player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") ~= true then
		ocultarTodo()
	end
end)

refrescar()
print("[ReanimarPersonalUI] activa")
