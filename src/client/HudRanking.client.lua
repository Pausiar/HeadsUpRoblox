-- Ranking HUD: panel de madera arriba a la izquierda con las 4 mejores posiciones.
-- Referencia visual: docs/concept/concepto-ui-pantallas.png (HUD en partida, fila 1 con corona).
-- La corona se sugiere con el AMARILLO del líder (#FFC93C), nunca con emoji (regla del ADN).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L
local MedallasRutaConfig = require(ReplicatedStorage.Shared.Config.MedallasRutaConfig)

-- mini-tokens
local COLOR_PANEL = Color3.fromRGB(62, 42, 24) -- #3E2A18
local COLOR_CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local COLOR_LIDER = Color3.fromRGB(255, 201, 60) -- #FFC93C (sugiere la corona)
local FUENTE = Enum.Font.GothamBold
local TAMANO_TEXTO = 16
local MAX_FILAS = 4
local ALTO_FILA = 26 -- deja crecer el texto al 140 % (22 px) sin recortarlo
local PASO_FILA = 30
local ANCHO_NOMBRE = 152
local ANCHO_NOMBRE_VACIO = 260 -- «Sin jugadores» ocupa la fila sin número ni puntos al lado

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HudRanking"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area: inset superior-izquierdo para no salirse bajo la notch en móviles (P1 apple-design).
local inset = GuiService:GetGuiInset()
local safeArea = Instance.new("UIPadding")
safeArea.PaddingTop = UDim.new(0, inset.Y)
safeArea.PaddingLeft = UDim.new(0, inset.X)
safeArea.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PanelRanking"
panel.Size = UDim2.fromOffset(310, 164)
panel.Position = UDim2.new(0, 20, 0, 20)
panel.BackgroundColor3 = COLOR_PANEL
panel.BorderSizePixel = 0
panel.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 12)
esquina.Parent = panel

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -20, 0, 24)
titulo.Position = UDim2.new(0, 10, 0, 8)
titulo.BackgroundTransparency = 1
titulo.Font = FUENTE
titulo.TextSize = TAMANO_TEXTO
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.TextColor3 = COLOR_CREMA
titulo.Text = L("ranking"):upper()
titulo.Parent = panel

-- Cada fila son tres etiquetas (número, nombre, puntos) para pintar el número y
-- los puntos del líder en amarillo sin RichText: los displayName no pasan por
-- escapes ni filtros.
local function etiqueta(xEscala, xOffset, y, ancho, alineacion)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromOffset(ancho, ALTO_FILA)
	t.Position = UDim2.new(xEscala, xOffset, 0, y)
	t.BackgroundTransparency = 1
	t.Font = FUENTE
	t.TextSize = TAMANO_TEXTO
	t.TextXAlignment = alineacion
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.TextColor3 = COLOR_CREMA
	t.Parent = panel
	return t
end

local filas = {}
for i = 1, MAX_FILAS do
	local y = 8 + i * PASO_FILA
	-- Chip de medalla de ruta (fase 11 · L5b): color del tier que el jugador
	-- flexeó; solo se pinta si el payload del ranking trae `medalla`.
	local medalla = Instance.new("Frame")
	medalla.Size = UDim2.fromOffset(10, 10)
	medalla.Position = UDim2.new(0, 36, 0, y + 8)
	medalla.BackgroundColor3 = COLOR_CREMA
	medalla.BorderSizePixel = 0
	medalla.Visible = false
	medalla.Parent = panel
	local esquinaMedalla = Instance.new("UICorner")
	esquinaMedalla.CornerRadius = UDim.new(0, 3)
	esquinaMedalla.Parent = medalla

	filas[i] = {
		num = etiqueta(0, 10, y, 24, Enum.TextXAlignment.Left),
		nombre = etiqueta(0, 36, y, ANCHO_NOMBRE, Enum.TextXAlignment.Left),
		puntos = etiqueta(1, -110, y, 106, Enum.TextXAlignment.Right),
		medalla = medalla,
	}
end

-- Con chip, el nombre se corre 14 px a la derecha para dejarle hueco.
local function colocarNombre(fila, conMedalla)
	local y = fila.nombre.Position.Y.Offset
	fila.nombre.Position = UDim2.fromOffset(conMedalla and 50 or 36, y)
	fila.nombre.Size = UDim2.fromOffset(conMedalla and ANCHO_NOMBRE - 14 or ANCHO_NOMBRE, ALTO_FILA)
end

-- Redibuja las filas con el payload del remote (array de { nombre, puntos, distancia, medalla? }).
local ultimaLista = {}

local function pintar(lista)
	lista = lista or {}
	ultimaLista = lista

	for i = 1, MAX_FILAS do
		local fila = filas[i]
		local entrada = lista[i]
		local visible = entrada ~= nil
		fila.num.Visible = visible
		fila.nombre.Visible = visible
		fila.puntos.Visible = visible
		fila.medalla.Visible = false
		if entrada then
			local color = i == 1 and COLOR_LIDER or COLOR_CREMA
			fila.num.Text = i .. "."
			fila.num.TextColor3 = color
			fila.nombre.TextTransparency = 0
			fila.nombre.Size = UDim2.fromOffset(ANCHO_NOMBRE, ALTO_FILA)
			fila.nombre.Text = entrada.nombre
				.. (entrada.nombre == player.DisplayName and (" (" .. L("tu"):lower() .. ")") or "")
			fila.puntos.TextColor3 = color
			fila.puntos.Text = ("— %d %s"):format(entrada.puntos, L("pts"))
			local tierMedalla = entrada.medalla and MedallasRutaConfig.PorId(entrada.medalla)
			fila.medalla.Visible = tierMedalla ~= nil
			if tierMedalla then
				fila.medalla.BackgroundColor3 = tierMedalla.color
			end
			colocarNombre(fila, tierMedalla ~= nil)
		end
	end

	-- Lista vacía: aviso en la primera fila, crema al 60 %.
	if #lista == 0 then
		local primera = filas[1]
		colocarNombre(primera, false)
		primera.nombre.Visible = true
		primera.nombre.Text = L("sin_jugadores")
		primera.nombre.TextTransparency = 0.4
		primera.nombre.Size = UDim2.fromOffset(ANCHO_NOMBRE_VACIO, ALTO_FILA)
	end
end

Remotes.Esperar(Remotes.Nombres.Ranking).OnClientEvent:Connect(pintar)
pintar({})

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	titulo.Text = L("ranking"):upper()
	pintar(ultimaLista)
end)

print("[HudRanking] activo")
