-- Sprint (LeftShift) + barra de estamina abajo-izquierda (plan §3.5; concepto: docs/concept/, ADN: docs/design/design-dna.md)
-- Paleta del ADN: barra verde lima #8BC34A, fondo marrón oscuro #3E2A18, texto crema #F5EBD8.
--
-- NOTA DE AUTORIDAD (honestidad del slice): la WalkSpeed se cambia desde el CLIENTE porque Roblox
-- no permite validarla en el servidor sin reemplazar el movimiento (control custom / propiedad del
-- movimiento). Aquí la estamina es cliente: un exploit puede esprintar sin gastarla. Queda
-- documentado y se mitiga en la fase 2 moviendo el movimiento a servidor (plan §3.5).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Constantes del slice (locales a propósito: GameConfig se toca cuando el balance se mida en playtest)
local ESTAMINA_MAX = 100
local DRENAJE = 20 -- estamina por segundo esprintando (5 s de sprint lleno)
local REGENERACION = 15 -- estamina por segundo en reposo
local VELOCIDAD_BASE = 16
local VELOCIDAD_SPRINT = 24
local UMBRAL_MINIMO = 10 -- tras vaciarse, no se vuelve a esprintar hasta recuperar esto

local COLOR_FONDO = Color3.fromRGB(62, 42, 24) -- #3E2A18 marrón oscuro
local COLOR_BARRA = Color3.fromRGB(139, 195, 74) -- #8BC34A verde lima (ADN: barras de estado)
local COLOR_TEXTO = Color3.fromRGB(245, 235, 216) -- #F5EBD8 crema

local estamina = ESTAMINA_MAX
local esprintando = false -- LeftShift mantenido y permitido
local bloqueadoPorVacio = false -- al llegar a 0, bloquea el sprint hasta UMBRAL_MINIMO

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
texto.Text = "Sprint: Shift"
texto.Parent = fondo

-- reducirEfectos (Settings): aquí no hay animaciones que desactivar — el tamaño de la barra es
-- funcional (se escribe cada Heartbeat), así que la opción no necesita gancho en este slice.

-- Sprint solo fuera del lobby: el flujo de JUGAR (MenuInicio) pone el atributo "EnJuego" en el jugador.
player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") ~= true then
		esprintando = false
		local humanoid = obtenerHumanoid()
		if humanoid and humanoid.Health > 0 and not humanoid.PlatformStand then
			humanoid.WalkSpeed = VELOCIDAD_BASE
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- un TextBox u otro sistema se quedó la tecla
	if input.KeyCode ~= Enum.KeyCode.LeftShift then return end
	local humanoid = obtenerHumanoid()
	if not humanoid or humanoid.Health <= 0 then return end
	esprintando = true
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.LeftShift then return end
	-- Sin check de gameProcessed a propósito: si un TextBox consumió la pulsación hay que soltar
	-- igualmente, o el sprint queda pegado drenando estamina.
	esprintando = false
end)

local function alPersonaje(character)
	estamina = ESTAMINA_MAX
	bloqueadoPorVacio = false
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = VELOCIDAD_BASE
end

player.CharacterAdded:Connect(alPersonaje)
if player.Character then
	task.spawn(alPersonaje, player.Character) -- respawn o script cargado tarde
end

RunService.Heartbeat:Connect(function(dt)
	local humanoid = obtenerHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		return -- sin personaje o muerto: no tocar nada
	end
	if humanoid.PlatformStand then
		return -- caído: PlayerStateService fija WalkSpeed 0 y lo restaura al revivir
	end

	if
		esprintando
		and not bloqueadoPorVacio
		and player:GetAttribute("EnJuego") == true
		and estamina > 0
	then
		humanoid.WalkSpeed = VELOCIDAD_SPRINT
		estamina -= DRENAJE * dt
		if estamina <= 0 then
			estamina = 0
			bloqueadoPorVacio = true -- sprint forzado fuera hasta recuperar UMBRAL_MINIMO
		end
	else
		humanoid.WalkSpeed = VELOCIDAD_BASE
		estamina += REGENERACION * dt
		if estamina > ESTAMINA_MAX then
			estamina = ESTAMINA_MAX
		end
		if bloqueadoPorVacio and estamina >= UMBRAL_MINIMO then
			bloqueadoPorVacio = false
		end
	end

	barra.Size = UDim2.new(estamina / ESTAMINA_MAX, -4, 0, 14)
end)

print("[Estamina] activo")
