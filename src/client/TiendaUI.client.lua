-- Tienda (plan §7): panel de madera 500x440 con pestañas PIÑAS y ROBUX.
-- PIÑAS conserva el catálogo de TiendaConfig y su flujo Comprar/CompraResult/Pinas;
-- ROBUX lista MonetizacionConfig y solo avisa al servidor (la entrega se revalida allí).
-- PaseEstado pinta los pases ACTIVO, el stock de reanimaciones, Piñas x2 y Modo Puro.
-- Contrato con MenuInicio: su botón TIENDA habilita esta gui; VOLVER la oculta y
-- re-muestra MenuInicio si EnJuego ~= true. Fase 9: la misma gui la abre el
-- ProximityPrompt "TiendaInicio" del puesto del campamento (en lobby y en partida),
-- y PIÑAS añade la bebida energética y las mejoras por niveles.
-- Paleta: docs/design/design-dna.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local TiendaConfig = require(ReplicatedStorage.Shared.Config.TiendaConfig)
local MonetizacionConfig = require(ReplicatedStorage.Shared.Config.MonetizacionConfig)
local TelemetriaConfig = require(ReplicatedStorage.Shared.Config.TelemetriaConfig)
local MenuCamara = require(script.Parent:WaitForChild("MenuCamara"))

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer

-- Paleta del ADN (docs/design/design-dna.md)
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21 (panel)
local MADERA_OSCURA = Color3.fromRGB(62, 42, 24) -- #3E2A18 (botón deshabilitado)
local MARRON_TARJETA = Color3.fromRGB(107, 74, 43) -- #6B4A2B (tarjetas)
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A (acción primaria)
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C (Piñas y selección)
local ROJO_AVISO = Color3.fromRGB(255, 111, 97) -- #FF6F61 (aviso de error)

-- Remotes resueltos una vez y ANTES de construir la UI: Esperar puede rendir.
local remoteComprar = Remotes.Esperar(Remotes.Nombres.Comprar)
local remotePinas = Remotes.Esperar(Remotes.Nombres.Pinas)
local remoteResultado = Remotes.Esperar(Remotes.Nombres.CompraResult)
local remoteComprarRobux = Remotes.Esperar(Remotes.Nombres.ComprarRobux)
local remoteRobuxResultado = Remotes.Esperar(Remotes.Nombres.RobuxResult)
local remotePaseEstado = Remotes.Esperar(Remotes.Nombres.PaseEstado)
local remoteReclamarPase = Remotes.Esperar(Remotes.Nombres.ReclamarPase)
local remoteModoPuro = Remotes.Esperar(Remotes.Nombres.ModoPuro)
local remoteTelemetria = Remotes.Esperar(Remotes.Nombres.TelemetriaUI)

local gui = Instance.new("ScreenGui")
gui.Name = "TiendaUI"
gui.Enabled = false
gui.DisplayOrder = 58
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
MenuCamara.Vincular(gui)

-- Safe area móvil: respetar notch y barras del sistema en los cuatro lados.
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
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(500, 440)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = gui
redondear(panel, 16)

