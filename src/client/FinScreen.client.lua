-- Pantalla de fin de carrera (plan §8): «¡HAS CAÍDO!» o «¡HAS LLEGADO A LA META!».
-- Variante de victoria: título verde, stats iguales, REINTENTAR + SEGUIR (oculta la GUI).
-- Paleta y estilo: docs/design/design-dna.md. Patrón de GUI reutilizado de Hud.client.lua.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local MenuCamara = require(script.Parent:WaitForChild("MenuCamara"))

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

-- Mini-tokens del ADN (docs/design/design-dna.md)
local MADERA = Color3.fromRGB(62, 42, 24) -- panel oscuro #3E2A18
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8 texto
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A acción primaria y victoria
local VERDE_APAGADO = Color3.fromRGB(62, 107, 60) -- #3E6B3C acción primaria en enfriamiento
local ROJO = Color3.fromRGB(224, 69, 58) -- #E0453A peligro/título
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C insignia récord (contraste 8.8:1 sobre madera)
local VELO = Color3.fromRGB(12, 8, 5) -- fondo oscuro semitransparente
local BLANCO = Color3.fromRGB(255, 255, 255)

local ENFRIAMIENTO = 3 -- s de debounce del botón (el servidor además limita)
local ANIMACION = 0.25 -- s, entrada sutil (accesibilidad §8: nada brusco)
local POS_FINAL = UDim2.fromScale(0.5, 0.5)
local INFO_ENTRADA = TweenInfo.new(ANIMACION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local finPartida = Remotes.Esperar(Remotes.Nombres.FinPartida)
local reintentar = Remotes.Esperar(Remotes.Nombres.Reintentar)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "FinPantalla"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
MenuCamara.Vincular(gui)

-- F4 (revisión apple-design): safe area móvil — el velo no cubre la notch.
local insetSuperior = GuiService:GetGuiInset() -- primer Vector2 = inset superior
local rellenoGui = Instance.new("UIPadding")
rellenoGui.PaddingTop = UDim.new(0, insetSuperior.Y)
rellenoGui.Parent = gui

local velo = Instance.new("Frame")
velo.Name = "Velo"
velo.Size = UDim2.fromScale(1, 1)
velo.BackgroundColor3 = VELO
velo.BackgroundTransparency = 0.45
velo.BorderSizePixel = 0
velo.Active = true -- bloquea clics a la UI de detrás (p. ej. reanimar tras cerrar la carrera)
velo.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PanelFin"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = POS_FINAL
panel.Size = UDim2.fromOffset(420, 432) -- derrota: 8 líneas + insignia + botón
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = velo

local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(0, 16)
esquina.Parent = panel

-- F1 (revisión apple-design, P1 móvil): panel escalable. El UISizeConstraint acota
-- el tamaño y el UIScale encoge el conjunto (panel + hijos) en pantallas estrechas.
local restriccionPanel = Instance.new("UISizeConstraint")
restriccionPanel.MaxSize = Vector2.new(420, 432)
restriccionPanel.MinSize = Vector2.new(340, 432)
restriccionPanel.Parent = panel

local escalaPanel = Instance.new("UIScale")
escalaPanel.Parent = panel

-- Player no tiene ViewportSize (doc Roblox gana): la GUI es la fuente del viewport
-- (IgnoreGuiInset=true ⇒ AbsoluteSize = viewport completo). La altura también manda:
-- la victoria mide 560 px y en un móvil de 338 px necesita bajar de 0,75 para que
-- los botones sigan en pantalla (A06: 560 × 0,6 = 336).
local function ajustarEscala()
	local alto = panel.Size.Y.Offset
	escalaPanel.Scale = math.clamp(math.min(gui.AbsoluteSize.X / 500, gui.AbsoluteSize.Y / (alto + 24)), 0.6, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -20, 0, 48)
titulo.Position = UDim2.new(0, 10, 0, 18)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.Text = L("has_caido")
titulo.TextSize = 40
titulo.TextColor3 = ROJO
titulo.Parent = panel

-- Variante centrada del helper etiqueta() de Hud.client.lua
local function etiqueta(y, tamano)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -40, 0, tamano)
	t.Position = UDim2.new(0, 20, 0, y)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = tamano - 4
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextColor3 = CREMA
	t.Parent = panel
	return t
end

-- Insignia de récord (una idea por pantalla): texto amarillo sobre el panel, sin pill extra.
local insignia = Instance.new("TextLabel")
insignia.Size = UDim2.new(1, -40, 0, 32)
insignia.Position = UDim2.new(0, 20, 0, 74)
insignia.BackgroundTransparency = 1
insignia.Font = Enum.Font.GothamBlack
insignia.Text = L("nuevo_record")
insignia.TextSize = 26
insignia.TextColor3 = AMARILLO
insignia.Visible = false
insignia.Parent = panel

