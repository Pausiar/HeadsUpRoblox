-- Renacimiento (fase 11 · L5b): estado de renacimientos, metas hacia el próximo y botón RENACER.
-- Contrato con MenuInicio (mismo que TiendaUI): su botón RENACER habilita esta gui; nuestro
-- VOLVER la oculta y re-muestra MenuInicio si EnJuego ~= true. Atajo documentado: tecla R en el lobby.
-- El servidor resuelve Renacer y empuja RenacimientoEstado { renacimientos, metas, faltan, ... };
-- aquí solo se pinta y se dispara. Patrón de panel/safe area/UIScale de MenuAjustes.client.lua,
-- barra de progreso con el patrón de Estamina.client.lua. ADN: docs/design/design-dna.md.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local MenuCamara = require(script.Parent:WaitForChild("MenuCamara"))

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer

-- El remote lo crea el servicio de renacimiento (servidor). Con timeout: si la
-- integración aún no arrancó, el panel funciona en local con el estado por defecto
-- y el envío se omite (un Esperar sin timeout colgaría el script; patrón de MenuAjustes).
local remotoRenacer = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(Remotes.Nombres.Renacer, 10)
local remotoEstado = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(Remotes.Nombres.RenacimientoEstado, 10)

-- Paleta del ADN
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21 panel
local MARRON_OSCURO = Color3.fromRGB(62, 42, 24) -- #3E2A18 fondo de barra, botón marrón
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8 texto
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A acción primaria
local VERDE_LIMA = Color3.fromRGB(139, 195, 74) -- #8BC34A barra de estado
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C buffs
local GRIS = Color3.fromRGB(138, 129, 119) -- #8A8177 botón deshabilitado

local MAX_RENACIMIENTOS = 5

-- Claves aún sin entrada en Strings.lua (el coordinador las añadirá): fallback es/en
-- local. Si la clave ya existe en Strings, gana Strings y el literal sobra (migración
-- sin tocar código).
local LITERALES = {
	renacimiento = { es = "Renacimiento", en = "Rebirth" },
	renacimientos = { es = "Renacimientos", en = "Rebirths" },
	metas_proximo = { es = "Metas para el próximo", en = "Finish lines to next" },
	puntos_buff = { es = "Puntos: +%d %%", en = "Points: +%d %%" },
	aguante_buff = { es = "Aguante: +%d %%", en = "Stamina: +%d %%" },
	renacer = { es = "RENACER", en = "REBIRTH" },
	faltan_metas = { es = "Te faltan %d metas", en = "%d finish lines to go" },
}