-- El panel nominal es 500x440; en pantallas estrechas se escala el conjunto
-- (mismo patrón que LobbyUI/CustomizationUI) para no recortar el VOLVER.
-- Suelo 0,62 cuando el ancho lo permite: a ese tamaño el precio ROBUX (18 px base)
-- sigue por encima de 11 px físicos incluso en un móvil de 320 px.
local escala = Instance.new("UIScale")
escala.Parent = panel
local function ajustarEscala()
	local ancho, alto = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	local suelo = math.max(0.62, math.min(0.72, ancho / 500))
	escala.Scale = math.clamp(math.min(ancho / 540, alto / 560), suelo, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local pinasActuales = 0

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.fromOffset(240, 34)
titulo.Position = UDim2.fromOffset(16, 4)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 30
titulo.Text = L("tienda"):upper()
titulo.TextColor3 = CREMA
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.Parent = panel

-- Saldo a la derecha del título: se refresca con el remote Pinas y con el ok de CompraResult.
local saldo = Instance.new("TextLabel")
saldo.Size = UDim2.fromOffset(220, 24)
saldo.Position = UDim2.new(1, -236, 0, 9)
saldo.BackgroundTransparency = 1
saldo.Font = Enum.Font.GothamBold
saldo.TextSize = 20
saldo.Text = L("pinas") .. ": 0"
saldo.TextColor3 = AMARILLO
saldo.TextXAlignment = Enum.TextXAlignment.Right
saldo.Parent = panel

-- Aviso compartido (2 s) para Piñas, Robux, reclamo de pase y Modo Puro.
local aviso = Instance.new("TextLabel")
aviso.Name = "Aviso"
aviso.Size = UDim2.new(1, 0, 0, 16)
aviso.Position = UDim2.fromOffset(0, 84)
aviso.BackgroundTransparency = 1
aviso.Font = Enum.Font.GothamBold
aviso.TextSize = 15
aviso.Text = ""
aviso.TextColor3 = ROJO_AVISO
aviso.TextTruncate = Enum.TextTruncate.AtEnd
aviso.Parent = panel

local tareaAviso = nil
local function mostrarAviso(texto, color)
	aviso.Text = texto
	aviso.TextColor3 = color or ROJO_AVISO
	if tareaAviso then
		task.cancel(tareaAviso)
	end
	tareaAviso = task.delay(2, function()
		aviso.Text = ""
		tareaAviso = nil
	end)
end

-- Pestañas bajo el título: 130x44 (objetivo táctil), activa en amarillo con texto oscuro.
local function crearPestana(texto, x)
	local b = Instance.new("TextButton")
	b.Name = "Pestana" .. texto
	b.Size = UDim2.fromOffset(130, 44)
	b.Position = UDim2.fromOffset(x, 40)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 19
	b.Text = texto
	b.Parent = panel
	redondear(b, 10)
	return b
end

local pestanaPinas = crearPestana(L("pinas_tab"), 16)
local pestanaRobux = crearPestana(L("robux"), 154)

local function pintarPestana(boton, activa)
	boton.BackgroundColor3 = activa and AMARILLO or MARRON_TARJETA
	boton.TextColor3 = activa and MADERA_OSCURA or CREMA
end

-- Páginas: se muestran/ocultan, nunca se destruyen. Contenido desde y=100.
local paginaPinas = Instance.new("Frame")
paginaPinas.Name = "PaginaPinas"
paginaPinas.Position = UDim2.fromOffset(16, 100)
paginaPinas.Size = UDim2.fromOffset(468, 338)
paginaPinas.BackgroundTransparency = 1
paginaPinas.Parent = panel

-- La página PIÑAS ya no cabe a la vista (11 tarjetas): mismas posiciones manuales
-- dentro de un ScrollingFrame, como la página ROBUX.
local scrollPinas = Instance.new("ScrollingFrame")
scrollPinas.Name = "CatalogoPinas"
scrollPinas.Size = UDim2.fromOffset(468, 338)
scrollPinas.BackgroundTransparency = 1
scrollPinas.BorderSizePixel = 0
scrollPinas.ScrollBarThickness = 5
scrollPinas.ScrollBarImageColor3 = CREMA
scrollPinas.ScrollingDirection = Enum.ScrollingDirection.Y
scrollPinas.CanvasSize = UDim2.fromOffset(0, 0)
scrollPinas.Parent = paginaPinas

local paginaRobux = Instance.new("Frame")
paginaRobux.Name = "PaginaRobux"
paginaRobux.Position = UDim2.fromOffset(16, 100)
paginaRobux.Size = UDim2.fromOffset(468, 338)
paginaRobux.BackgroundTransparency = 1
paginaRobux.Visible = false
paginaRobux.Parent = panel

-- Estado de monetización recibido del servidor (PaseEstado).
local estadoPases = {
	pases = {},
	reanimaciones = 0,
	pinasX2Hasta = 0,
	modoPuro = false,
	activo = false,
}
local registrosRobux = {}
local refrescarEstadoRobux -- se define tras crear las etiquetas de la pestaña ROBUX

local function seleccionar(cual)
	local pinas = cual == "pinas"
	paginaPinas.Visible = pinas
	paginaRobux.Visible = not pinas
	pintarPestana(pestanaPinas, pinas)
	pintarPestana(pestanaRobux, not pinas)
	if not pinas and refrescarEstadoRobux then
		refrescarEstadoRobux()
	end
end

-- Telemetría (E46): el servidor solo acepta los nombres de TelemetriaConfig.EventosUI.
local function anunciarEvento(nombre)
	remoteTelemetria:FireServer(nombre)
end

local function anunciarPestana()
	if paginaRobux.Visible then
		anunciarEvento(TelemetriaConfig.Eventos.TiendaPestanaRobux)
	else
		anunciarEvento(TelemetriaConfig.Eventos.TiendaPestanaPinas)
	end
end

-- ===== PESTAÑA PIÑAS =====
-- Tarjetas de 230x80 en 2 columnas (230 + 8 + 230 = 468), con scroll vertical.
local ANCHO_TARJETA, ALTO_TARJETA = 230, 80
local PASO_X, PASO_Y = 238, 85

local registroPendiente = nil -- tarjeta del último COMPRAR en vuelo (CompraResult no trae id)
local registrosPinas = {}

local function marcarComprado(registro)
	registro.comprado = true
	registro.boton.Text = L("equipar")
end

-- Nivel de una mejora a partir de los atributos de TiendaService: no hay atributo
-- de nivel, pero MonedasMult = 1 + 0,25·nivel y Cansancio = 1 - 0,15·nivel.
-- El +0,5 absorbe el error de coma flotante antes de truncar.
local function nivelMejora(item)
	local nivel
	if item.mejora == "monedas" then
		local mult = tonumber(player:GetAttribute("MonedasMult")) or 1
		nivel = math.floor((mult - 1) / 0.25 + 0.5)
	else
		local cansancio = tonumber(player:GetAttribute("Cansancio")) or 1
		nivel = math.floor((1 - cansancio) / 0.15 + 0.5)
	end
	return math.clamp(nivel, 0, item.maximo)
end

-- Estado de bebida/mejora: stock o nivel, precio del siguiente nivel y si COMPRAR
-- está disponible (saldo suficiente y no estar al máximo). Los cosméticos no pasan
-- por aquí: conservan su flujo EQUIPAR.
local function nombreItem(item)
	return item.nombreClave and L(item.nombreClave) or item.nombre
end

-- Tope de bebidas: 5 base + 1 con Mochila Pro; Modo Puro anula la ventaja.
local function maxBebidas(item)
	if estadoPases.pases and estadoPases.pases.mochilaPro == true and estadoPases.modoPuro ~= true then
		return (item.maximo or 5) + 1
	end
	return item.maximo or 5
end

local function refrescarTarjeta(registro)
	local item = registro.item
	if registro.nombre then
		registro.nombre.Text = nombreItem(item)
	end
	if item.tipo == "bebida" then
		local tope = maxBebidas(item)
		-- Modo Puro recorta el tope sin borrar la 6.ª bebida de Mochila Pro: se acota
		-- también el número para no enseñar «6/5».
		local stock = math.min(tonumber(player:GetAttribute("Bebidas")) or 0, tope)
		local alMaximo = stock >= tope
		registro.descripcion.Text = L(item.descripcionClave)
		registro.estado.Text = L("bebidas") .. ": " .. stock .. "/" .. tope
		registro.precio.Text = alMaximo and L("maximo"):upper() or ("%d %s"):format(item.precio, L(TiendaConfig.MonedaClave))
		registro.habilitado = not alMaximo and pinasActuales >= item.precio
	elseif item.tipo == "mejora" then
		local nivel = nivelMejora(item)
		local siguiente = item.precios[nivel + 1]
		registro.descripcion.Text = L(item.descripcionClave)
		registro.estado.Text = L("nivel") .. " " .. nivel .. "/" .. item.maximo
		if nivel >= item.maximo or not siguiente then
			registro.precio.Text = L("maximo"):upper()
			registro.habilitado = false
		else
			registro.precio.Text = ("%d %s"):format(siguiente, L(TiendaConfig.MonedaClave))
			registro.habilitado = pinasActuales >= siguiente
		end
	else
		registro.boton.Text = registro.comprado and L("equipar") or L("comprar")
		return
	end
	registro.boton.Text = L("comprar")
	registro.boton.BackgroundColor3 = registro.habilitado and VERDE or MADERA_OSCURA
	registro.boton.TextTransparency = registro.habilitado and 0 or 0.35
	registro.boton.AutoButtonColor = registro.habilitado
	registro.boton.Selectable = registro.habilitado
end

local function refrescarTarjetas()
	for _, registro in ipairs(registrosPinas) do
		refrescarTarjeta(registro)
	end
end

-- ===== Confirmación de compra (C25) =====
-- Un solo diálogo para toda la pestaña PIÑAS: cancelar no toca el servidor; confirmar
-- envía la petición de siempre (el servidor valida saldo y nunca cobra dos veces).
-- ROBUX no pasa por aquí: su compra ya abre el prompt nativo de Roblox.
local veloCompra = Instance.new("Frame")
veloCompra.Name = "VeloCompra"
veloCompra.Size = UDim2.fromScale(1, 1)
veloCompra.BackgroundColor3 = Color3.fromRGB(12, 8, 5)
veloCompra.BackgroundTransparency = 0.45
veloCompra.BorderSizePixel = 0
veloCompra.Active = true -- bloquea la tienda de detrás
veloCompra.Visible = false
veloCompra.ZIndex = 20
veloCompra.Parent = gui

local dialogoCompra = Instance.new("Frame")
dialogoCompra.Name = "DialogoCompra"
dialogoCompra.AnchorPoint = Vector2.new(0.5, 0.5)
dialogoCompra.Position = UDim2.fromScale(0.5, 0.5)
dialogoCompra.Size = UDim2.fromOffset(380, 236)
dialogoCompra.BackgroundColor3 = MADERA
dialogoCompra.BorderSizePixel = 0
dialogoCompra.ZIndex = 21
dialogoCompra.Parent = veloCompra
redondear(dialogoCompra, 14)

local escalaDialogo = Instance.new("UIScale")
escalaDialogo.Parent = dialogoCompra
local function ajustarEscalaDialogo()
	local ancho, alto = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	escalaDialogo.Scale = math.clamp(math.min(ancho / 440, alto / 340), 0.8, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscalaDialogo)
ajustarEscalaDialogo()

local dialogoTitulo = Instance.new("TextLabel")
dialogoTitulo.Size = UDim2.new(1, -32, 0, 28)
dialogoTitulo.Position = UDim2.fromOffset(16, 14)
dialogoTitulo.BackgroundTransparency = 1
dialogoTitulo.Font = Enum.Font.GothamBlack
dialogoTitulo.TextSize = 21
dialogoTitulo.Text = L("confirmar_compra")
dialogoTitulo.TextColor3 = CREMA
dialogoTitulo.Parent = dialogoCompra

local dialogoNombre = Instance.new("TextLabel")
dialogoNombre.Size = UDim2.new(1, -32, 0, 26)
dialogoNombre.Position = UDim2.fromOffset(16, 48)
dialogoNombre.BackgroundTransparency = 1
dialogoNombre.Font = Enum.Font.GothamBold
dialogoNombre.TextSize = 18
dialogoNombre.TextColor3 = CREMA
dialogoNombre.TextTruncate = Enum.TextTruncate.AtEnd
dialogoNombre.Parent = dialogoCompra

local dialogoPrecio = Instance.new("TextLabel")
dialogoPrecio.Size = UDim2.new(1, -32, 0, 28)
dialogoPrecio.Position = UDim2.fromOffset(16, 78)
dialogoPrecio.BackgroundTransparency = 1
dialogoPrecio.Font = Enum.Font.GothamBlack
dialogoPrecio.TextSize = 21
dialogoPrecio.TextColor3 = AMARILLO
dialogoPrecio.Parent = dialogoCompra

local dialogoSaldo = Instance.new("TextLabel")
dialogoSaldo.Size = UDim2.new(1, -32, 0, 22)
dialogoSaldo.Position = UDim2.fromOffset(16, 108)
dialogoSaldo.BackgroundTransparency = 1
dialogoSaldo.Font = Enum.Font.Gotham
dialogoSaldo.TextSize = 16
dialogoSaldo.TextColor3 = CREMA
dialogoSaldo.TextTransparency = 0.15
dialogoSaldo.Parent = dialogoCompra

-- 56 px de alto: con la escala mínima 0,8 siguen quedando ≥ 44 px de objetivo
-- táctil en pantallas pequeñas (regla de la revisión apple-design).
local botonCancelarCompra = Instance.new("TextButton")
botonCancelarCompra.Name = "CancelarCompra"
botonCancelarCompra.Size = UDim2.fromOffset(160, 56)
botonCancelarCompra.Position = UDim2.fromOffset(20, 156)
botonCancelarCompra.BackgroundColor3 = MADERA_OSCURA
botonCancelarCompra.Font = Enum.Font.GothamBold
botonCancelarCompra.TextSize = 18
botonCancelarCompra.Text = L("cancelar"):upper()
botonCancelarCompra.TextColor3 = CREMA
botonCancelarCompra.Parent = dialogoCompra
redondear(botonCancelarCompra, 10)

local botonConfirmarCompra = Instance.new("TextButton")
botonConfirmarCompra.Name = "ConfirmarCompra"
botonConfirmarCompra.Size = UDim2.fromOffset(160, 56)
botonConfirmarCompra.Position = UDim2.fromOffset(200, 156)
botonConfirmarCompra.BackgroundColor3 = VERDE
botonConfirmarCompra.Font = Enum.Font.GothamBlack
botonConfirmarCompra.TextSize = 18
botonConfirmarCompra.Text = L("comprar")
botonConfirmarCompra.TextColor3 = CREMA
botonConfirmarCompra.Parent = dialogoCompra
redondear(botonConfirmarCompra, 10)

local registroEnCompra = nil -- tarjeta pendiente de confirmar

local function cerrarConfirmacion()
	veloCompra.Visible = false
	registroEnCompra = nil
end

local function abrirConfirmacion(registro)
	local precio = registro.item.tipo == "mejora"
		and registro.item.precios[nivelMejora(registro.item) + 1]
		or registro.item.precio
	if type(precio) ~= "number" then
		return
	end
	dialogoNombre.Text = nombreItem(registro.item)
	dialogoPrecio.Text = ("%d %s"):format(precio, L(TiendaConfig.MonedaClave))
	dialogoSaldo.Text = L("pinas") .. ": " .. ("%d"):format(pinasActuales)
	registroEnCompra = registro
	veloCompra.Visible = true
end

botonCancelarCompra.Activated:Connect(cerrarConfirmacion)
botonConfirmarCompra.Activated:Connect(function()
	local registro = registroEnCompra
	if not registro then
		return
	end
	cerrarConfirmacion() -- con el velo oculto, un segundo clic no llega
	registroPendiente = registro
	remoteComprar:FireServer({ id = registro.item.id })
end)

-- Cerrar la tienda por cualquier vía (partida, aviso del servidor) no deja el
-- diálogo armado para la próxima apertura.
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not gui.Enabled then
		cerrarConfirmacion()
	end
end)

