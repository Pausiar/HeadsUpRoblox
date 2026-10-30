-- Pantalla de personalización (plan §6): pestañas CUERPO y ROPA.
-- CUERPO conserva la vista previa en vivo al SOLTAR el slider. ROPA es el editor plan B (decisión D7,
-- sin EditableImage): todos los cambios son locales hasta pulsar GUARDAR; al abrir la pestaña se
-- pide el estado al servidor (PedirRopa) y la vista previa 2D reutiliza RopaArte.
-- Contrato con MenuInicio: su PERSONALIZAR habilita esta gui; nuestro VOLVER re-muestra MenuInicio si no estamos en juego.
-- Reutiliza paleta, patrón de slider de MenuAjustes y helpers de GUI de LobbyUI; ADN en docs/design/design-dna.md
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RopaConfig = require(ReplicatedStorage.Shared.Config.RopaConfig)
local RopaArte = require(ReplicatedStorage.Shared.RopaArte)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local MenuCamara = require(script.Parent:WaitForChild("MenuCamara"))

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local personalizacion = Config.Etapa0.Personalizacion
local player = Players.LocalPlayer

-- Remotes resueltos una vez y ANTES de construir la UI: Esperar puede rendir.
local remotePersonalizacion = Remotes.Esperar(Remotes.Nombres.Personalizacion)
local remoteTusDatos = Remotes.Esperar(Remotes.Nombres.TusDatos)
local remotePedirRopa = Remotes.Esperar(Remotes.Nombres.PedirRopa)
local remoteRopaEstado = Remotes.Esperar(Remotes.Nombres.RopaEstado)
local remoteGuardarRopa = Remotes.Esperar(Remotes.Nombres.GuardarRopa)
local remoteRopaResult = Remotes.Esperar(Remotes.Nombres.RopaResult)

-- Paleta del ADN
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local MARRON = Color3.fromRGB(107, 74, 43) -- #6B4A2B
local MARRON_OSCURO = Color3.fromRGB(62, 42, 24) -- #3E2A18
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A
local VERDE_CLARO = Color3.fromRGB(139, 195, 74) -- #8BC34A (texto positivo legible sobre madera)
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C
local ROJO_ACLARADO = Color3.fromRGB(255, 160, 143) -- #FFA08F (error legible sobre madera)

local gui = Instance.new("ScreenGui")
gui.Name = "Personalizacion"
gui.Enabled = false
gui.DisplayOrder = 55
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
MenuCamara.Vincular(gui)

-- Safe area: inset superior-izquierdo para no quedar bajo la notch en móviles (patrón HudRanking).
local inset = GuiService:GetGuiInset()
local safeArea = Instance.new("UIPadding")
safeArea.PaddingTop = UDim.new(0, inset.Y)
safeArea.PaddingLeft = UDim.new(0, inset.X)
safeArea.Parent = gui

-- El panel nominal es 560x600; en pantallas estrechas se escala el conjunto y, si aun así
-- no cabe (móvil apaisado), el marco lo desplaza en vertical: guardar/volver siempre quedan
-- al alcance del dedo. El scroll es solo Y para no robar el arrastre horizontal de los sliders.
-- El suelo 0,9 mantiene los botones de 44 px en ~40 px.
local marco = Instance.new("ScrollingFrame")
marco.Name = "MarcoScroll"
marco.AnchorPoint = Vector2.new(0.5, 0.5)
marco.Position = UDim2.fromScale(0.5, 0.5)
marco.BackgroundTransparency = 1
marco.BorderSizePixel = 0
marco.ScrollBarThickness = 4
marco.ScrollBarImageColor3 = CREMA
marco.ScrollingDirection = Enum.ScrollingDirection.Y
marco.CanvasSize = UDim2.fromOffset(0, 0)
marco.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(0, 0)
panel.Size = UDim2.fromOffset(560, 600)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = marco

local esquinaPanel = Instance.new("UICorner")
esquinaPanel.CornerRadius = UDim.new(0, 16)
esquinaPanel.Parent = panel

