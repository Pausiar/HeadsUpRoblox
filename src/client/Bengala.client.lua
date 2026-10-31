-- Bengala (fase 11 · B13, plan L6): tecla G pide usar una bengala del stock.
-- El cliente NO resuelve nada: FireServer({}) y el servidor planta la bengala,
-- aturde a El Doble y responde BengalaResult { ok, clave, params } (E44).
-- El stock mostrado es SOLO el que confirma el servidor (params.restantes):
-- arranca en 0 porque la fuente de verdad es DataService vía BengalaService.
-- Sin partículas locales: las chispas pertenecen a la bengala del mundo del
-- servidor (reduceEfectos no las debe apagar: avisan al equipo, no deslumbran).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer
local TECLA = Enum.KeyCode.G -- D36 añadirá el binding de mando (L9, no este lote)

local carpetaRemotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local remoto = carpetaRemotes and carpetaRemotes:WaitForChild("Bengala", 15)
local remotoResultado = carpetaRemotes and carpetaRemotes:WaitForChild("BengalaResult", 15)
if not remoto or not remotoResultado then
	warn("[Bengala] sin remotes: la bengala queda inactiva")
	return
end

-- Etiqueta discreta apilada sobre la de linterna («F: linterna» está en 1,-38),
-- clonada de su estilo (crema #F5EBD8 al 25 %).
local gui = Instance.new("ScreenGui")
gui.Name = "HudBengala"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local etiqueta = Instance.new("TextLabel")
etiqueta.Name = "AvisoBengala"
etiqueta.AnchorPoint = Vector2.new(1, 1)
etiqueta.Position = UDim2.new(1, -16, 1, -62)
etiqueta.Size = UDim2.fromOffset(140, 24)
etiqueta.BackgroundTransparency = 1
etiqueta.Font = Enum.Font.Gotham
etiqueta.TextSize = 14
etiqueta.TextTransparency = 0.25
etiqueta.TextXAlignment = Enum.TextXAlignment.Right
etiqueta.TextColor3 = Color3.fromRGB(245, 235, 216)
etiqueta.Parent = gui

local stock = 0 -- SOLO lo confirmado por el servidor; el atributo "Bengalas" es su eco

local function pintar()
	local base = L("g_bengala", { stock })
	if base == "g_bengala" then
		-- Clave pendiente en Strings.lua (coordinador): fallback ES para no pintar la clave.
		base = ("G: bengala (%d)"):format(stock)
	end
	etiqueta.Text = base
end

local function actualizarVisibilidad()
	if UserInputService.TouchEnabled then
		return -- en táctil el rótulo de teclado se oculta (patrón Linterna); manda el botón
	end
	etiqueta.Visible = player:GetAttribute("EnJuego") == true
end

local function usar()
	if player:GetAttribute("EnJuego") ~= true then
		return -- mismo guard EnJuego que Linterna; el servidor revalida todo
	end
	remoto:FireServer({})
end

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado then
		return
	end
	if entrada.KeyCode == TECLA then
		usar()
	end
end)

-- Resultado del servidor: única fuente del stock pintado. sin_stock también
-- corrige a 0 (p. ej. tras un rejoin con etiqueta desfasada).
remotoResultado.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	if datos.ok and type(datos.params) == "table" then
		stock = math.max(0, math.floor(tonumber(datos.params.restantes) or 0))
	elseif datos.clave == "bengala_sin_stock" then
		stock = 0
	else
		return -- fallo no de stock: la etiqueta no cambia
	end
	pintar()
end)

-- Táctil: botón compartido de Acciones (el texto sale de L("bengala"): la palabra
-- coincide en ES/EN, sin clave nueva). Orden 4: tras beber, cámara y linterna.
if UserInputService.TouchEnabled then
	etiqueta.Visible = false
	local Acciones = require(script.Parent:WaitForChild("Acciones"))
	local boton = Acciones.CrearBoton("bengala", 4)
	boton.Activated:Connect(usar)
	player:GetAttributeChangedSignal("EnJuego"):Connect(function()
		boton.Visible = player:GetAttribute("EnJuego") == true
	end)
	boton.Visible = player:GetAttribute("EnJuego") == true
end

player:GetAttributeChangedSignal("EnJuego"):Connect(actualizarVisibilidad)
actualizarVisibilidad()

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	pintar()
end)

print("[Bengala] activo")