local function crearTarjetaPinas(item, columna, fila)
	local tarjeta = Instance.new("Frame")
	tarjeta.Name = "Tarjeta_" .. item.id
	tarjeta.Size = UDim2.fromOffset(ANCHO_TARJETA, ALTO_TARJETA)
	tarjeta.Position = UDim2.fromOffset((columna - 1) * PASO_X, (fila - 1) * PASO_Y)
	tarjeta.BackgroundColor3 = MARRON_TARJETA
	tarjeta.BorderSizePixel = 0
	tarjeta.Parent = scrollPinas
	redondear(tarjeta, 10)

	local esConsumo = item.tipo == "bebida" or item.tipo == "mejora"

	local nombre = Instance.new("TextLabel")
	nombre.Size = UDim2.new(1, item.tipo == "camiseta" and -40 or -20, 0, 22)
	nombre.Position = UDim2.fromOffset(10, 5)
	nombre.BackgroundTransparency = 1
	nombre.Font = Enum.Font.GothamBold
	nombre.TextSize = 17
	nombre.Text = nombreItem(item)
	nombre.TextColor3 = CREMA
	nombre.TextXAlignment = Enum.TextXAlignment.Left
	nombre.TextTruncate = Enum.TextTruncate.AtEnd
	nombre.Parent = tarjeta

	-- Camisetas: muestra del color en un cuadrado 18x18 redondeado arriba a la derecha.
	if item.tipo == "camiseta" and item.color then
		local muestra = Instance.new("Frame")
		muestra.Size = UDim2.fromOffset(18, 18)
		muestra.Position = UDim2.new(1, -28, 0, 8)
		muestra.BackgroundColor3 = Color3.fromRGB(item.color[1], item.color[2], item.color[3])
		muestra.BorderSizePixel = 0
		muestra.Parent = tarjeta
		redondear(muestra, 6)
	end

	local precio = Instance.new("TextLabel")
	precio.Size = UDim2.fromOffset(108, 18)
	precio.Position = UDim2.fromOffset(10, esConsumo and 55 or 45) -- centrado con el botón (29..73)
	precio.BackgroundTransparency = 1
	precio.Font = Enum.Font.GothamBold
	precio.TextSize = esConsumo and 14 or 16
	precio.TextColor3 = AMARILLO
	precio.TextXAlignment = Enum.TextXAlignment.Left
	precio.Parent = tarjeta

	local boton = Instance.new("TextButton")
	boton.Size = UDim2.fromOffset(100, 44)
	boton.Position = UDim2.new(1, -108, 0, 29)
	boton.BackgroundColor3 = VERDE
	boton.Font = Enum.Font.GothamBlack
	boton.TextSize = 15
	boton.Text = L("comprar")
	boton.TextColor3 = CREMA
	boton.Parent = tarjeta
	redondear(boton, 8)

	local registro = { item = item, nombre = nombre, boton = boton, comprado = false, precio = precio }
	table.insert(registrosPinas, registro)
	boton.Activated:Connect(function()
		if registro.habilitado == false then
			return
		end
		if registro.comprado then
			-- Re-equipar un cosmético ya pagado es gratis: sin diálogo.
			registroPendiente = registro
			remoteComprar:FireServer({ id = item.id })
			return
		end
		abrirConfirmacion(registro)
	end)

	if esConsumo then
		-- Nombre, descripción breve, estado (stock/nivel) y precio en la columna
		-- izquierda; el botón sigue a la derecha con su objetivo táctil de 44 px.
		nombre.TextSize = 16
		local descripcion = Instance.new("TextLabel")
		descripcion.Size = UDim2.new(1, -20, 0, 14)
		descripcion.Position = UDim2.fromOffset(10, 23)
		descripcion.BackgroundTransparency = 1
		descripcion.Font = Enum.Font.Gotham
		descripcion.TextSize = 12
		descripcion.TextColor3 = CREMA
		descripcion.TextTransparency = 0.15
		descripcion.TextXAlignment = Enum.TextXAlignment.Left
		descripcion.TextTruncate = Enum.TextTruncate.AtEnd
		descripcion.Parent = tarjeta
		registro.descripcion = descripcion

		local estado = Instance.new("TextLabel")
		estado.Size = UDim2.fromOffset(100, 16)
		estado.Position = UDim2.fromOffset(10, 38)
		estado.BackgroundTransparency = 1
		estado.Font = Enum.Font.GothamBold
		estado.TextSize = 13
		estado.TextColor3 = CREMA
		estado.TextXAlignment = Enum.TextXAlignment.Left
		estado.Parent = tarjeta
		registro.estado = estado

		refrescarTarjeta(registro)
	else
		precio.Text = ("%d %s"):format(item.precio, L(TiendaConfig.MonedaClave))
	end