local escala = Instance.new("UIScale")
escala.Parent = panel
local function ajustarEscala()
	-- safeArea solo añade inset superior e izquierdo, así que el área útil es la del gui menos eso.
	local ancho = gui.AbsoluteSize.X - inset.X
	local alto = gui.AbsoluteSize.Y - inset.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	escala.Scale = math.clamp(math.min(ancho / 600, alto / 640), 0.9, 1)
	local anchoPanel = 560 * escala.Scale
	local altoPanel = 600 * escala.Scale
	marco.CanvasSize = UDim2.fromOffset(anchoPanel, altoPanel)
	marco.Size = UDim2.fromOffset(math.min(ancho, anchoPanel), math.min(alto, altoPanel))
	marco.ScrollingEnabled = altoPanel > alto
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio)
	esquina.Parent = objeto
	return esquina
end

local function etiqueta(padre, posicion, tamano, texto, tamanoTexto, color, fuente, alineacion)
	local t = Instance.new("TextLabel")
	t.Position = posicion
	t.Size = tamano
	t.BackgroundTransparency = 1
	t.Font = fuente or Enum.Font.GothamBold
	t.Text = texto or ""
	t.TextSize = tamanoTexto
	t.TextColor3 = color
	t.TextXAlignment = alineacion or Enum.TextXAlignment.Center
	t.Parent = padre
	return t
end

local function boton(padre, posicion, tamano, texto, tamanoTexto, colorFondo, colorTexto)
	local b = Instance.new("TextButton")
	b.Position = posicion
	b.Size = tamano
	b.BackgroundColor3 = colorFondo
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.Text = texto
	b.TextSize = tamanoTexto
	b.TextColor3 = colorTexto
	b.Parent = padre
	redondear(b, 10)
	return b
end

local function pintarSeleccion(b, activo)
	b.BackgroundColor3 = activo and AMARILLO or MARRON
	b.TextColor3 = activo and MARRON_OSCURO or CREMA
end

-- Guarda las etiquetas con su clave para reaplicar el idioma sin reconstruir la UI.
local textosTraducibles = {}
local function registrarTexto(objeto, clave, mayusculas)
	table.insert(textosTraducibles, { objeto = objeto, clave = clave, mayusculas = mayusculas == true })
	return objeto
end

local function etiquetaClave(padre, posicion, tamano, clave, tamanoTexto, color, fuente, alineacion)
	return registrarTexto(
		etiqueta(padre, posicion, tamano, L(clave), tamanoTexto, color, fuente, alineacion),
		clave
	)
end

registrarTexto(etiqueta(
	panel,
	UDim2.fromOffset(0, 4),
	UDim2.new(1, 0, 0, 36),
	L("personalizacion"),
	28,
	CREMA,
	Enum.Font.GothamBlack
), "personalizacion")

-- Pestañas: 160 de ancho y 42 de alto (objetivo táctil ≥40); activa en amarillo con texto oscuro.
local pestanaCuerpo = boton(
	panel,
	UDim2.fromOffset(114, 44),
	UDim2.fromOffset(160, 42),
	L("cuerpo"):upper(),
	20,
	AMARILLO,
	MARRON_OSCURO
)
registrarTexto(pestanaCuerpo, "cuerpo", true)
pestanaCuerpo.Name = "PestanaCuerpo"
pestanaCuerpo.ZIndex = 2 -- por encima de los grupos de contenido, que cubren todo el panel
local pestanaRopa = boton(
	panel,
	UDim2.fromOffset(286, 44),
	UDim2.fromOffset(160, 42),
	L("ropa"):upper(),
	20,
	MARRON,
	CREMA
)
registrarTexto(pestanaRopa, "ropa", true)
pestanaRopa.Name = "PestanaRopa"
pestanaRopa.ZIndex = 2
pintarSeleccion(pestanaCuerpo, true)
pintarSeleccion(pestanaRopa, false)

-- Hueco compartido de feedback: GUARDADO (1,2 s) o error del servidor (2 s), en ambas pestañas.
local aviso = etiqueta(
	panel,
	UDim2.fromOffset(24, 90),
	UDim2.new(1, -48, 0, 20),
	"",
	17,
	CREMA,
	Enum.Font.GothamBold
)
aviso.Name = "Aviso"
aviso.TextTruncate = Enum.TextTruncate.AtEnd

local tareaAviso = nil
local function limpiarAviso()
	if tareaAviso then
		task.cancel(tareaAviso)
		tareaAviso = nil
	end
	aviso.Text = ""
end

local function mostrarAviso(texto, color, duracion)
	limpiarAviso()
	aviso.Text = texto
	aviso.TextColor3 = color
	if duracion then
		tareaAviso = task.delay(duracion, function()
			aviso.Text = ""
			tareaAviso = nil
		end)
	end
end

