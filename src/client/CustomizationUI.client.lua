-- Pantalla de personalización (concepto: pestañas Cuerpo/Ropa/Accesorios con sliders y GUARDAR).
-- Fase actual: solo CUERPO (altura/ancho/cabeza); Ropa y Accesorios llegan en fases posteriores.
-- Contrato con MenuInicio: su PERSONALIZAR habilita esta gui; nuestro VOLVER re-muestra MenuInicio si no estamos en juego.
-- Vista previa en vivo: el remote solo se dispara al SOLTAR cada slider (CustomizationService valida y aplica en vivo).
-- Reutiliza paleta y patrón crearSlider de MenuAjustes.client.lua; ADN visual en docs/design/design-dna.md
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local personalizacion = Config.Etapa0.Personalizacion

local player = Players.LocalPlayer
local remote = Remotes.Esperar("Personalizacion")

-- Paleta del ADN
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C
local MARRON = Color3.fromRGB(107, 74, 43) -- #6B4A2B

local gui = Instance.new("ScreenGui")
gui.Name = "Personalizacion"
gui.Enabled = false
gui.DisplayOrder = 55
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area: inset superior-izquierdo para no quedar bajo la notch en móviles (patrón HudRanking).
local inset = GuiService:GetGuiInset()
local safeArea = Instance.new("UIPadding")
safeArea.PaddingTop = UDim.new(0, inset.Y)
safeArea.PaddingLeft = UDim.new(0, inset.X)
safeArea.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(460, 420)
panel.Position = UDim2.new(0.5, -230, 0.5, -210)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = gui

local esquinaPanel = Instance.new("UICorner")
esquinaPanel.CornerRadius = UDim.new(0, 16)
esquinaPanel.Parent = panel

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio)
	esquina.Parent = objeto
end

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, 0, 0, 36)
titulo.Position = UDim2.new(0, 0, 0, 12)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 28
titulo.Text = "PERSONALIZACIÓN"
titulo.TextColor3 = CREMA
titulo.Parent = panel

-- Pestaña actual. Ropa y Accesorios llegarán en fases posteriores.
local pestana = Instance.new("TextLabel")
pestana.Size = UDim2.new(1, 0, 0, 18)
pestana.Position = UDim2.new(0, 0, 0, 50)
pestana.BackgroundTransparency = 1
pestana.Font = Enum.Font.GothamBlack
pestana.TextSize = 16
pestana.Text = "CUERPO"
pestana.TextColor3 = AMARILLO
pestana.Parent = panel

local function etiquetaFila(y, texto)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -48, 0, 22)
	t.Position = UDim2.new(0, 24, 0, y)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 20
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = CREMA
	t.Text = texto
	t.Parent = panel
	return t
end

-- Los valores iniciales son el default 1.0; si el jugador tiene escalas guardadas, el
-- servidor las publica por TusDatos al terminar de cargar el DataStore y se aplican aquí.
local estado = { altura = 1, ancho = 1, cabeza = 1 }