end

for i, item in ipairs(TiendaConfig.Catalogo) do
	crearTarjetaPinas(item, (i - 1) % 2 + 1, math.floor((i - 1) / 2) + 1)
end
local filasPinas = math.ceil(#TiendaConfig.Catalogo / 2)
scrollPinas.CanvasSize = UDim2.fromOffset(0, filasPinas * PASO_Y - (PASO_Y - ALTO_TARJETA))
-- Los atributos del servidor pueden llegar después de crear las tarjetas (carga
-- del DataStore) y cambian al beber/comprar: el panel se repinta con ellos.
player:GetAttributeChangedSignal("Bebidas"):Connect(refrescarTarjetas)
player:GetAttributeChangedSignal("MonedasMult"):Connect(refrescarTarjetas)
player:GetAttributeChangedSignal("Cansancio"):Connect(refrescarTarjetas)

-- ===== PESTAÑA ROBUX =====
-- Barra fija: stock de reanimaciones, tiempo restante de Piñas x2 y toggle de Modo Puro.
local barraEstado = Instance.new("Frame")
barraEstado.Name = "BarraEstado"
barraEstado.Size = UDim2.fromOffset(468, 46)
barraEstado.BackgroundColor3 = MARRON_TARJETA
barraEstado.BorderSizePixel = 0
barraEstado.Parent = paginaRobux
redondear(barraEstado, 10)

local stockLabel = Instance.new("TextLabel")
stockLabel.Size = UDim2.fromOffset(190, 18)
stockLabel.Position = UDim2.fromOffset(10, 4)
stockLabel.BackgroundTransparency = 1
stockLabel.Font = Enum.Font.GothamBold
stockLabel.TextSize = 14
stockLabel.Text = L("reanimaciones") .. ": 0"
stockLabel.TextColor3 = CREMA
stockLabel.TextXAlignment = Enum.TextXAlignment.Left
stockLabel.Parent = barraEstado

local x2Label = Instance.new("TextLabel")
x2Label.Size = UDim2.fromOffset(190, 18)
x2Label.Position = UDim2.fromOffset(10, 23)
x2Label.BackgroundTransparency = 1
x2Label.Font = Enum.Font.GothamBold
x2Label.TextSize = 14
x2Label.Text = L("pinas_x2") .. ": —"
x2Label.TextColor3 = AMARILLO
x2Label.TextXAlignment = Enum.TextXAlignment.Left
x2Label.Parent = barraEstado

local modoPuroBoton = Instance.new("TextButton")
modoPuroBoton.Name = "ModoPuro"
modoPuroBoton.AnchorPoint = Vector2.new(1, 0)
modoPuroBoton.Position = UDim2.new(1, -10, 0, 1)
modoPuroBoton.Size = UDim2.fromOffset(164, 44) -- objetivo táctil ≥44 (barra de 46)
modoPuroBoton.BackgroundColor3 = MADERA_OSCURA
modoPuroBoton.BorderSizePixel = 0
modoPuroBoton.Font = Enum.Font.GothamBlack
modoPuroBoton.TextSize = 14
modoPuroBoton.Text = L("modo_puro"):upper() .. ": " .. L("no")
modoPuroBoton.TextColor3 = CREMA
modoPuroBoton.Parent = barraEstado
redondear(modoPuroBoton, 8)

-- ScrollingFrame de 2 columnas con las tarjetas de MonetizacionConfig.Todos().
local scrollRobux = Instance.new("ScrollingFrame")
scrollRobux.Name = "CatalogoRobux"
scrollRobux.Position = UDim2.fromOffset(0, 52)
scrollRobux.Size = UDim2.fromOffset(468, 286)
scrollRobux.BackgroundTransparency = 1
scrollRobux.BorderSizePixel = 0
scrollRobux.ScrollBarThickness = 5
scrollRobux.ScrollBarImageColor3 = CREMA
scrollRobux.ScrollingDirection = Enum.ScrollingDirection.Y
scrollRobux.CanvasSize = UDim2.fromOffset(0, 0)
scrollRobux.Parent = paginaRobux

local rejilla = Instance.new("UIGridLayout")
rejilla.CellSize = UDim2.new(0.5, -8, 0, 108)
rejilla.CellPadding = UDim2.fromOffset(10, 10)
rejilla.SortOrder = Enum.SortOrder.LayoutOrder
rejilla.Parent = scrollRobux

local ultimaCompraRobux = 0

local function actualizarBotonRobux(registro)
	local item = registro.item
	local boton = registro.boton
	if registro.nombre then
		registro.nombre.Text = nombreItem(item)
	end
	local poseido = item.tipo == "pase"
		and type(estadoPases.pases) == "table"
		and estadoPases.pases[item.efecto] == true
	local idRobux = item.tipo == "pase" and item.paseId or item.productoId
	local publicable = MonetizacionConfig.Activo == true
		and type(idRobux) == "number"
		and idRobux > 0

	local texto, habilitado, activo
	if poseido then
		texto, habilitado, activo = L("activo"), false, true
	elseif item.disponible == false then
		texto, habilitado, activo = L("proximamente"), false, false
	elseif not publicable then
		texto, habilitado, activo = L("al_publicar"), false, false
	else
		texto, habilitado, activo = L("comprar"), true, false
	end

	boton.Text = texto
	boton.BackgroundColor3 = habilitado and VERDE or MADERA_OSCURA
	boton.TextColor3 = activo and AMARILLO or CREMA
	boton.TextTransparency = (habilitado or activo) and 0 or 0.35
	boton.Active = habilitado
	boton.Selectable = habilitado
	boton.AutoButtonColor = habilitado
	registro.habilitado = habilitado
end

local ALTO_TARJETA_ROBUX = 128 -- título a dos líneas con el texto al 140 %

local function crearTarjetaRobux(item, orden)
	local tarjeta = Instance.new("Frame")
	tarjeta.Name = "Robux_" .. item.id
	tarjeta.Size = UDim2.fromOffset(220, ALTO_TARJETA_ROBUX)
	tarjeta.LayoutOrder = orden
	tarjeta.BackgroundColor3 = MARRON_TARJETA
	tarjeta.BorderSizePixel = 0
	tarjeta.Parent = scrollRobux
	redondear(tarjeta, 10)

	local nombre = Instance.new("TextLabel")
	nombre.Size = UDim2.new(1, -20, 0, 52)
	nombre.Position = UDim2.fromOffset(10, 3)
	nombre.BackgroundTransparency = 1
	nombre.Font = Enum.Font.GothamBold
	nombre.TextSize = 16
	nombre.Text = nombreItem(item)
	nombre.TextColor3 = CREMA
	nombre.TextXAlignment = Enum.TextXAlignment.Left
	nombre.TextYAlignment = Enum.TextYAlignment.Top
	nombre.TextWrapped = true
	nombre.Parent = tarjeta

	local precio = Instance.new("TextLabel")
	precio.Size = UDim2.new(1, -20, 0, 18)
	precio.Position = UDim2.fromOffset(10, 56)
	precio.BackgroundTransparency = 1
	precio.Font = Enum.Font.GothamBold
	precio.TextSize = 18
	local precioRobux = tonumber(item.precioRobux) or 0
	if precioRobux > 0 then
		precio.Text = ("%d %s"):format(precioRobux, MonetizacionConfig.Moneda or "Robux")
	else
		precio.Text = "— " .. (MonetizacionConfig.Moneda or "Robux")
	end
	precio.TextColor3 = AMARILLO
	precio.TextXAlignment = Enum.TextXAlignment.Left
	precio.Parent = tarjeta

	local boton = Instance.new("TextButton")
	boton.Size = UDim2.new(1, -20, 0, 44)
	boton.Position = UDim2.fromOffset(10, 80)
	boton.BackgroundColor3 = MADERA_OSCURA
	boton.Font = Enum.Font.GothamBlack
	boton.TextSize = 17
	boton.Text = L("comprar")
	boton.TextColor3 = CREMA
	boton.Parent = tarjeta
	redondear(boton, 8)

	local registro = { item = item, nombre = nombre, boton = boton, habilitado = false }
	boton.Activated:Connect(function()
		if not registro.habilitado then
			return
		end
		if os.clock() - ultimaCompraRobux < 0.8 then
			return -- un prompt a la vez; el servidor revalida y limita
		end
		ultimaCompraRobux = os.clock()
		remoteComprarRobux:FireServer({ id = item.id })
	end)
	registrosRobux[item.id] = registro
	actualizarBotonRobux(registro)
end

local catalogoRobux = MonetizacionConfig.Todos()
for i, item in ipairs(catalogoRobux) do
	crearTarjetaRobux(item, i)
end
local filasRobux = math.ceil(#catalogoRobux / 2)
scrollRobux.CanvasSize = UDim2.fromOffset(0, filasRobux * ALTO_TARJETA_ROBUX + math.max(0, filasRobux - 1) * 10)

refrescarEstadoRobux = function()
	stockLabel.Text = L("reanimaciones") .. ": " .. ("%d"):format(estadoPases.reanimaciones)
	local restante = estadoPases.pinasX2Hasta - os.time()
	if restante > 0 then
		x2Label.Text = L("pinas_x2") .. ": " .. ("%d min"):format(math.ceil(restante / 60))
	else
		x2Label.Text = L("pinas_x2") .. ": —"
	end
	modoPuroBoton.Text = L("modo_puro"):upper() .. ": " .. (estadoPases.modoPuro and L("si") or L("no"))
	modoPuroBoton.BackgroundColor3 = estadoPases.modoPuro and AMARILLO or MADERA_OSCURA
	modoPuroBoton.TextColor3 = estadoPases.modoPuro and MADERA_OSCURA or CREMA
end
refrescarEstadoRobux()

-- El minuto restante de Piñas x2 caduca con el reloj: refresco perezoso cada 15 s.
task.spawn(function()
	while true do
		task.wait(15)
		if paginaRobux.Visible then
			refrescarEstadoRobux()
		end
	end
end)

local ultimoModoPuro = 0
modoPuroBoton.Activated:Connect(function()
	if os.clock() - ultimoModoPuro < 1 then
		return
	end
	ultimoModoPuro = os.clock()
	mostrarAviso(L("ranking_solo_puro"), AMARILLO)
	remoteModoPuro:FireServer(not estadoPases.modoPuro)
end)

pestanaPinas.Activated:Connect(function()
	local eraRobux = paginaRobux.Visible
	seleccionar("pinas")
	if eraRobux then
		anunciarEvento(TelemetriaConfig.Eventos.TiendaPestanaPinas)
	end
end)
pestanaRobux.Activated:Connect(function()
	local eraPinas = paginaPinas.Visible
	seleccionar("robux")
	if eraPinas then
		anunciarEvento(TelemetriaConfig.Eventos.TiendaPestanaRobux)
	end
end)
seleccionar("pinas")

-- Apertura (E46): vale el botón del menú y el ProximityPrompt del campamento;
-- se anuncia la pestaña visible para saber en qué página entra el jugador.
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then
		anunciarEvento(TelemetriaConfig.Eventos.TiendaAbierta)
		-- 0,3 s después: el servidor limita a un evento de UI cada 0,25 s y dos
		-- mensajes en el mismo frame perderían el segundo (la pestaña de entrada).
		task.delay(0.3, anunciarPestana)
	end
end)

-- ===== Volver (contrato con MenuInicio) =====
local volver = Instance.new("TextButton")
volver.Name = "Volver"
volver.Size = UDim2.fromOffset(240, 48)
volver.Position = UDim2.fromOffset(130, 452) -- 12 px bajo el borde inferior del panel
volver.BackgroundColor3 = VERDE
volver.Font = Enum.Font.GothamBlack
volver.TextSize = 22
volver.Text = L("volver"):upper()
volver.TextColor3 = CREMA
volver.Parent = panel
redondear(volver, 12)

volver.Activated:Connect(function()
	gui.Enabled = false
	local lobby = player.PlayerGui:FindFirstChild("LobbyUI")
	local enSala = lobby and lobby:IsA("ScreenGui") and lobby.Enabled
	if not enSala and player:GetAttribute("EnJuego") ~= true then
		local inicio = player.PlayerGui:FindFirstChild("MenuInicio")
		if inicio then
			inicio.Enabled = true
		end
	end
end)

-- Apertura desde el mundo: StageService coloca un ProximityPrompt "TiendaInicio"
-- en el puesto del campamento. Es la misma gui que abre el menú; si MenuInicio
-- estaba delante se aparta y VOLVER lo re-muestra (salvo con la sala LobbyUI
-- abierta, que sigue debajo y no se toca para no desincronizar su fase).
ProximityPromptService.PromptTriggered:Connect(function(prompt, jugador)
	if jugador ~= player or prompt.Name ~= "TiendaInicio" then
		return
	end
	gui.Enabled = true
	local inicio = player.PlayerGui:FindFirstChild("MenuInicio")
	if inicio then
		inicio.Enabled = false
	end
end)

-- ===== Remotes =====
remotePinas.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	saldo.Text = L("pinas") .. ": " .. ("%d"):format(datos.pinas or 0)
	pinasActuales = datos.pinas or 0
	if veloCompra.Visible then
		dialogoSaldo.Text = L("pinas") .. ": " .. ("%d"):format(pinasActuales)
	end
	refrescarTarjetas() -- el saldo decide qué COMPRAR sigue habilitado
end)

