-- Subtítulos de avisos sonoros (fase 6, plan §8): crema sobre madera, abajo-centro.
-- Escucha el mismo remoto Sonido; visible solo si Settings.subtitulos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)

local player = Players.LocalPlayer

local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local DURACION = 2.5

local gui = Instance.new("ScreenGui")
gui.Name = "Subtitulos"
gui.ResetOnSpawn = false
-- IgnoreGuiInset pasa ScreenInsets a DeviceSafeInsets: respeta la safe area inferior.
gui.IgnoreGuiInset = true
gui.DisplayOrder = 59 -- encima del HUD/reanimar (57); debajo de ajustes (60)
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "PanelSubtitulo"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -170) -- por encima del panel de reanimación
panel.Size = UDim2.new(1, -24, 0, 40)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

-- 460 px en escritorio; en pantallas estrechas ocupa el ancho útil.
local tope = Instance.new("UISizeConstraint")
tope.MaxSize = Vector2.new(460, 40)
tope.Parent = panel

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 10)
esquina.Parent = panel

local texto = Instance.new("TextLabel")
texto.Size = UDim2.new(1, -24, 1, 0)
texto.Position = UDim2.fromOffset(12, 0)
texto.BackgroundTransparency = 1
texto.Font = Enum.Font.GothamBold
texto.TextSize = 18
texto.TextColor3 = CREMA
texto.TextWrapped = true
texto.TextYAlignment = Enum.TextYAlignment.Center
texto.Text = ""
texto.Parent = panel

local token = 0
local ultimoTexto = nil
local ultimoInstante = 0

local function mostrar(nuevo)
	if Settings.Obtener("subtitulos") ~= true then
		return
	end
	if nuevo == ultimoTexto and (os.clock() - ultimoInstante) < 1 then
		return -- evita el eco de dos eventos casi seguidos
	end
	ultimoTexto = nuevo
	ultimoInstante = os.clock()
	token += 1
	local mio = token
	texto.Text = nuevo
	panel.Visible = true
	task.delay(DURACION, function()
		if mio == token then
			panel.Visible = false
		end
	end)
end

local remoteSonido = nil

task.spawn(function()
	local ok, remote = pcall(Remotes.Esperar, Remotes.Nombres.Sonido)
	if not ok or not remote then
		return
	end
	remoteSonido = remote
	remote.OnClientEvent:Connect(function(payload)
		pcall(function()
			if type(payload) == "table" and type(payload.subtitulo) == "string" and payload.subtitulo ~= "" then
				mostrar(payload.subtitulo)
			end
		end)
	end)
end)

task.delay(10, function()
	if not remoteSonido then
		warn("[Subtitulos] remote Sonido ausente: sin subtítulos")
	end
end)

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave == "subtitulos" and valor ~= true then
		token += 1
		panel.Visible = false
	end
end)

print("[Subtitulos] activo")