-- Escalas guardadas (TusDatos: server->client, payload = tabla guardada, puede venir {}).
-- Orden anti-carrera: se conecta ANTES de crear los sliders; si el remote llega primero
-- queda en `pendiente` y se vuelca justo tras crearlos; si llega después, se aplica al momento.
local pendiente = nil
local aplicarEscalasGuardadas = nil -- se define tras crear los sliders (necesita sus refrescar)
Remotes.Esperar("TusDatos").OnClientEvent:Connect(function(datos)
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
	remote:FireServer({ altura = estado.altura, ancho = estado.ancho, cabeza = estado.cabeza })
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

-- Slider real: pista 300x8 + knob circular arrastrable (patrón EXACTO de MenuAjustes).
-- Adaptado: valores flotantes con 2 decimales, sin símbolo % (los rangos no empiezan en 0),
-- escribe en `estado` y devuelve su refrescar para el botón ALEATORIO.
local function crearSlider(yFila, texto, clave, minimo, maximo)
	etiquetaFila(yFila, texto)

	local pista = Instance.new("Frame")
	pista.Size = UDim2.fromOffset(300, 8)
	pista.Position = UDim2.new(0, 24, 0, yFila + 32)
	pista.BackgroundColor3 = CREMA
	pista.BackgroundTransparency = 0.3
	pista.BorderSizePixel = 0
	pista.Parent = panel
	redondear(pista, 4)

	local valor = Instance.new("TextLabel")
	valor.Size = UDim2.fromOffset(100, 26)
	valor.Position = UDim2.new(0, 336, 0, yFila + 23)
	valor.BackgroundTransparency = 1
	valor.Font = Enum.Font.GothamBold
	valor.TextSize = 20
	valor.TextXAlignment = Enum.TextXAlignment.Right
	valor.TextColor3 = CREMA
	valor.Parent = panel

	local agarre = Instance.new("TextButton")
	agarre.Size = UDim2.fromOffset(40, 40)
	agarre.BackgroundTransparency = 1
	agarre.Text = ""
	agarre.AutoButtonColor = false
	agarre.Parent = pista

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.new(0.5, -10, 0.5, -10)
	knob.BackgroundColor3 = AMARILLO
	knob.BorderSizePixel = 0
	knob.Parent = agarre
	redondear(knob, 10) -- círculo

	local function refrescar()
		local v = estado[clave]
		local alpha = (v - minimo) / (maximo - minimo)
		agarre.Position = UDim2.new(alpha, -20, 0.5, -20)
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

local refrescarAltura = crearSlider(76, "Altura", "altura", personalizacion.AlturaMin, personalizacion.AlturaMax)
local refrescarAncho = crearSlider(134, "Ancho", "ancho", personalizacion.AnchoMin, personalizacion.AnchoMax)
local refrescarCabeza = crearSlider(192, "Cabeza", "cabeza", personalizacion.CabezaMin, personalizacion.CabezaMax)

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

local aleatorio = Instance.new("TextButton")
aleatorio.Size = UDim2.fromOffset(240, 44)
aleatorio.Position = UDim2.new(0, 110, 0, 248)
aleatorio.BackgroundColor3 = MARRON
aleatorio.Font = Enum.Font.GothamBlack
aleatorio.TextSize = 20
aleatorio.TextColor3 = CREMA
aleatorio.Text = "ALEATORIO"
aleatorio.Parent = panel
redondear(aleatorio, 10)

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

local guardar = Instance.new("TextButton")
guardar.Size = UDim2.fromOffset(240, 52)
guardar.Position = UDim2.new(0, 100, 0, 302)
guardar.BackgroundColor3 = VERDE
guardar.Font = Enum.Font.GothamBlack
guardar.TextSize = 22
guardar.TextColor3 = CREMA
guardar.Text = "GUARDAR"
guardar.Parent = panel
redondear(guardar, 12)

local guardado = Instance.new("TextLabel")
guardado.Size = UDim2.fromOffset(112, 52)
guardado.Position = UDim2.new(0, 344, 0, 302)
guardado.BackgroundTransparency = 1
guardado.Font = Enum.Font.GothamBlack
guardado.TextSize = 16
guardado.TextXAlignment = Enum.TextXAlignment.Right
guardado.TextColor3 = VERDE
guardado.Text = ""
guardado.Parent = panel

local ocultarGuardado = nil

guardar.Activated:Connect(function()
	enviar() -- reenvía por si soltó el ratón/dedo fuera de la pista
	guardado.Text = "GUARDADO"
	if ocultarGuardado then
		task.cancel(ocultarGuardado)
	end
	ocultarGuardado = task.delay(1.2, function()
		guardado.Text = ""
		ocultarGuardado = nil
	end)
end)

local volver = Instance.new("TextButton")
volver.Size = UDim2.fromOffset(240, 44)
volver.Position = UDim2.new(0, 110, 0, 364)
volver.BackgroundColor3 = MARRON
volver.Font = Enum.Font.GothamBlack
volver.TextSize = 20
volver.TextColor3 = CREMA
volver.Text = "VOLVER"
volver.Parent = panel
redondear(volver, 10)

volver.Activated:Connect(function()
	gui.Enabled = false
	if player:GetAttribute("EnJuego") ~= true then
		local inicio = player.PlayerGui:FindFirstChild("MenuInicio")
		if inicio then
			inicio.Enabled = true
		end
	end
end)

print("[CustomizationUI] activo")
