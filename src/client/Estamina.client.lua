-- Sprint (LeftShift) + barra de estamina abajo-izquierda (plan §3.5; concepto: docs/concept/, ADN: docs/design/design-dna.md)
-- Paleta del ADN: barra verde lima #8BC34A, fondo marrón oscuro #3E2A18, texto crema #F5EBD8.
--
-- E43: la estamina y la WalkSpeed viven en el SERVIDOR (EstaminaService). Este script
-- solo pide esprintar con el remoto Sprint y pinta el estado que publica EstaminaEstado;
-- no toca Humanoid.WalkSpeed ni simula drenaje. La física sigue siendo del cliente
-- (riesgo residual documentado en EstaminaService).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer
local BOTON_SPRINT = Enum.KeyCode.ButtonL3
local BOTON_BEBER = Enum.KeyCode.ButtonY
local remotoBeber = Remotes.Esperar(Remotes.Nombres.BeberBebida)
local remotoBebidaResultado = Remotes.Esperar(Remotes.Nombres.BebidaResult)
local remotoSprint = Remotes.Esperar(Remotes.Nombres.Sprint)
local remotoEstado = Remotes.Esperar(Remotes.Nombres.EstaminaEstado)

local COLOR_FONDO = Color3.fromRGB(62, 42, 24) -- #3E2A18 marrón oscuro
local COLOR_BARRA = Color3.fromRGB(139, 195, 74) -- #8BC34A verde lima (ADN: barras de estado)
local COLOR_TEXTO = Color3.fromRGB(245, 235, 216) -- #F5EBD8 crema

local estaminaMax = 100

local function obtenerHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- GUI (mismo patrón que Hud.client.lua)
local gui = Instance.new("ScreenGui")
gui.Name = "EstaminaGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local fondo = Instance.new("Frame")
fondo.Name = "BarraEstamina"
fondo.AnchorPoint = Vector2.new(0, 1)
fondo.Position = UDim2.new(0, 14, 1, -14) -- abajo-izquierda, margen 14 px
fondo.Size = UDim2.fromOffset(200, 18)
fondo.BackgroundColor3 = COLOR_FONDO
fondo.BorderSizePixel = 0
fondo.Parent = gui

local esquinaFondo = Instance.new("UICorner")
esquinaFondo.CornerRadius = UDim.new(0, 9)
esquinaFondo.Parent = fondo

local barra = Instance.new("Frame")
barra.Name = "Relleno"
barra.AnchorPoint = Vector2.new(0, 0.5)
barra.Position = UDim2.new(0, 2, 0.5, 0) -- centrada vertical, margen 2 px
barra.Size = UDim2.new(1, -4, 0, 14)
barra.BackgroundColor3 = COLOR_BARRA
barra.BorderSizePixel = 0
barra.Parent = fondo

local esquinaBarra = Instance.new("UICorner")
esquinaBarra.CornerRadius = UDim.new(0, 9)
esquinaBarra.Parent = barra

local texto = Instance.new("TextLabel")
texto.Name = "AvisoSprint"
texto.AnchorPoint = Vector2.new(0, 0.5)
texto.Position = UDim2.new(0, 210, 0.5, 0) -- a la derecha del fondo (200 + 10 px)
texto.Size = UDim2.fromOffset(110, 18)
texto.BackgroundTransparency = 1
texto.Font = Enum.Font.GothamBold
texto.TextSize = 14
texto.TextXAlignment = Enum.TextXAlignment.Left
texto.TextColor3 = COLOR_TEXTO
texto.Text = L("sprint_shift")
texto.Parent = fondo

-- Bebidas de la tienda: rótulo con el stock y el atajo Q, justo sobre la barra.
-- Solo se ve en partida; tras beber muestra el aviso 1,5 s en el mismo espacio.
-- En táctil no hay atajo de teclado: el botón «Beber» de Acciones lo sustituye.
local ATAJO_BEBER = UserInputService.TouchEnabled and "" or " · Q"
local rotuloBebidas = Instance.new("TextLabel")
rotuloBebidas.Name = "AvisoBebidas"
rotuloBebidas.AnchorPoint = Vector2.new(0, 1)
rotuloBebidas.Position = UDim2.new(0, 14, 1, -38) -- 6 px sobre la barra (que acaba en -32)
rotuloBebidas.Size = UDim2.fromOffset(160, 24)
rotuloBebidas.BackgroundColor3 = COLOR_FONDO -- madera oscura: legible sobre el terreno
rotuloBebidas.BackgroundTransparency = 0.15
rotuloBebidas.BorderSizePixel = 0
rotuloBebidas.Font = Enum.Font.GothamBold
rotuloBebidas.TextSize = 18
rotuloBebidas.TextXAlignment = Enum.TextXAlignment.Center
rotuloBebidas.TextColor3 = COLOR_TEXTO
rotuloBebidas.Text = ""
rotuloBebidas.Visible = false
rotuloBebidas.Parent = gui