-- Grupos de pestaña: se muestran/ocultan, nunca se destruyen.
local grupoCuerpo = Instance.new("Frame")
grupoCuerpo.Name = "GrupoCuerpo"
grupoCuerpo.Size = UDim2.fromScale(1, 1)
grupoCuerpo.BackgroundTransparency = 1
grupoCuerpo.Parent = panel

local grupoRopa = Instance.new("Frame")
grupoRopa.Name = "GrupoRopa"
grupoRopa.Size = UDim2.fromScale(1, 1)
grupoRopa.BackgroundTransparency = 1
grupoRopa.Visible = false
grupoRopa.Parent = panel

-- ===== CUERPO =====
-- Los valores iniciales son el default 1.0; si el jugador tiene escalas guardadas, el
-- servidor las publica por TusDatos al terminar de cargar el DataStore y se aplican aquí.
local estado = { altura = 1, ancho = 1, cabeza = 1 }

-- Escalas guardadas (TusDatos: server->client, payload = tabla guardada, puede venir {}).
-- Orden anti-carrera: se conecta ANTES de crear los sliders; si el remote llega primero
-- queda en `pendiente` y se vuelca justo tras crearlos; si llega después, se aplica al momento.
local pendiente = nil
local aplicarEscalasGuardadas = nil -- se define tras crear los sliders (necesita sus refrescar)
remoteTusDatos.OnClientEvent:Connect(function(datos)
	local escalas = typeof(datos) == "table" and datos.escalas
	if typeof(escalas) ~= "table" then
		return
	end
	local a, n, c = escalas.altura, escalas.ancho, escalas.cabeza
	if typeof(a) ~= "number" or typeof(n) ~= "number" or typeof(c) ~= "number" then
		return
	end
	-- Clamp por si acaso: el servidor ya valida, pero no confiamos en la red (plan §3.3).
	pendiente = {
		altura = math.clamp(a, personalizacion.AlturaMin, personalizacion.AlturaMax),
		ancho = math.clamp(n, personalizacion.AnchoMin, personalizacion.AnchoMax),
		cabeza = math.clamp(c, personalizacion.CabezaMin, personalizacion.CabezaMax),
	}
	if aplicarEscalasGuardadas then
		aplicarEscalasGuardadas()
	end
end)

-- Anti-spam del remote: los sliders envían solo al SOLTAR (máx. 1 envío por arrastre);
-- los botones comparten además un enfriamiento de 0,3 s y el valor pendiente se reenvía
-- coalescido al vencer (así GUARDAR garantiza que el último estado llegue).
local ENFRIAMIENTO_ENVIO = 0.3
local ultimoEnvio = 0
local envioPendiente = false

local function enviarYa()
	ultimoEnvio = os.clock()
	envioPendiente = false
	remotePersonalizacion:FireServer({ altura = estado.altura, ancho = estado.ancho, cabeza = estado.cabeza })
end

local function enviar()
	local restante = ENFRIAMIENTO_ENVIO - (os.clock() - ultimoEnvio)
	if restante <= 0 then
		enviarYa()
	elseif not envioPendiente then
		envioPendiente = true
		task.delay(restante, enviarYa)
	end
end

-- Etiqueta de fila del cuerpo: título a la izquierda, valor del slider alineado a la derecha.
local function etiquetaFila(y, clave)
	return etiquetaClave(
		grupoCuerpo,
		UDim2.fromOffset(64, y),
		UDim2.fromOffset(336, 24),
		clave,
		20,
		CREMA,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Left
	)
end

