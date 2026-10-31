-- Menú de ajustes (plan §8: overlay, no pausa). Escribe en Settings; CameraController y efectos leen.
-- Contrato con MenuInicio: su AJUSTES habilita esta gui; nuestro VOLVER re-muestra MenuInicio si no estamos en juego.
-- Reutiliza paleta y patrón de Hud.client.lua; ADN visual en docs/design/design-dna.md
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MenuCamara = require(script.Parent:WaitForChild("MenuCamara"))

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer

-- El remote lo crea EmpujonService (servidor). Con timeout: si la integración
-- aún no arrancó el servicio, el toggle funciona en local y el envío se omite
-- (un Esperar sin timeout colgaría el menú).
local remotoEmpujar = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(Remotes.Nombres.Empujar, 10)

-- Paleta del ADN
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C
local GRIS = Color3.fromRGB(138, 129, 119) -- #8A8177
local MARRON_OSCURO = Color3.fromRGB(62, 42, 24) -- #3E2A18

local gui = Instance.new("ScreenGui")
gui.Name = "MenuAjustes"
gui.Enabled = false
gui.DisplayOrder = 60
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
MenuCamara.Vincular(gui)

-- Safe area móvil en los cuatro lados. UIPadding solo aplica a GuiObject, así que el
-- relleno va en un contenedor a pantalla completa y no directamente en el ScreenGui.
local insetSup, insetInf = GuiService:GetGuiInset()
local contenedor = Instance.new("Frame")
contenedor.Name = "SafeArea"
contenedor.Size = UDim2.fromScale(1, 1)
contenedor.BackgroundTransparency = 1
contenedor.Parent = gui

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, insetSup.Y)
pad.PaddingLeft = UDim.new(0, insetSup.X)
pad.PaddingRight = UDim.new(0, insetInf.X)
pad.PaddingBottom = UDim.new(0, insetInf.Y)
pad.Parent = contenedor

-- Panel nominal 460x532: 4 sliders y 3 toggles con
-- objetivos de 44 px. En pantallas cortas se escala el conjunto y, si aun así no
-- cabe (móvil apaisado de 338 px de alto), un ScrollingFrame lo desplaza en
-- vertical para que VOLVER siga al alcance. El scroll es solo Y para no robar
-- el arrastre horizontal de los sliders. El suelo 0,9 mantiene los controles de
-- 44 px en ~40 px.
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
marco.Parent = contenedor

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(0, 0)
panel.Size = UDim2.fromOffset(460, 532)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = marco

local esquinaPanel = Instance.new("UICorner")
esquinaPanel.CornerRadius = UDim.new(0, 16)
esquinaPanel.Parent = panel

local escala = Instance.new("UIScale")
escala.Parent = panel
local function ajustarEscala()
	local ancho, alto = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	escala.Scale = math.clamp(math.min(ancho / 500, alto / 590), 0.9, 1)
	local anchoPanel = 460 * escala.Scale
	local altoPanel = 532 * escala.Scale
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
end

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, 0, 0, 34)
titulo.Position = UDim2.new(0, 0, 0, 12)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 30
titulo.Text = L("ajustes"):upper()
titulo.TextColor3 = CREMA
titulo.Parent = panel

-- Selector de idioma en la fila del título: dos botones de 44x44, sin mover nada más.
-- El idioma vive en Settings; AlCambiar se encarga de reaplicar los textos.
local selectores = {}
local function crearSelector(idioma, x)
	local b = Instance.new("TextButton")
	b.Name = "Idioma" .. idioma:upper()
	b.Size = UDim2.fromOffset(44, 44)
	b.Position = UDim2.fromOffset(x, 8)
	b.BackgroundColor3 = MARRON_OSCURO
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 18
	b.Text = idioma:upper()
	b.TextColor3 = CREMA
	b.AutoButtonColor = false
	b.Parent = panel
	redondear(b, 10)
	b.Activated:Connect(function()
		Settings.Cambiar("idioma", idioma)
	end)
	table.insert(selectores, { idioma = idioma, boton = b })
end
crearSelector("es", 352)
crearSelector("en", 400)

local etiquetasTraducibles = {}
local refrescosTexto = {}

-- Etiquetas aún sin clave en Strings.lua (integración §3.1 las migrará): fallback es/en local.
local LITERALES = {
	modo_amistoso = { es = "Modo amistoso", en = "Friendly mode" },
}

local function textoFila(clave)
	local literal = LITERALES[clave]
	if literal then
		return literal[Settings.Obtener("idioma")] or literal.es
	end
	return L(clave)
end

local function etiquetaFila(y, clave)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -48, 0, 22)
	t.Position = UDim2.new(0, 24, 0, y)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 20
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = CREMA
	t.Text = textoFila(clave)
	t.Parent = panel
	table.insert(etiquetasTraducibles, { objeto = t, clave = clave })
	return t
end