remoteResultado.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	if datos.ok == true then
		-- Compra (o re-uso «Equipado») aceptada: cosmético a EQUIPAR y saldo del
		-- payload. Bebidas y mejoras se repintan desde los atributos del servidor.
		if registroPendiente then
			local item = registroPendiente.item
			if item.tipo ~= "bebida" and item.tipo ~= "mejora" then
				marcarComprado(registroPendiente)
			end
			registroPendiente = nil
		end
		if type(datos.pinas) == "number" then
			pinasActuales = datos.pinas
			saldo.Text = L("pinas") .. ": " .. ("%d"):format(datos.pinas)
		end
		if type(datos.clave) == "string" and datos.clave ~= "" then
			mostrarAviso(L(datos.clave, datos.params), AMARILLO)
		end
		-- Los atributos replican por su propio canal: repintar al final del frame
		-- evita enseñar el stock/nivel anterior unos milisegundos.
		task.defer(refrescarTarjetas)
	else
		local texto = type(datos.clave) == "string" and L(datos.clave, datos.params) or L("pinas_insuficientes")
		mostrarAviso(texto)
		registroPendiente = nil
		refrescarTarjetas()
	end
end)

remoteRobuxResultado.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	local mensaje = type(datos.clave) == "string" and L(datos.clave, datos.params)
		or (datos.ok == true and L("compra_iniciada") or L("compra_no_disponible"))
	mostrarAviso(mensaje, datos.ok == true and AMARILLO or ROJO_AVISO)
