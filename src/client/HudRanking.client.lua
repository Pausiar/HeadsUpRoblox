-- Ranking HUD: panel de madera arriba a la izquierda con las 4 mejores posiciones.
-- Referencia visual: docs/concept/concepto-ui-pantallas.png (HUD en partida, fila 1 con corona).
-- La corona se sugiere con el AMARILLO del líder (#FFC93C), nunca con emoji (regla del ADN).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- mini-tokens
local COLOR_PANEL = Color3.fromRGB(62, 42, 24) -- #3E2A18
local COLOR_CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local COLOR_LIDER = Color3.fromRGB(255, 201, 60) -- #FFC93C (sugiere la corona)
local FUENTE = Enum.Font.GothamBold
local TAMANO_TEXTO = 16
local MAX_FILAS = 4
local ALTO_FILA = 22
local PASO_FILA = 26
local ANCHO_NOMBRE = 84
local ANCHO_NOMBRE_VACIO = 178 -- «Sin jugadores» ocupa la fila sin número ni puntos al lado

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
panel.Size = UDim2.fromOffset(220, 150)
panel.Position = UDim2.new(0, 20, 0, 20)
panel.BackgroundColor3 = COLOR_PANEL
panel.BorderSizePixel = 0
panel.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 12)
esquina.Parent = panel

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -20, 0, 20)
titulo.Position = UDim2.new(0, 10, 0, 8)
titulo.BackgroundTransparency = 1
titulo.Font = FUENTE
titulo.TextSize = TAMANO_TEXTO
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.TextColor3 = COLOR_CREMA
titulo.Text = "RANKING"
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
	filas[i] = {
		num = etiqueta(0, 10, y, 20, Enum.TextXAlignment.Left),
		nombre = etiqueta(0, 32, y, ANCHO_NOMBRE, Enum.TextXAlignment.Left),
		puntos = etiqueta(1, -100, y, 90, Enum.TextXAlignment.Right),
	}
end

-- Redibuja las filas con el payload del remote (array de { nombre, puntos, distancia }).
local function pintar(lista)
	lista = lista or {}

	for i = 1, MAX_FILAS do
		local fila = filas[i]
		local entrada = lista[i]
		local visible = entrada ~= nil
		fila.num.Visible = visible
		fila.nombre.Visible = visible
		fila.puntos.Visible = visible
		if entrada then
			local color = i == 1 and COLOR_LIDER or COLOR_CREMA
			fila.num.Text = i .. "."
			fila.num.TextColor3 = color
			fila.nombre.TextTransparency = 0
			fila.nombre.Size = UDim2.fromOffset(ANCHO_NOMBRE, ALTO_FILA)
			fila.nombre.Text = entrada.nombre .. (entrada.nombre == player.DisplayName and " (tú)" or "")
			fila.puntos.TextColor3 = color
			fila.puntos.Text = ("— %d pts"):format(entrada.puntos)
		end
	end

	-- Lista vacía: aviso en la primera fila, crema al 60 %.
	if #lista == 0 then
		local primera = filas[1]
		primera.nombre.Visible = true
		primera.nombre.Text = "Sin jugadores"
		primera.nombre.TextTransparency = 0.4
		primera.nombre.Size = UDim2.fromOffset(ANCHO_NOMBRE_VACIO, ALTO_FILA)
	end
end

Remotes.Esperar(Remotes.Nombres.Ranking).OnClientEvent:Connect(pintar)
pintar({})

print("[HudRanking] activo")