-- Slider real: pista 432x8 + knob circular arrastrable (patrón EXACTO de MenuAjustes).
-- Adaptado: valores flotantes con 2 decimales, sin símbolo % (los rangos no empiezan en 0),
-- escribe en `estado` y devuelve su refrescar para el botón ALEATORIO.
local function crearSlider(yFila, claveTexto, clave, minimo, maximo)
	etiquetaFila(yFila, claveTexto)

	local pista = Instance.new("Frame")
	pista.Size = UDim2.fromOffset(432, 8)
	pista.Position = UDim2.fromOffset(64, yFila + 42)
	pista.BackgroundColor3 = CREMA
	pista.BackgroundTransparency = 0.3
	pista.BorderSizePixel = 0
	pista.Parent = grupoCuerpo
	redondear(pista, 4)

	local valor = etiqueta(
		grupoCuerpo,
		UDim2.fromOffset(400, yFila),
		UDim2.fromOffset(96, 24),
		"",
		20,
		CREMA,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)

	local agarre = Instance.new("TextButton")
	agarre.Name = "Agarre"
	agarre.Size = UDim2.fromOffset(44, 44) -- objetivo táctil cómodo alrededor del knob
	agarre.BackgroundTransparency = 1
	agarre.Text = ""
	agarre.AutoButtonColor = false
	agarre.Parent = pista

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(22, 22)
	knob.Position = UDim2.new(0.5, -11, 0.5, -11)
	knob.BackgroundColor3 = AMARILLO
	knob.BorderSizePixel = 0
	knob.Parent = agarre
	redondear(knob, 11) -- círculo

	local function refrescar()
		local v = estado[clave]
		local alpha = (v - minimo) / (maximo - minimo)
		agarre.Position = UDim2.new(alpha, -22, 0.5, -22)
		valor.Text = ("%.2f"):format(v)
	end

	local function valorDe(xPantalla)
		local alpha = (xPantalla - pista.AbsolutePosition.X) / math.max(pista.AbsoluteSize.X, 1)
		alpha = math.clamp(alpha, 0, 1)
		return math.floor((minimo + alpha * (maximo - minimo)) * 100 + 0.5) / 100
	end

	local arrastrando = false
	local function iniciar(input)
		local tipo = input.UserInputType
		if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch then
			arrastrando = true
			estado[clave] = valorDe(input.Position.X)
			refrescar()
		end
	end

	agarre.InputBegan:Connect(iniciar)
	pista.InputBegan:Connect(iniciar) -- tocar la pista salta el knob (táctil)
	UserInputService.InputChanged:Connect(function(input)
		local tipo = input.UserInputType
		if arrastrando and (tipo == Enum.UserInputType.MouseMovement or tipo == Enum.UserInputType.Touch) then
			estado[clave] = valorDe(input.Position.X)
			refrescar()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local tipo = input.UserInputType
		if arrastrando and (tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch) then
			arrastrando = false
			enviar() -- vista previa en vivo: solo al soltar
		end
	end)

	refrescar()
	return refrescar
end

-- Grupo centrado en la franja de contenido: las filas van de 170 a 472 (centro 321 del panel).
local refrescarAltura = crearSlider(170, "altura", "altura", personalizacion.AlturaMin, personalizacion.AlturaMax)
local refrescarAncho = crearSlider(258, "ancho", "ancho", personalizacion.AnchoMin, personalizacion.AnchoMax)
local refrescarCabeza = crearSlider(346, "cabeza", "cabeza", personalizacion.CabezaMin, personalizacion.CabezaMax)

-- Con los sliders ya creados, define cómo aplicar las escalas recibidas y vuelca
-- las pendientes si TusDatos llegó antes de crearlos (solo refresca la UI: no reenvía).
aplicarEscalasGuardadas = function()
	if not pendiente then
		return
	end
	estado.altura = pendiente.altura
	estado.ancho = pendiente.ancho
	estado.cabeza = pendiente.cabeza
	pendiente = nil
	refrescarAltura()
	refrescarAncho()
	refrescarCabeza()
end
aplicarEscalasGuardadas()

local aleatorio = boton(
	grupoCuerpo,
	UDim2.fromOffset(160, 428),
	UDim2.fromOffset(240, 44),
	L("aleatorio"):upper(),
	20,
	MARRON,
	CREMA
)
registrarTexto(aleatorio, "aleatorio", true)
aleatorio.Name = "Aleatorio"

local function valorAleatorio(minimo, maximo)
	return math.floor((minimo + math.random() * (maximo - minimo)) * 100 + 0.5) / 100
end

aleatorio.Activated:Connect(function()
	estado.altura = valorAleatorio(personalizacion.AlturaMin, personalizacion.AlturaMax)
	estado.ancho = valorAleatorio(personalizacion.AnchoMin, personalizacion.AnchoMax)
	estado.cabeza = valorAleatorio(personalizacion.CabezaMin, personalizacion.CabezaMax)
	refrescarAltura()
	refrescarAncho()
	refrescarCabeza()
	enviar()
end)

-- ===== ROPA =====
-- El editor trabaja con ids de RopaConfig; RopaConfig.PorDefecto guarda rgb y no es válido
-- como payload (el servidor revalida ids). Este es el default del contrato.
local DISENO_POR_DEFECTO = {
	patron = "lisa",
	color1 = "verde",
	color2 = "crema",
	pegatina = "ninguna",
}