local function T(clave, ...)
	local args = { ... }
	local texto = L(clave, #args > 0 and args or nil)
	if texto ~= clave then -- la clave ya vive en Strings.lua
		return texto
	end
	local literal = LITERALES[clave]
	if not literal then
		return clave
	end
	local plantilla = literal[Settings.Obtener("idioma")] or literal.es
	return #args > 0 and plantilla:format(...) or plantilla
end

local gui = Instance.new("ScreenGui")
gui.Name = "RenacimientoUI"
gui.Enabled = false
gui.DisplayOrder = 57
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
MenuCamara.Vincular(gui)

-- Safe area móvil en los cuatro lados. UIPadding solo aplica a GuiObject, así que el
-- relleno va en un contenedor a pantalla completa (patrón de MenuAjustes).
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

-- Panel nominal 460x380 dentro de un ScrollingFrame: en pantallas cortas el conjunto
-- se escala y, si aun así no cabe (móvil apaisado de 338 px de alto), el marco lo
-- desplaza en vertical para que VOLVER siga al alcance.
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
panel.Size = UDim2.fromOffset(460, 380)
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
	escala.Scale = math.clamp(math.min(ancho / 500, alto / 440), 0.6, 1)
	local anchoPanel = 460 * escala.Scale
	local altoPanel = 380 * escala.Scale
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
titulo.Name = "Titulo"
titulo.Size = UDim2.new(1, 0, 0, 34)
titulo.Position = UDim2.new(0, 0, 0, 12)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 28
titulo.Text = T("renacimiento"):upper()
titulo.TextColor3 = CREMA
titulo.Parent = panel

local textoRenacimientos = Instance.new("TextLabel")
textoRenacimientos.Name = "EstadoRenacimientos"
textoRenacimientos.Size = UDim2.new(1, -48, 0, 26)
textoRenacimientos.Position = UDim2.new(0, 24, 0, 56)
textoRenacimientos.BackgroundTransparency = 1
textoRenacimientos.Font = Enum.Font.GothamBold
textoRenacimientos.TextSize = 22
textoRenacimientos.TextColor3 = CREMA
textoRenacimientos.Parent = panel

local textoMetas = Instance.new("TextLabel")
textoMetas.Name = "EstadoMetas"
textoMetas.Size = UDim2.new(1, -48, 0, 22)
textoMetas.Position = UDim2.new(0, 24, 0, 92)
textoMetas.BackgroundTransparency = 1
textoMetas.Font = Enum.Font.GothamBold
textoMetas.TextSize = 18
textoMetas.TextColor3 = CREMA
textoMetas.Parent = panel

-- Barra de progreso con el patrón de la barra de estamina: fondo marrón oscuro,
-- relleno verde lima con 2 px de margen.
local barraFondo = Instance.new("Frame")
barraFondo.Name = "BarraMetas"
barraFondo.Size = UDim2.fromOffset(412, 16)
barraFondo.Position = UDim2.new(0, 24, 0, 122)
barraFondo.BackgroundColor3 = MARRON_OSCURO
barraFondo.BorderSizePixel = 0
barraFondo.Parent = panel
redondear(barraFondo, 8)

local barraRelleno = Instance.new("Frame")
barraRelleno.Name = "Relleno"
barraRelleno.AnchorPoint = Vector2.new(0, 0.5)
barraRelleno.Position = UDim2.new(0, 2, 0.5, 0)
barraRelleno.Size = UDim2.new(0, 0, 0, 12)
barraRelleno.BackgroundColor3 = VERDE_LIMA
barraRelleno.BorderSizePixel = 0
barraRelleno.Parent = barraFondo
redondear(barraRelleno, 6)

local textoPuntos = Instance.new("TextLabel")
textoPuntos.Name = "BuffPuntos"
textoPuntos.Size = UDim2.new(1, -48, 0, 26)
textoPuntos.Position = UDim2.new(0, 24, 0, 154)
textoPuntos.BackgroundTransparency = 1
textoPuntos.Font = Enum.Font.GothamBold
textoPuntos.TextSize = 22
textoPuntos.TextColor3 = AMARILLO
textoPuntos.Parent = panel

local textoAguante = Instance.new("TextLabel")
textoAguante.Name = "BuffAguante"
textoAguante.Size = UDim2.new(1, -48, 0, 26)
textoAguante.Position = UDim2.new(0, 24, 0, 186)
textoAguante.BackgroundTransparency = 1
textoAguante.Font = Enum.Font.GothamBold
textoAguante.TextSize = 22
textoAguante.TextColor3 = AMARILLO
textoAguante.Parent = panel

local botonRenacer = Instance.new("TextButton")
botonRenacer.Name = "BotonRenacer"
botonRenacer.Size = UDim2.fromOffset(240, 52)
botonRenacer.Position = UDim2.new(0, 110, 0, 232)
botonRenacer.BackgroundColor3 = GRIS
botonRenacer.BorderSizePixel = 0
botonRenacer.Font = Enum.Font.GothamBlack
botonRenacer.TextSize = 22
botonRenacer.TextColor3 = MARRON_OSCURO
botonRenacer.AutoButtonColor = false
botonRenacer.Parent = panel
redondear(botonRenacer, 12)

local volver = Instance.new("TextButton")
volver.Name = "BotonVolver"
volver.Size = UDim2.fromOffset(240, 52)
volver.Position = UDim2.new(0, 110, 0, 300)
volver.BackgroundColor3 = MARRON_OSCURO
volver.BorderSizePixel = 0
volver.Font = Enum.Font.GothamBlack
volver.TextSize = 22
volver.TextColor3 = CREMA
volver.Text = L("volver"):upper()
volver.Parent = panel
redondear(volver, 12)

-- Estado cacheado del servidor; valores por defecto hasta el primer push de RenacimientoEstado.
local estado = { renacimientos = 0, metas = 0, faltan = 10 }
local puedeRenacer = false

local function refrescar()
	local n = math.max(0, math.floor(tonumber(estado.renacimientos) or 0))
	local metas = math.max(0, math.floor(tonumber(estado.metas) or 0))
	local faltan = math.max(0, math.floor(tonumber(estado.faltan) or 0))
	local objetivo = math.max(metas + faltan, 1)

	textoRenacimientos.Text = T("renacimientos") .. ": " .. n .. " / " .. MAX_RENACIMIENTOS
	textoMetas.Text = T("metas_proximo") .. ": " .. metas .. "/" .. objetivo
	barraRelleno.Size = UDim2.new(math.clamp(metas / objetivo, 0, 1), -4, 0, 12)
	textoPuntos.Text = T("puntos_buff", n * 10) -- +10 % de puntos por renacimiento
	textoAguante.Text = T("aguante_buff", n * 5) -- +5 % de aguante por renacimiento

	if n >= MAX_RENACIMIENTOS then
		puedeRenacer = false
		botonRenacer.Text = L("maximo")
		botonRenacer.BackgroundColor3 = GRIS
		botonRenacer.TextColor3 = MARRON_OSCURO
	elseif faltan > 0 then
		puedeRenacer = false
		botonRenacer.Text = T("faltan_metas", faltan)
		botonRenacer.BackgroundColor3 = GRIS
		botonRenacer.TextColor3 = MARRON_OSCURO
	else
		puedeRenacer = true
		botonRenacer.Text = T("renacer")
		botonRenacer.BackgroundColor3 = VERDE
		botonRenacer.TextColor3 = CREMA
	end
end

botonRenacer.Activated:Connect(function()
	if puedeRenacer and remotoRenacer then
		remotoRenacer:FireServer()
	end
end)

-- Contrato estándar (MenuAjustes/TiendaUI): ocultar y devolver el menú si no hay partida.
volver.Activated:Connect(function()
	gui.Enabled = false
	if player:GetAttribute("EnJuego") ~= true then
		local inicio = player.PlayerGui:FindFirstChild("MenuInicio")
		if inicio then
			inicio.Enabled = true
		end
	end
end)

-- Atajo documentado: tecla R abre el panel en el lobby (nunca en partida).
UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado or entrada.KeyCode ~= Enum.KeyCode.R then
		return
	end
	if player:GetAttribute("EnJuego") == true or gui.Enabled then
		return
	end
	gui.Enabled = true
end)

if remotoEstado then
	remotoEstado.OnClientEvent:Connect(function(datos)
		if type(datos) ~= "table" then
			return
		end
		estado = datos
		refrescar()
	end)
end

local function aplicarTextos()
	titulo.Text = T("renacimiento"):upper()
	volver.Text = L("volver"):upper()
	refrescar()
end

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	aplicarTextos()
end)

aplicarTextos()

print("[RenacimientoUI] activo")