local textoDistancia = etiqueta(104, 26)
local textoTiempo = etiqueta(136, 26)
local textoCheckpoint = etiqueta(168, 26)
local textoRecord = etiqueta(200, 26)
local textoPuntos = etiqueta(232, 26)
local textoPinas = etiqueta(264, 26)
local textoReanimaciones = etiqueta(296, 26)
local textoEquipo = etiqueta(328, 26)
local etiquetas = {
	textoDistancia,
	textoTiempo,
	textoCheckpoint,
	textoRecord,
	textoPuntos,
	textoPinas,
	textoReanimaciones,
	textoEquipo,
}

local boton = Instance.new("TextButton")
boton.Name = "BotonReintentar"
boton.AnchorPoint = Vector2.new(0.5, 0)
boton.Position = UDim2.new(0.5, 0, 0, 362)
boton.Size = UDim2.fromOffset(300, 56) -- objetivo de toque grande (≥44 px)
boton.BackgroundColor3 = VERDE
boton.BorderSizePixel = 0
boton.Font = Enum.Font.GothamBold
boton.Text = L("reintentar")
boton.TextSize = 26
boton.TextColor3 = BLANCO
boton.Parent = panel

local esquinaBoton = Instance.new("UICorner")
esquinaBoton.CornerRadius = UDim.new(0, 12)
esquinaBoton.Parent = boton

-- Acción secundaria de la victoria: solo retira el velo; la carrera ya terminó.
local botonSeguir = Instance.new("TextButton")
botonSeguir.Name = "BotonSeguir"
botonSeguir.AnchorPoint = Vector2.new(0.5, 0)
botonSeguir.Size = UDim2.fromOffset(300, 56)
botonSeguir.BackgroundColor3 = CREMA
botonSeguir.BorderSizePixel = 0
botonSeguir.Font = Enum.Font.GothamBold
botonSeguir.Text = L("seguir")
botonSeguir.TextSize = 26
botonSeguir.TextColor3 = MADERA
botonSeguir.Visible = false
botonSeguir.Parent = panel

local esquinaSeguir = Instance.new("UICorner")
esquinaSeguir.CornerRadius = UDim.new(0, 12)
esquinaSeguir.Parent = botonSeguir

-- Dos alturas fijas: derrota 432 (un botón) y victoria 560 (dos botones con 12 px de aire).
local FILAS_DERROTA = { 104, 136, 168, 200, 232, 264, 296, 328 }
local FILAS_VICTORIA = { 164, 196, 228, 260, 292, 324, 356, 388 }

local function aplicarVariante(victoria)
	if victoria then
		panel.Size = UDim2.fromOffset(420, 560)
		restriccionPanel.MaxSize = Vector2.new(420, 560)
		restriccionPanel.MinSize = Vector2.new(340, 560)
		titulo.Position = UDim2.new(0, 10, 0, 8)
		titulo.Size = UDim2.new(1, -20, 0, 114) -- holgura para dos líneas de 40 px
		titulo.TextWrapped = true
		titulo.Text = L("has_llegado")
		titulo.TextColor3 = VERDE
		insignia.Position = UDim2.new(0, 20, 0, 126)
		for i, t in ipairs(etiquetas) do
			t.Position = UDim2.new(0, 20, 0, FILAS_VICTORIA[i])
		end
		boton.Position = UDim2.new(0.5, 0, 0, 422)
		botonSeguir.Position = UDim2.new(0.5, 0, 0, 490)
		botonSeguir.Text = L("seguir")
		botonSeguir.Visible = true
	else
		panel.Size = UDim2.fromOffset(420, 432)
		restriccionPanel.MaxSize = Vector2.new(420, 432)
		restriccionPanel.MinSize = Vector2.new(340, 432)
		titulo.Position = UDim2.new(0, 10, 0, 16)
		titulo.Size = UDim2.new(1, -20, 0, 48)
		titulo.TextWrapped = false
		titulo.Text = L("has_caido")
		titulo.TextColor3 = ROJO
		insignia.Position = UDim2.new(0, 20, 0, 66)
		for i, t in ipairs(etiquetas) do
			t.Position = UDim2.new(0, 20, 0, FILAS_DERROTA[i])
		end
		boton.Position = UDim2.new(0.5, 0, 0, 362)
		botonSeguir.Visible = false
	end
	ajustarEscala()
end

local enEnfriamiento = false
local ultimosDatos = nil
local pinasPartida = 0 -- Piñas ganadas en la partida en curso (Pinas remote)