local function copiarDiseno(diseno)
	if type(diseno) ~= "table" then
		diseno = DISENO_POR_DEFECTO
	end
	return {
		patron = diseno.patron,
		color1 = diseno.color1,
		color2 = diseno.color2,
		pegatina = diseno.pegatina,
	}
end

-- Normaliza lo que venga del servidor: ids desconocidos caen al default, nunca a rgb.
local function disenoNormalizado(diseno)
	if type(diseno) ~= "table" then
		return copiarDiseno(DISENO_POR_DEFECTO)
	end
	return {
		patron = RopaConfig.PatronPorId(diseno.patron) and diseno.patron or DISENO_POR_DEFECTO.patron,
		color1 = RopaConfig.ColorPorId(diseno.color1) and diseno.color1 or DISENO_POR_DEFECTO.color1,
		color2 = RopaConfig.ColorPorId(diseno.color2) and diseno.color2 or DISENO_POR_DEFECTO.color2,
		pegatina = RopaConfig.PegatinaPorId(diseno.pegatina) and diseno.pegatina or DISENO_POR_DEFECTO.pegatina,
	}
end

local function mismoDiseno(a, b)
	return a.patron == b.patron
		and a.color1 == b.color1
		and a.color2 == b.color2
		and a.pegatina == b.pegatina
end

local estadoRopa = {
	ranura = 1,
	ranuras = RopaConfig.RanurasGratis,
	disenos = {}, -- [ranura] = diseño guardado (ids)
	borradores = {}, -- [ranura] = edición local sin guardar (no se pierde al cambiar de ranura)
	diseno = copiarDiseno(DISENO_POR_DEFECTO), -- diseño en edición
	modificado = false, -- hay cambios locales sin guardar
	cargada = false, -- ya llegó el primer RopaEstado
}

local renderRopa = nil -- se define al final de la sección, cuando ya existen todos los controles
local seleccionarRanura = nil

-- Vista previa 2D: mismo dibujo que el servidor pinta en el torso (RopaArte).
local vistaPrevia = Instance.new("Frame")
vistaPrevia.Name = "VistaPreviaRopa"
vistaPrevia.Position = UDim2.fromOffset(24, 116)
vistaPrevia.Size = UDim2.fromOffset(150, 190)
vistaPrevia.BackgroundColor3 = MARRON
vistaPrevia.BorderSizePixel = 0
vistaPrevia.ClipsDescendants = true
vistaPrevia.Parent = grupoRopa
redondear(vistaPrevia, 12)

local lienzoRopa = nil
local function redibujarRopa()
	if lienzoRopa then
		lienzoRopa:Destroy() -- contrato RopaArte: destruir el lienzo anterior antes de redibujar
	end
	lienzoRopa = RopaArte.Dibujar(vistaPrevia, estadoRopa.diseno)
	redondear(lienzoRopa, 12)
end

-- Ranura activa arriba del selector (no solo color: el texto dice qué ranura se edita).
local ranuraTitulo = etiqueta(
	grupoRopa,
	UDim2.fromOffset(194, 116),
	UDim2.fromOffset(342, 20),
	L("ranura"):upper() .. " 1",
	18,
	AMARILLO,
	Enum.Font.GothamBlack,
	Enum.TextXAlignment.Left
)

local botonesRanura = {}
for i = 1, RopaConfig.RanurasMax do
	local fila = math.floor((i - 1) / 5)
	local columna = (i - 1) % 5
	local b = boton(
		grupoRopa,
		UDim2.fromOffset(194 + columna * 64, 140 + fila * 48),
		UDim2.fromOffset(56, 44),
		tostring(i),
		20,
		MARRON,
		CREMA
	)
	b.Name = "Ranura" .. i
	b.Visible = false
	b.Activated:Connect(function()
		seleccionarRanura(i)
	end)
	botonesRanura[i] = b
end

local notaRanuras = etiqueta(
	grupoRopa,
	UDim2.fromOffset(194, 188),
	UDim2.fromOffset(342, 18),
	"",
	16,
	CREMA,
	Enum.Font.Gotham,
	Enum.TextXAlignment.Left
)
notaRanuras.Name = "NotaRanuras"
notaRanuras.TextTruncate = Enum.TextTruncate.AtEnd