-- Slider real: pista 300x8 + knob circular arrastrable. El knob vive dentro de un botón
-- invisible de 44x44: área de agarre mínima táctil, mayor que el knob.
local function crearSlider(yFila, claveTexto, clave, minimo, maximo, colorKnob)
	etiquetaFila(yFila, claveTexto)

	local pista = Instance.new("Frame")
	pista.Size = UDim2.fromOffset(300, 8)
	pista.Position = UDim2.new(0, 24, 0, yFila + 30)
	pista.BackgroundColor3 = CREMA
	pista.BackgroundTransparency = 0.3
	pista.BorderSizePixel = 0
	pista.Parent = panel
	redondear(pista, 4)

	local valor = Instance.new("TextLabel")
	valor.Size = UDim2.fromOffset(100, 26)
	valor.Position = UDim2.new(0, 336, 0, yFila + 21)
	valor.BackgroundTransparency = 1
	valor.Font = Enum.Font.GothamBold
	valor.TextSize = 20
	valor.TextXAlignment = Enum.TextXAlignment.Right
	valor.TextColor3 = CREMA
	valor.Parent = panel

	local agarre = Instance.new("TextButton")
	agarre.Size = UDim2.fromOffset(44, 44)
	agarre.BackgroundTransparency = 1
	agarre.Text = ""
	agarre.AutoButtonColor = false
	agarre.Parent = pista

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.new(0.5, -10, 0.5, -10)
	knob.BackgroundColor3 = colorKnob
	knob.BorderSizePixel = 0
	knob.Parent = agarre
	redondear(knob, 10) -- círculo

	local function refrescar(v)
		v = math.floor(v)
		local alpha = (v - minimo) / (maximo - minimo)
		agarre.Position = UDim2.new(alpha, -22, 0.5, -22)
		valor.Text = ("%d%%"):format(v)
	end

	local function valorDe(xPantalla)
		local alpha = (xPantalla - pista.AbsolutePosition.X) / math.max(pista.AbsoluteSize.X, 1)
		alpha = math.clamp(alpha, 0, 1)
		return math.floor(minimo + alpha * (maximo - minimo) + 0.5)
	end

	local arrastrando = false
	local function iniciar(input)
		local tipo = input.UserInputType
		if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch then
			arrastrando = true
			Settings.Cambiar(clave, valorDe(input.Position.X))
		end
	end

	agarre.InputBegan:Connect(iniciar)
	pista.InputBegan:Connect(iniciar) -- tocar la pista salta el knob (táctil)
	UserInputService.InputChanged:Connect(function(input)
		local tipo = input.UserInputType
		if arrastrando and (tipo == Enum.UserInputType.MouseMovement or tipo == Enum.UserInputType.Touch) then
			Settings.Cambiar(clave, valorDe(input.Position.X))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local tipo = input.UserInputType
		if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch then
			arrastrando = false
		end
	end)

	Settings.AlCambiar.Event:Connect(function(claveCambiada, v)
		if claveCambiada == clave then
			refrescar(v)
		end
	end)
	refrescar(Settings.Obtener(clave))
end

-- Toggle reutilizado para «Reducir efectos», «Subtítulos» y «Modo amistoso»: 186x44, estado por texto y color.
local function crearToggle(yFila, claveTexto, clave, alCambiar)
	etiquetaFila(yFila + 11, claveTexto)

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.fromOffset(186, 44)
	toggle.Position = UDim2.new(0, 250, 0, yFila)
	toggle.Font = Enum.Font.GothamBlack
	toggle.TextSize = 18
	toggle.Parent = panel
	redondear(toggle, 10)

	local function refrescar(activado)
		toggle.Text = (activado and L("activado") or L("desactivado")):upper()
		toggle.BackgroundColor3 = activado and VERDE or GRIS
		toggle.TextColor3 = activado and CREMA or MARRON_OSCURO
	end

	toggle.Activated:Connect(function()
		local nuevo = not Settings.Obtener(clave)
		Settings.Cambiar(clave, nuevo)
		if alCambiar then
			alCambiar(nuevo)
		end
	end)
	Settings.AlCambiar.Event:Connect(function(claveCambiada, v)
		if claveCambiada == clave then
			refrescar(v == true)
		end
	end)
	table.insert(refrescosTexto, function()
		refrescar(Settings.Obtener(clave) == true)
	end)
	refrescar(Settings.Obtener(clave) == true)
end

crearSlider(52, "sensibilidad", "sensibilidad", 10, 100, VERDE)
crearSlider(114, "tamano_texto", "escalaTexto", 80, 140, AMARILLO)
crearSlider(176, "volumen_musica", "volumenMusica", 0, 100, AMARILLO)
crearSlider(238, "volumen_efectos", "volumenEfectos", 0, 100, AMARILLO)

crearToggle(306, "reducir_efectos", "reducirEfectos")
crearToggle(354, "subtitulos", "subtitulos")
-- B10: el toggle también avisa al servidor (su copia de Settings no ve este VM).
crearToggle(402, "modo_amistoso", "modoAmistoso", function(nuevo)
	if remotoEmpujar then
		remotoEmpujar:FireServer({ accion = "amistoso", valor = nuevo })
	end
end)

local volver = Instance.new("TextButton")
volver.Size = UDim2.fromOffset(240, 52)
volver.Position = UDim2.new(0, 110, 0, 458)
volver.BackgroundColor3 = VERDE
volver.Font = Enum.Font.GothamBlack
volver.TextSize = 22
volver.TextColor3 = CREMA
volver.Text = L("volver"):upper()
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

local function aplicarTextos()
	titulo.Text = L("ajustes"):upper()
	volver.Text = L("volver"):upper()
	for _, par in ipairs(etiquetasTraducibles) do
		par.objeto.Text = textoFila(par.clave)
	end
	for _, refrescar in ipairs(refrescosTexto) do
		refrescar()
	end
	local idioma = Settings.Obtener("idioma")
	for _, par in ipairs(selectores) do
		local activo = par.idioma == idioma
		par.boton.BackgroundColor3 = activo and AMARILLO or MARRON_OSCURO
		par.boton.TextColor3 = activo and MARRON_OSCURO or CREMA
	end
end

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	aplicarTextos()
end)

aplicarTextos()

print("[MenuAjustes] activo")