local function pintarDatos(datos)
	local distancia = math.max(0, math.floor(tonumber(datos and datos.distancia) or 0))
	local tiempo = math.max(0, math.floor(tonumber(datos and datos.tiempo) or 0))
	local checkpoint = math.floor(tonumber(datos and datos.checkpoint) or 0)
	local puntos = math.max(0, math.floor(tonumber(datos and datos.puntos) or 0))
	local record = math.max(0, math.floor(tonumber(datos and datos.record) or 0))
	local reanimaciones = math.max(0, math.floor(tonumber(datos and datos.reanimaciones) or 0))
	local mejorEquipo = math.max(0, math.floor(tonumber(datos and datos.mejorEquipo) or 0))
	local nuevoRecord = datos ~= nil and datos.nuevoRecord == true

	textoDistancia.Text = L("distancia") .. ": " .. ("%d m"):format(distancia)
	textoTiempo.Text = L("tiempo") .. ": " .. ("%02d:%02d"):format(tiempo / 60, tiempo % 60)
	textoCheckpoint.Text = L("checkpoint") .. ": "
		.. (checkpoint > 0 and ("%d"):format(checkpoint) or "—")
	textoRecord.Text = L("record") .. ": " .. ("%d m"):format(record)
	textoPuntos.Text = L("puntos") .. ": " .. ("%d"):format(puntos)
	textoPinas.Text = L("pinas_ganadas") .. ": " .. ("%d"):format(pinasPartida)
	textoReanimaciones.Text = L("reanimaciones") .. ": " .. ("%d"):format(reanimaciones)
	textoEquipo.Text = L("mejor_equipo") .. ": " .. ("%d m"):format(mejorEquipo)
	insignia.Visible = nuevoRecord
end

local function mostrar(datos)
	local victoria = datos ~= nil and datos.victoria == true
	aplicarVariante(victoria)
	ultimosDatos = datos
	pintarDatos(datos)

	-- Entrada sutil: fundido del velo + panel sube unos píxeles (nunca cambia de tamaño)
	velo.BackgroundTransparency = 1
	panel.Position = UDim2.new(0.5, 0, 0.5, 24)
	gui.Enabled = true
	TweenService:Create(velo, INFO_ENTRADA, { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(panel, INFO_ENTRADA, { Position = POS_FINAL }):Play()
end

boton.Activated:Connect(function()
	if enEnfriamiento then
		return
	end
	enEnfriamiento = true
	boton.Active = false
	boton.AutoButtonColor = false
	boton.Text = L("reanudando") -- F2: feedback visible durante el enfriamiento
	boton.BackgroundColor3 = VERDE_APAGADO
	-- El ganador no respawnea al reintentar (no hay CharacterAdded que cierre el velo)
	-- y EnJuego no cambia de valor en el servidor: limpiar aquí las Piñas de la
	-- partida anterior, que si no se sumarían a las del nuevo panel.
	gui.Enabled = false
	pinasPartida = 0
	reintentar:FireServer()
	task.delay(ENFRIAMIENTO, function()
		enEnfriamiento = false
		boton.Active = true
		boton.AutoButtonColor = true
		boton.Text = L("reintentar")
		boton.BackgroundColor3 = VERDE
	end)
end)

-- SEGUIR no toca el servidor: la carrera ya está cerrada y el jugador se queda en la meta.
botonSeguir.Activated:Connect(function()
	gui.Enabled = false
end)

finPartida.OnClientEvent:Connect(mostrar)

-- Las Piñas de la partida se acumulan del propio remote (caminar + bonus al cerrar);
-- así el total del panel también recoge el bonus de meta que llega tras FinPartida.
Remotes.Esperar(Remotes.Nombres.Pinas).OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" then
		return
	end
	local ganadas = math.max(0, math.floor(tonumber(datos.ganadas) or 0))
	if ganadas == 0 then
		return
	end
	pinasPartida += ganadas
	if gui.Enabled and ultimosDatos then
		pintarDatos(ultimosDatos)
	end
end)

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	local victoria = ultimosDatos ~= nil and ultimosDatos.victoria == true
	titulo.Text = victoria and L("has_llegado") or L("has_caido")
	insignia.Text = L("nuevo_record")
	botonSeguir.Text = L("seguir")
	boton.Text = enEnfriamiento and L("reanudando") or L("reintentar")
	pintarDatos(ultimosDatos)
end)

-- Al reaparecer, la pantalla desaparece (gui.Enabled cubre velo y panel de golpe)
player.CharacterAdded:Connect(function()
	gui.Enabled = false
end)

-- La vuelta al lobby (o un reintento) pone EnJuego=false sin recargar al ganador:
-- sin esto el velo se quedaría encima del lobby.
player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") == true then
		pinasPartida = 0 -- nueva partida: el panel arranca sin las Piñas de la anterior
	else
		gui.Enabled = false
	end
end)

aplicarVariante(false)
print("[FinScreen] activo")