etiquetaClave(
	grupoRopa,
	UDim2.fromOffset(34, 388),
	UDim2.fromOffset(240, 20),
	"patron",
	17,
	CREMA,
	Enum.Font.GothamBlack,
	Enum.TextXAlignment.Left
)

local botonesPatron = {}
for i, item in ipairs(RopaConfig.Patrones) do
	local b = boton(
		grupoRopa,
		UDim2.fromOffset(34 + (i - 1) * 100, 410),
		UDim2.fromOffset(92, 44),
		item.nombre,
		18,
		MARRON,
		CREMA
	)
	b.Name = "Patron" .. item.id
	b.Activated:Connect(function()
		if estadoRopa.diseno.patron ~= item.id then
			estadoRopa.diseno.patron = item.id
			estadoRopa.modificado = true
			renderRopa()
		end
	end)
	botonesPatron[i] = { id = item.id, boton = b }
end

-- Muestras de 36x36 dentro de una zona táctil de 44x44 (sin huecos: 8 colores ocupan 352 px).
local function crearFilaColor(clave, y)
	local botones = {}
	for i, color in ipairs(RopaConfig.Colores) do
		local b = Instance.new("TextButton")
		b.Name = ("Color_%s_%d"):format(clave, i)
		b.Size = UDim2.fromOffset(44, 44)
		b.Position = UDim2.fromOffset(186 + (i - 1) * 44, y)
		b.BackgroundTransparency = 1
		b.BorderSizePixel = 0
		b.Text = ""
		b.Parent = grupoRopa

		local muestra = Instance.new("Frame")
		muestra.Name = "Muestra"
		muestra.Size = UDim2.fromOffset(36, 36)
		muestra.Position = UDim2.fromOffset(4, 4)
		muestra.BackgroundColor3 = Color3.fromRGB(color.rgb[1], color.rgb[2], color.rgb[3])
		muestra.BorderSizePixel = 0
		muestra.Parent = b
		redondear(muestra, 18)

		local trazo = Instance.new("UIStroke")
		trazo.Color = CREMA
		trazo.Thickness = 0
		trazo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		trazo.Parent = muestra

		b.Activated:Connect(function()
			if estadoRopa.diseno[clave] ~= color.id then
				estadoRopa.diseno[clave] = color.id
				estadoRopa.modificado = true
				renderRopa()
			end
		end)
		botones[i] = { id = color.id, trazo = trazo }
	end
	return botones
end

local botonesColor1 = crearFilaColor("color1", 252)
local color1Nombre = etiqueta(
	grupoRopa,
	UDim2.fromOffset(186, 296),
	UDim2.fromOffset(350, 18),
	"",
	17,
	CREMA,
	Enum.Font.GothamBold,
	Enum.TextXAlignment.Left
)
local botonesColor2 = crearFilaColor("color2", 320)
local color2Nombre = etiqueta(
	grupoRopa,
	UDim2.fromOffset(186, 364),
	UDim2.fromOffset(350, 18),
	"",
	17,
	CREMA,
	Enum.Font.GothamBold,
	Enum.TextXAlignment.Left
)

etiquetaClave(
	grupoRopa,
	UDim2.fromOffset(34, 458),
	UDim2.fromOffset(240, 20),
	"pegatina",
	17,
	CREMA,
	Enum.Font.GothamBlack,
	Enum.TextXAlignment.Left
)

local botonesPegatina = {}
for i, item in ipairs(RopaConfig.Pegatinas) do
	local b = boton(
		grupoRopa,
		UDim2.fromOffset(34 + (i - 1) * 100, 480),
		UDim2.fromOffset(92, 44),
		item.nombre,
		18,
		MARRON,
		CREMA
	)
	b.Name = "Pegatina" .. item.id
	b.Activated:Connect(function()
		if estadoRopa.diseno.pegatina ~= item.id then
			estadoRopa.diseno.pegatina = item.id
			estadoRopa.modificado = true
			renderRopa()
		end
	end)
	botonesPegatina[i] = { id = item.id, boton = b }
end

