-- Feed de caídas del equipo (fase 11 · L4/B7): las 3 últimas, arriba a la izquierda
-- bajo el panel de ranking (HudRanking: 310x164 en 20,20). El servidor manda
-- { nombre, causa } a los jugadores en partida y { reinicio = true } al empezar otra.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

-- Mini-tokens del ADN (docs/design/design-dna.md)
local MADERA = Color3.fromRGB(62, 42, 24) -- #3E2A18
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local ROJO_ACLARADO = Color3.fromRGB(255, 160, 143) -- #FFA08F (6,8:1 sobre madera)
local MAX = 3
local ANCHO = 310

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HudCaidas"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local inset = GuiService:GetGuiInset()
local safeArea = Instance.new("UIPadding")
safeArea.PaddingTop = UDim.new(0, inset.Y)
safeArea.PaddingLeft = UDim.new(0, inset.X)
safeArea.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PanelCaidas"
panel.Size = UDim2.fromOffset(ANCHO, 100)
panel.Position = UDim2.new(0, 20, 0, 190) -- 6 px bajo el ranking (20 + 164)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 12)
esquina.Parent = panel

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -20, 0, 18)
titulo.Position = UDim2.fromOffset(10, 6)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBold
titulo.TextSize = 14
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.TextColor3 = CREMA
titulo.Text = L("caidas")
titulo.Parent = panel

local filas = {}
for i = 1, MAX do
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -20, 0, 22)
	t.Position = UDim2.fromOffset(10, 24 + (i - 1) * 24)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.RichText = true
	t.TextColor3 = CREMA
	t.Text = ""
	t.Parent = panel
	filas[i] = t
end

-- El nombre es texto de jugador: se escapa antes de meterlo en RichText.
local function escapar(texto)
	return (tostring(texto):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local historial = {} -- [1] = la más reciente, hasta MAX

local function pintar()
	panel.Visible = #historial > 0
	for i = 1, MAX do
		local entrada = historial[i]
		local fila = filas[i]
		if entrada then
			local causa = Localization.Causa(entrada.causa) or L("caido")
			fila.Text = ('<font color="#F5EBD8">%s</font> · <font color="#FFA08F">%s</font>'):format(
				escapar(entrada.nombre),
				escapar(causa)
			)
		else
			fila.Text = ""
		end
	end
end

Remotes.Esperar(Remotes.Nombres.Caidas).OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	if datos.reinicio == true then
		historial = {}
		pintar()
		return
	end
	if type(datos.nombre) ~= "string" or datos.nombre == "" then
		return
	end
	table.insert(historial, 1, { nombre = datos.nombre, causa = datos.causa })
	while #historial > MAX do
		table.remove(historial)
	end
	pintar()
end)

-- Al volver al lobby o empezar otra partida no se arrastran caídas viejas.
player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") ~= true then
		historial = {}
		pintar()
	end
end)

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	titulo.Text = L("caidas")
	pintar()
end)

print("[HudCaidas] activo")