local esquinaBebidas = Instance.new("UICorner")
esquinaBebidas.CornerRadius = UDim.new(0, 8)
esquinaBebidas.Parent = rotuloBebidas

local avisoBebidas = nil -- tarea del aviso temporal; si existe, manda sobre el stock

local function pintarBebidas()
	if avisoBebidas then
		return -- no pisar «¡Bebida tomada!» mientras se muestra
	end
	rotuloBebidas.Visible = player:GetAttribute("EnJuego") == true
	rotuloBebidas.Text = L("bebidas") .. ": " .. (tonumber(player:GetAttribute("Bebidas")) or 0) .. ATAJO_BEBER
end

local function avisarBebidas(texto)
	rotuloBebidas.Visible = player:GetAttribute("EnJuego") == true
	rotuloBebidas.Text = texto
	if avisoBebidas then
		task.cancel(avisoBebidas)
	end
	avisoBebidas = task.delay(1.5, function()
		avisoBebidas = nil
		pintarBebidas()
	end)
end

-- El servidor descuenta el stock y repone la estamina; la barra se actualiza
-- con el siguiente EstaminaEstado.
remotoBebidaResultado.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	if datos.ok == true then
		avisarBebidas(L("bebida_tomada"))
	else
		avisarBebidas(L("sin_bebidas"))
	end
end)

local function pintarEstamina(datos)
	if type(datos) ~= "table" or type(datos.estamina) ~= "number" then
		return
	end
	estaminaMax = tonumber(datos.max) or estaminaMax
	if estaminaMax <= 0 then
		return
	end
	local fraccion = math.clamp(datos.estamina / estaminaMax, 0, 1)
	barra.Size = UDim2.new(fraccion, -4, 0, 14)
end

remotoEstado.OnClientEvent:Connect(pintarEstamina)

player:GetAttributeChangedSignal("Bebidas"):Connect(pintarBebidas)
pintarBebidas()

-- reducirEfectos (Settings): aquí no hay animaciones que desactivar — el tamaño de la barra es
-- funcional, así que la opción no necesita gancho en este slice.

local function pedirSprint(activo)
	if activo then
		local humanoid = obtenerHumanoid()
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		if player:GetAttribute("EnJuego") ~= true then
			return
		end
	end
	remotoSprint:FireServer(activo)
end

-- Sprint solo fuera del lobby: el flujo de JUGAR (MenuInicio) pone el atributo "EnJuego" en el jugador.
player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") ~= true then
		pedirSprint(false) -- el servidor devuelve la WalkSpeed base
	end
	pintarBebidas()
end)

local function detenerSprint()
	-- Sin check de gameProcessed a propósito: si un TextBox consumió la pulsación hay que soltar
	-- igualmente, o el sprint queda pegado.
	pedirSprint(false)
end

local function puedeBeber()
	local humanoid = obtenerHumanoid()
	return player:GetAttribute("EnJuego") == true
		and player:GetAttribute("Terminado") ~= true
		and humanoid ~= nil
		and humanoid.Health > 0
		and not humanoid.PlatformStand
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- un TextBox u otro sistema se quedó la tecla
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == BOTON_BEBER then
		-- Solo en partida y en pie: el servidor lo revalida igualmente.
		if puedeBeber() then
			remotoBeber:FireServer() -- el servidor valida stock y limita a 1/s
		end
		return
	end
	if input.KeyCode ~= Enum.KeyCode.LeftShift and input.KeyCode ~= BOTON_SPRINT then return end
	pedirSprint(true)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.LeftShift and input.KeyCode ~= BOTON_SPRINT then return end
	detenerSprint()
end)

-- Táctil: botón compartido que mantiene el sprint mientras se toca. El atajo de teclado
-- no se muestra (sería falso en móvil); el botón se explica solo.
if UserInputService.TouchEnabled then
	texto.Visible = false
	local Acciones = require(script.Parent:WaitForChild("Acciones"))
	local boton = Acciones.CrearBoton("sprint", 1)
	local botonBeber = Acciones.CrearBoton("beber", 2)
	local function actualizarVisibilidad()
		local enJuego = player:GetAttribute("EnJuego") == true
		boton.Visible = enJuego
		botonBeber.Visible = enJuego
	end
	player:GetAttributeChangedSignal("EnJuego"):Connect(actualizarVisibilidad)
	actualizarVisibilidad()
	boton.InputBegan:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.Touch then
			pedirSprint(true)
		end
	end)
	boton.InputEnded:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.Touch then
			detenerSprint()
		end
	end)
	botonBeber.Activated:Connect(function()
		if puedeBeber() then
			remotoBeber:FireServer()
		end
	end)
end

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	texto.Text = L("sprint_shift")
	pintarBebidas()
end)

print("[Estamina] activo (servidor autoritativo)")
