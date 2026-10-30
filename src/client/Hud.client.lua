-- HUD mínimo del slice (referencia visual: docs/concept/, ADN en docs/design/design-dna.md)
-- Paleta del ADN: panel marrón #5C3A21, texto crema #F5EBD8, acento verde lima #8BC34A, peligro #E0453A
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HudSlice"
gui.ResetOnSpawn = false
gui.Enabled = false -- solo se enciende con EnJuego (ver aplicarEnJuego)
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area (notch): top va en el Vector2 superior-izquierdo, derecha en el inferior-derecho
local insetSup, insetInf = GuiService:GetGuiInset()
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, insetSup.Y)
padding.PaddingRight = UDim.new(0, insetInf.X)
padding.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PanelEstado"
panel.Size = UDim2.fromOffset(240, 124)
panel.Position = UDim2.new(1, -260, 0, 20)
panel.BackgroundColor3 = Color3.fromRGB(62, 42, 24)
panel.BorderSizePixel = 0
panel.Parent = gui

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 12)
esquina.Parent = panel

local function etiqueta(y, tamano, color)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -20, 0, tamano)
	t.Position = UDim2.new(0, 10, 0, y)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = tamano - 4
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = color
	t.Parent = panel
	return t
end

local distancia = etiqueta(8, 24, Color3.fromRGB(245, 235, 216))
local tiempo = etiqueta(36, 22, Color3.fromRGB(255, 201, 60))
local estado = etiqueta(64, 22, Color3.fromRGB(139, 195, 74))
-- Cuarta fila (fase 11 · L4): récord/delta en vivo o, mientras está caído, la causa.
local detalle = etiqueta(92, 22, Color3.fromRGB(245, 235, 216))

local AMARILLO = Color3.fromRGB(255, 201, 60)
local CREMA = Color3.fromRGB(245, 235, 216)
local ROJO = Color3.fromRGB(255, 111, 97) -- #FF6F61, mismo token que el estado CAÍDO

distancia.Text = L("distancia") .. ": 0 m"
tiempo.Text = L("tiempo") .. ": 00:00"
estado.Text = L("sano")
detalle.Text = ""

local inicio = os.clock()
local deadlineLocal = nil
local causaActual = nil
local recordBase = 0
local avisoRecordHasta = 0

local function refrescarEstado()
	if deadlineLocal then
		estado.Text = L("caido") .. " · " .. ("%ds"):format(math.max(0, math.ceil(deadlineLocal - os.clock())))
	else
		estado.Text = L("sano")
	end
end

-- Récord y delta en vivo (B5); si está caído, la causa ocupa la misma fila (B7).
local function refrescarDetalle(progreso)
	progreso = math.floor(tonumber(progreso) or 0)
	if causaActual then
		detalle.Text = Localization.Causa(causaActual) or L("caido")
		detalle.TextColor3 = ROJO
		return
	end
	if os.clock() < avisoRecordHasta then
		detalle.Text = L("nuevo_record")
		detalle.TextColor3 = AMARILLO
		return
	end
	local delta = progreso - recordBase
	if recordBase > 0 and delta > 0 then
		detalle.Text = L("record") .. ": " .. ("%d m"):format(progreso) .. " · +" .. ("%d"):format(delta)
		detalle.TextColor3 = AMARILLO
	else
		detalle.Text = L("record") .. ": " .. ("%d m"):format(recordBase)
		detalle.TextColor3 = CREMA
	end
end

-- Lobby/menú no son partida: el HUD solo vive con EnJuego. El cronómetro local
-- arranca al entrar a partida para no sumar el tiempo de la sala de espera.
local function aplicarEnJuego()
	local enJuego = player:GetAttribute("EnJuego") == true
	gui.Enabled = enJuego
	if enJuego then
		inicio = os.clock()
		tiempo.Text = L("tiempo") .. ": 00:00"
	end
end

player:GetAttributeChangedSignal("EnJuego"):Connect(aplicarEnJuego)
aplicarEnJuego()

Remotes.Esperar(Remotes.Nombres.HudEstado).OnClientEvent:Connect(function(datos)
	if datos.estado == "CAÍDO" then
		deadlineLocal = os.clock() + (datos.restante or 0)
		causaActual = datos.causa
		estado.TextColor3 = Color3.fromRGB(255, 111, 97) -- #FF6F61, contraste ≥ 4.5:1 (revisión apple-design)
		refrescarEstado()
	else
		deadlineLocal = nil
		causaActual = nil
		estado.TextColor3 = Color3.fromRGB(139, 195, 74)
		refrescarEstado()
	end
end)

-- Récord de sesión: el servidor lo publica al cargar el perfil, al superarlo en vivo
-- y al cerrar la partida. «superado» enciende el aviso 3 s (B5).
Remotes.Esperar(Remotes.Nombres.Record).OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	recordBase = math.max(0, math.floor(tonumber(datos.record) or 0))
	if datos.superado == true then
		avisoRecordHasta = os.clock() + 3
	end
	refrescarDetalle(player:GetAttribute("Distancia"))
end)

RunService.Heartbeat:Connect(function()
	-- Progreso curvilíneo autoritativo del servidor: el sendero ya no es una recta en X
	local progreso = tonumber(player:GetAttribute("Distancia")) or 0
	distancia.Text = L("distancia") .. ": " .. ("%d m"):format(math.max(0, math.floor(progreso)))
	local seg = math.floor(os.clock() - inicio)
	tiempo.Text = L("tiempo") .. ": " .. ("%02d:%02d"):format(seg / 60, seg % 60)
	if deadlineLocal then
		refrescarEstado()
	end
	refrescarDetalle(progreso)
end)

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	refrescarEstado()
	refrescarDetalle(player:GetAttribute("Distancia"))
end)

print("[Hud] activo")