-- Pinta todo el editor ROPA desde estadoRopa y redibuja la vista previa. No envía remotes.
renderRopa = function()
	local filas = math.ceil(estadoRopa.ranuras / 5)
	ranuraTitulo.Text = L("ranura"):upper() .. " " .. ("%d"):format(estadoRopa.ranura)

	for i, b in ipairs(botonesRanura) do
		local visible = i <= estadoRopa.ranuras
		b.Visible = visible
		if visible then
			pintarSeleccion(b, i == estadoRopa.ranura)
		end
	end

	notaRanuras.Position = UDim2.fromOffset(194, 140 + filas * 48 + 4)
	local cabecera = ("%d "):format(estadoRopa.ranuras)
		.. L("de")
		.. " "
		.. ("%d "):format(RopaConfig.RanurasMax)
	if estadoRopa.ranuras >= RopaConfig.RanurasMax then
		notaRanuras.Text = cabecera .. L("ranuras_todas")
	else
		notaRanuras.Text = cabecera .. L("ranuras_extra")
	end

	for _, item in ipairs(botonesPatron) do
		pintarSeleccion(item.boton, estadoRopa.diseno.patron == item.id)
	end
	for _, item in ipairs(botonesColor1) do
		item.trazo.Thickness = estadoRopa.diseno.color1 == item.id and 2 or 0
	end
	for _, item in ipairs(botonesColor2) do
		item.trazo.Thickness = estadoRopa.diseno.color2 == item.id and 2 or 0
	end
	for _, item in ipairs(botonesPegatina) do
		pintarSeleccion(item.boton, estadoRopa.diseno.pegatina == item.id)
	end

	local color1 = RopaConfig.ColorPorId(estadoRopa.diseno.color1)
	local color2 = RopaConfig.ColorPorId(estadoRopa.diseno.color2)
	color1Nombre.Text = L("color_1") .. ": " .. (color1 and color1.nombre or "—")
	color2Nombre.Text = L("color_2") .. ": " .. (color2 and color2.nombre or "—")

	redibujarRopa()
end

-- Cambiar de ranura no envía nada: carga el diseño guardado de esa ranura o el default.
seleccionarRanura = function(ranura)
	ranura = math.floor(ranura)
	if ranura < 1 or ranura > estadoRopa.ranuras or ranura == estadoRopa.ranura then
		return
	end
	-- Cambiar de ranura no descarta lo editado sin guardar: se queda como borrador local.
	if estadoRopa.modificado then
		estadoRopa.borradores[estadoRopa.ranura] = copiarDiseno(estadoRopa.diseno)
	end
	estadoRopa.ranura = ranura
	estadoRopa.diseno = disenoNormalizado(estadoRopa.borradores[ranura] or estadoRopa.disenos[ranura])
	estadoRopa.modificado = estadoRopa.borradores[ranura] ~= nil
	renderRopa()
end

-- RopaEstado: única fuente de ranuras/diseños guardados. `activa` solo decide la ranura
-- en la primera carga; después se respeta la selección del jugador.
local function aplicarRopaEstado(datos)
	if type(datos) ~= "table" then
		return
	end

	local ranuras = tonumber(datos.ranurasDesbloqueadas)
	if ranuras then
		ranuras = math.clamp(math.floor(ranuras), 1, RopaConfig.RanurasMax)
	else
		ranuras = RopaConfig.RanurasGratis
	end
	estadoRopa.ranuras = ranuras

	local disenos = type(datos.disenos) == "table" and datos.disenos or {}
	local limpios = {}
	for i = 1, ranuras do
		local guardado = disenos[i] or disenos[tostring(i)] -- DataStore puede devolver claves string
		if type(guardado) == "table" then
			limpios[i] = disenoNormalizado(guardado)
		end
	end
	estadoRopa.disenos = limpios

	local primeraCarga = not estadoRopa.cargada
	if primeraCarga then
		local activa = tonumber(datos.activa)
		if activa and activa == math.floor(activa) and activa >= 1 and activa <= ranuras then
			estadoRopa.ranura = activa
		else
			estadoRopa.ranura = math.clamp(estadoRopa.ranura, 1, ranuras)
		end
		estadoRopa.cargada = true
	else
		estadoRopa.ranura = math.clamp(estadoRopa.ranura, 1, ranuras)
	end

	-- Si el jugador ya tocó opciones sin guardar, RopaEstado no pisa su edición (ni en la primera carga).
	if not estadoRopa.modificado then
		estadoRopa.diseno = disenoNormalizado(limpios[estadoRopa.ranura])
		estadoRopa.modificado = false
	end

	renderRopa()
end

remoteRopaEstado.OnClientEvent:Connect(aplicarRopaEstado)

