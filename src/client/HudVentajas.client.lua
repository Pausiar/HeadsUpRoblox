-- Chip de ventajas del HUD (plan §L8 C29): Piñas ×2, stock de reanimaciones y Modo Puro
-- desde el remote PaseEstado. Oculto si el jugador no tiene ninguna ventaja.
-- Mismo patrón que HudPinas.client.lua: madera oscura, esquinas redondeadas, safe area y
-- apilado bajo el panel de Piñas (240x40 en y=204..244 → chip en y=252, hueco de 8 px como
-- entre Puntos y Piñas). Sin animaciones: aparece y desaparece con Visible.
-- TODO(l10n): textos ES literales con claves pendientes para Localization.Strings:
-- «ventajas_pinas», «ventajas_reanimaciones» y «ventajas_modo_puro».
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Mini-tokens de la paleta (ADN: docs/design/design-dna.md)
local MADERA_OSCURA = Color3.fromRGB(62, 42, 24) -- #3E2A18
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C (color de las Piñas)
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8 (texto sobre madera)
local AZUL = Color3.fromRGB(63, 127, 191) -- #3F7FBF (Modo Puro)

local ANCHO = 230
local ALTO_FILA = 36

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HudVentajas"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area: mismo inset que HudPinas para no salirse bajo la notch en móviles.
local inset = GuiService:GetGuiInset()
local safeArea = Instance.new("UIPadding")
safeArea.PaddingTop = UDim.new(0, inset.Y)
safeArea.PaddingLeft = UDim.new(0, inset.X)
safeArea.Parent = gui

local chip = Instance.new("Frame")
chip.Name = "ChipVentajas"
chip.Size = UDim2.fromOffset(ANCHO, ALTO_FILA) -- ALTO_FILA es el mínimo; crece si coinciden varias ventajas
chip.AutomaticSize = Enum.AutomaticSize.Y
chip.Position = UDim2.new(1, -250, 0, 252) -- bajo el panel de Piñas; borde derecho alineado con los paneles (240 en x=-260)
chip.BackgroundColor3 = MADERA_OSCURA
chip.BorderSizePixel = 0
chip.Visible = false
chip.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 10)
esquina.Parent = chip

local lista = Instance.new("UIListLayout")
lista.FillDirection = Enum.FillDirection.Vertical
lista.Padding = UDim.new(0, 2)
lista.SortOrder = Enum.SortOrder.LayoutOrder
lista.Parent = chip

-- Una fila por ventaja; cada una con su color del enunciado (amarillo/crema/azul).
local function fila(orden, color, texto)
	local f = Instance.new("Frame")
	f.Name = "Ventaja" .. orden
	f.Size = UDim2.new(1, 0, 0, ALTO_FILA)
	f.BackgroundTransparency = 1
	f.LayoutOrder = orden
	f.Visible = false
	f.Parent = chip

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -20, 1, 0)
	t.Position = UDim2.new(0, 10, 0, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextTruncate = Enum.TextTruncate.AtEnd -- degradación suave si un texto no cabe en pantallas muy estrechas
	t.TextColor3 = color
	t.Text = texto
	t.Parent = f
	return f, t
end

-- TODO(l10n): clave pendiente «ventajas_pinas»
local filaX2 = fila(1, AMARILLO, "Piñas ×2")
-- TODO(l10n): clave pendiente «ventajas_reanimaciones»
local filaReanimaciones, etiquetaReanimaciones = fila(2, CREMA, "Reanimaciones: 0")
-- TODO(l10n): clave pendiente «ventajas_modo_puro»
local filaPuro = fila(3, AZUL, "Modo Puro: ranking limpio")

-- Repinta las tres filas con el payload de PaseEstado; el chip solo se ve si hay ventaja.
-- Semántica de Piñas ×2 igual que TiendaUI: activo mientras pinasX2Hasta > os.time().
local function repintar(datos)
	if type(datos) ~= "table" then
		return
	end
	local hayX2 = (tonumber(datos.pinasX2Hasta) or 0) > os.time()
	local reanimaciones = math.max(0, math.floor(tonumber(datos.reanimaciones) or 0))
	local hayReanimaciones = reanimaciones > 0
	local hayPuro = datos.modoPuro == true

	filaX2.Visible = hayX2
	etiquetaReanimaciones.Text = ("Reanimaciones: %d"):format(reanimaciones)
	filaReanimaciones.Visible = hayReanimaciones
	filaPuro.Visible = hayPuro
	chip.Visible = hayX2 or hayReanimaciones or hayPuro
end

-- Conexión defensiva (patrón Subtitulos/Linterna): pcall + timeout; si el remote no existe
-- en esta build, un único warn y el chip queda oculto. Nada más que hacer.
task.spawn(function()
	local ok, remoto = pcall(function()
		local carpeta = ReplicatedStorage:WaitForChild("Remotes", 15)
		return carpeta and carpeta:WaitForChild(Remotes.Nombres.PaseEstado, 15)
	end)
	if not ok or not remoto then
		warn("[HudVentajas] sin remote PaseEstado: el chip de ventajas queda oculto")
		return
	end
	remoto.OnClientEvent:Connect(function(datos)
		pcall(repintar, datos)
	end)
end)

print("[HudVentajas] activo")
