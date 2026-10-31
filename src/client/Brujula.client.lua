-- Brújula del HUD (plan fase-11 §L9 · D38): tres indicadores arriba-centro apuntan
-- al próximo checkpoint (C, amarillo), a la meta (M, verde) y a la tienda (T, azul).
-- Los datos llegan en HudEstado.objetivos (servidor autoritativo, puntos estáticos
-- de la ruta calculados en MatchService.ObjetivosBrujula). JAMÁS revela a El Doble:
-- el payload solo lleva puntos de la ruta, nunca posiciones de enemigos.
-- Colores del ADN (docs/design/design-dna.md). Criterio D38: gira con la cámara.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Brujula"
gui.ResetOnSpawn = false
gui.Enabled = false -- solo con EnJuego y con objetivos en el payload
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area (notch): mismo patrón que Hud.client.lua
local insetSup = GuiService:GetGuiInset()
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, insetSup.Y)
padding.Parent = gui

-- Arriba-centro (y=8): no pisa HudRanking (izquierda) ni el panel del HUD (derecha)
local contenedor = Instance.new("Frame")
contenedor.Name = "Indicadores"
contenedor.AnchorPoint = Vector2.new(0.5, 0)
contenedor.Position = UDim2.new(0.5, 0, 0, 8)
contenedor.Size = UDim2.fromOffset(150, 58)
contenedor.BackgroundTransparency = 1
contenedor.Parent = gui

local lista = Instance.new("UIListLayout")
lista.FillDirection = Enum.FillDirection.Horizontal
lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
lista.SortOrder = Enum.SortOrder.LayoutOrder
lista.Parent = contenedor

-- Stroke marrón oscuro del ADN: las flechas flotan sin panel y el cielo es claro
local STROKE = Color3.fromRGB(62, 42, 24)

-- La letra es un símbolo de leyenda (C/M/T), no texto traducible; la redundancia
-- de forma + color cubre daltónicos (fase-11 D40).
local OBJETIVOS = {
	{ clave = "checkpoint", letra = "C", color = Color3.fromRGB(255, 201, 60) }, -- #FFC93C
	{ clave = "meta", letra = "M", color = Color3.fromRGB(76, 140, 74) }, -- #4C8C4A
	{ clave = "tienda", letra = "T", color = Color3.fromRGB(63, 127, 191) }, -- #3F7FBF
}

local flechas = {}
for i, def in ipairs(OBJETIVOS) do
	local marco = Instance.new("Frame")
	marco.Name = def.clave
	marco.Size = UDim2.fromOffset(44, 58)
	marco.BackgroundTransparency = 1
	marco.LayoutOrder = i
	marco.Parent = contenedor

	local flecha = Instance.new("TextLabel")
	flecha.Name = "Flecha"
	flecha.AnchorPoint = Vector2.new(0.5, 0)
	flecha.Position = UDim2.new(0.5, 0, 0, 0)
	flecha.Size = UDim2.fromOffset(40, 40)
	flecha.BackgroundTransparency = 1
	flecha.Font = Enum.Font.GothamBold
	flecha.Text = "▲" -- glifo, no emoji (iconografía del ADN)
	flecha.TextSize = 30
	flecha.TextColor3 = def.color
	flecha.TextStrokeColor3 = STROKE
	flecha.TextStrokeTransparency = 0.4
	flecha.Parent = marco

	local letra = Instance.new("TextLabel")
	letra.Name = "Letra"
	letra.Position = UDim2.new(0, 0, 0, 42)
	letra.Size = UDim2.new(1, 0, 0, 14)
	letra.BackgroundTransparency = 1
	letra.Font = Enum.Font.GothamBold
	letra.Text = def.letra
	letra.TextSize = 14
	letra.TextColor3 = def.color
	letra.TextStrokeColor3 = STROKE
	letra.TextStrokeTransparency = 0.4
	letra.Parent = marco

	flechas[def.clave] = flecha
end

local objetivos = nil -- último payload del servidor; nil = lobby o payload sin brújula

local function aplicar()
	gui.Enabled = player:GetAttribute("EnJuego") == true and objetivos ~= nil
end

player:GetAttributeChangedSignal("EnJuego"):Connect(aplicar)

-- Mismo remote que Hud y ReanimarPersonalUI; aquí solo importa datos.objetivos
Remotes.Esperar(Remotes.Nombres.HudEstado).OnClientEvent:Connect(function(datos)
	if type(datos) == "table" and type(datos.objetivos) == "table" then
		objetivos = datos.objetivos
	else
		objetivos = nil
	end
	aplicar()
end)

-- Rotación relativa al yaw de la cámara. Rumbo en el plano XZ:
-- math.atan2(delta.X, delta.Z) mide desde +Z hacia +X (misma convención que
-- TerrenoService). Un objetivo delante → flecha arriba (Rotation 0); a la derecha
-- → Rotation 90 (GuiObject.Rotation positivo es horario, docs Roblox). De ahí:
-- Rotation = rumboCamara - rumboObjetivo (el signo opuesto al rumbo absoluto).
local function rotacionHacia(posicion, raiz)
	local delta = Vector3.new(posicion.x - raiz.Position.X, 0, posicion.z - raiz.Position.Z)
	local camara = workspace.CurrentCamera
	local mirar = camara and camara.CFrame.LookVector or Vector3.zAxis
	local rumboCamara = math.deg(math.atan2(mirar.X, mirar.Z))
	local rumboObjetivo = math.deg(math.atan2(delta.X, delta.Z))
	return (rumboCamara - rumboObjetivo) % 360
end

RunService.RenderStepped:Connect(function()
	if not gui.Enabled or not objetivos then
		return
	end
	local char = player.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end
	for _, def in ipairs(OBJETIVOS) do
		local flecha = flechas[def.clave]
		local pos = objetivos[def.clave]
		if type(pos) == "table" and type(pos.x) == "number" and type(pos.z) == "number" then
			flecha.Visible = true
			flecha.Rotation = rotacionHacia(pos, raiz)
		else
			flecha.Visible = false -- objetivo sin posición en el payload
		end
	end
end)

print("[Brujula] activo")