-- ===== Controles compartidos =====
local pestanaActual = "cuerpo"
local function cambiarPestana(nueva)
	if nueva == pestanaActual then
		return
	end
	pestanaActual = nueva
	local esCuerpo = nueva == "cuerpo"
	grupoCuerpo.Visible = esCuerpo
	grupoRopa.Visible = not esCuerpo
	pintarSeleccion(pestanaCuerpo, esCuerpo)
	pintarSeleccion(pestanaRopa, not esCuerpo)
	limpiarAviso()
	if nueva == "ropa" then
		remotePedirRopa:FireServer() -- estado fresco al abrir la pestaña
	end
end

pestanaCuerpo.Activated:Connect(function()
	cambiarPestana("cuerpo")
end)
pestanaRopa.Activated:Connect(function()
	cambiarPestana("ropa")
end)

-- ROPA solo envía GuardarRopa al pulsar GUARDAR; las opciones y la ranura son locales.
local envioRopa = nil
local proximoGuardadoRopa = 0

local guardar = boton(
	panel,
	UDim2.fromOffset(24, 532),
	UDim2.fromOffset(240, 52),
	L("guardar"):upper(),
	22,
	VERDE,
	CREMA
)
registrarTexto(guardar, "guardar", true)
guardar.Name = "Guardar"

guardar.Activated:Connect(function()
	if pestanaActual == "cuerpo" then
		enviar() -- reenvía por si soltó el ratón/dedo fuera de la pista
		mostrarAviso(L("guardado"), VERDE_CLARO, 1.2)
		return
	end

	if not estadoRopa.cargada then
		mostrarAviso(L("cargando_ropa"), CREMA, 1.5)
		remotePedirRopa:FireServer()
		return
	end

	local ahora = os.clock()
	if ahora < proximoGuardadoRopa then
		return
	end
	proximoGuardadoRopa = ahora + RopaConfig.Enfriamiento

	envioRopa = {
		ranura = estadoRopa.ranura,
		diseno = copiarDiseno(estadoRopa.diseno),
	}
	limpiarAviso()
	remoteGuardarRopa:FireServer({
		ranura = envioRopa.ranura,
		patron = envioRopa.diseno.patron,
		color1 = envioRopa.diseno.color1,
		color2 = envioRopa.diseno.color2,
		pegatina = envioRopa.diseno.pegatina,
	})
end)

local volver = boton(
	panel,
	UDim2.fromOffset(296, 536),
	UDim2.fromOffset(240, 44),
	L("volver"):upper(),
	20,
	MARRON,
	CREMA
)
registrarTexto(volver, "volver", true)
volver.Name = "Volver"

volver.Activated:Connect(function()
	gui.Enabled = false
	if player:GetAttribute("EnJuego") ~= true then
		local inicio = player.PlayerGui:FindFirstChild("MenuInicio")
		if inicio then
			inicio.Enabled = true
		end
	end
end)

remoteRopaResult.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	if datos.ok == true then
		if envioRopa then
			estadoRopa.disenos[envioRopa.ranura] = envioRopa.diseno
			local borrador = estadoRopa.borradores[envioRopa.ranura]
			if borrador and mismoDiseno(borrador, envioRopa.diseno) then
				estadoRopa.borradores[envioRopa.ranura] = nil
			end
			if envioRopa.ranura == estadoRopa.ranura then
				if mismoDiseno(estadoRopa.diseno, envioRopa.diseno) then
					estadoRopa.modificado = false
				elseif not estadoRopa.modificado then
					-- Volvió a esta ranura antes de la respuesta: muestra lo realmente guardado.
					estadoRopa.diseno = copiarDiseno(envioRopa.diseno)
					renderRopa()
				end
			end
		end
		envioRopa = nil
		mostrarAviso(L("guardado"), VERDE_CLARO, 1.2)
	else
		envioRopa = nil
		local texto = type(datos.clave) == "string" and L(datos.clave, datos.params) or L("no_guardar")
		mostrarAviso(texto, ROJO_ACLARADO, 2)
	end
end)

-- Al abrir la gui estando ya en ROPA (el gui se oculta, no se destruye) pedimos estado fresco.
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled and pestanaActual == "ropa" then
		remotePedirRopa:FireServer()
	end
end)

renderRopa() -- pinta default/ranura 1 y deja la vista previa lista antes del primer RopaEstado

local function aplicarTextos()
	for _, par in ipairs(textosTraducibles) do
		local texto = L(par.clave)
		if par.mayusculas then
			texto = texto:upper()
		end
		par.objeto.Text = texto
	end
end

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	aplicarTextos()
	renderRopa()
end)

print("[CustomizationUI] activo")