end)

remotePaseEstado.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	estadoPases.pases = type(datos.pases) == "table" and datos.pases or {}
	estadoPases.reanimaciones = math.max(0, math.floor(tonumber(datos.reanimaciones) or 0))
	estadoPases.pinasX2Hasta = tonumber(datos.pinasX2Hasta) or 0
	estadoPases.modoPuro = datos.modoPuro == true
	estadoPases.activo = datos.activo == true
	for _, registro in pairs(registrosRobux) do
		actualizarBotonRobux(registro)
	end
	refrescarTarjetas()
	refrescarEstadoRobux()
end)

-- Tras el prompt, el cliente solo avisa; el servidor vuelve a comprobar la posesión.
local pasesPorRobux = {}
for _, item in ipairs(MonetizacionConfig.Pases) do
	local paseId = tonumber(item.paseId)
	if item.tipo == "pase" and paseId and paseId > 0 then
		pasesPorRobux[paseId] = item
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(jugador, paseId, comprado)
	if jugador ~= player or comprado ~= true then
		return
	end
	local item = pasesPorRobux[paseId]
	if not item then
		return
	end
	remoteReclamarPase:FireServer(item.id)
	mostrarAviso(L("comprobando_pase"), AMARILLO)
end)

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	titulo.Text = L("tienda"):upper()
	pestanaPinas.Text = L("pinas_tab")
	pestanaRobux.Text = L("robux")
	volver.Text = L("volver"):upper()
	saldo.Text = L("pinas") .. ": " .. ("%d"):format(pinasActuales)
	refrescarTarjetas()
	for _, registro in pairs(registrosRobux) do
		actualizarBotonRobux(registro)
	end
	refrescarEstadoRobux()
end)

print("[TiendaUI] activa")
