-- Sala de espera formal 2–8 (plan §4.1/§4.2/§9 fase 2). La abre MenuInicio con JUGAR;
-- toda la verdad viene de LobbyEstado (servidor autoritativo, §3.3): aquí no se inventan
-- estados de listo ni de partida. Paleta y estilo: docs/design/design-dna.md.
-- Patrón de GUI reutilizado de MenuInicio/MenuAjustes/TiendaUI (una sola gui, sin frameworks).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.LobbyConfig)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

-- Mini-tokens del ADN (docs/design/design-dna.md)
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21 panel
local MADERA_BOTON = Color3.fromRGB(107, 74, 43) -- #6B4A2B botones secundarios/filas
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8 texto
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A acción primaria
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C destacado
local MARRON_OSCURO = Color3.fromRGB(62, 42, 24) -- #3E2A18 texto sobre amarillo
local BLANCO = Color3.fromRGB(255, 255, 255)

local MAX_JUGADORES = LobbyConfig.MaxJugadores -- 8 filas creadas una vez y reutilizadas
local ALTO_FILA = 27
local PASO_FILA = 29
local AVISO_RANKING = 6 -- s del aviso si el panel de ranking aún no existe

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyUI"
gui.Enabled = false
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 55 -- MenuInicio 50, tienda 58
gui.Parent = player:WaitForChild("PlayerGui")

-- Safe area móvil: mismo patrón que TiendaUI/MenuAjustes/FinScreen.
local insetSup, insetInf = GuiService:GetGuiInset()
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, insetSup.Y)
pad.PaddingLeft = UDim.new(0, insetSup.X)
pad.PaddingRight = UDim.new(0, insetInf.X)
pad.PaddingBottom = UDim.new(0, insetInf.Y)
pad.Parent = gui

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio)
	esquina.Parent = objeto
	return esquina
end

-- El panel nominal es 560x540; en pantallas estrechas se escala el conjunto para no recortar.
-- Si aun así no cabe (móvil apaisado), un ScrollingFrame lo desplaza: los botones nunca
-- quedan fuera del área táctil. El suelo 0,9 mantiene los botones de 44 px en ~40 px.
local marco = Instance.new("ScrollingFrame")
marco.Name = "MarcoScroll"
marco.AnchorPoint = Vector2.new(0.5, 0.5)
marco.Position = UDim2.fromScale(0.5, 0.5)
marco.BackgroundTransparency = 1
marco.BorderSizePixel = 0
marco.ScrollBarThickness = 4
marco.ScrollBarImageColor3 = CREMA
marco.ScrollingDirection = Enum.ScrollingDirection.XY
marco.CanvasSize = UDim2.fromOffset(0, 0)
marco.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PanelLobby"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(0, 0)
panel.Size = UDim2.fromOffset(560, 540)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = marco
redondear(panel, 16)

local escala = Instance.new("UIScale")
escala.Parent = panel
local function ajustarEscala()
	local ancho = gui.AbsoluteSize.X - insetSup.X - insetInf.X
	local alto = gui.AbsoluteSize.Y - insetSup.Y - insetInf.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	escala.Scale = math.clamp(math.min(ancho / 600, alto / 580), 0.9, 1)
	local anchoPanel = 560 * escala.Scale
	local altoPanel = 540 * escala.Scale
	marco.CanvasSize = UDim2.fromOffset(anchoPanel, altoPanel)
	marco.Size = UDim2.fromOffset(math.min(ancho, anchoPanel), math.min(alto, altoPanel))
	marco.ScrollingEnabled = anchoPanel > ancho or altoPanel > alto
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local function etiqueta(padre, posicion, tamano, texto, tamanoTexto, color, fuente, alineacion)
	local t = Instance.new("TextLabel")
	t.Position = posicion
	t.Size = tamano
	t.BackgroundTransparency = 1
	t.Font = fuente or Enum.Font.GothamBold
	t.Text = texto or ""
	t.TextSize = tamanoTexto
	t.TextColor3 = color
	t.TextXAlignment = alineacion or Enum.TextXAlignment.Center
	t.Parent = padre
	return t
end

local function boton(padre, nombre, posicion, tamano, texto, tamanoTexto, colorFondo, colorTexto)
	local b = Instance.new("TextButton")
	b.Name = nombre
	b.Position = posicion
	b.Size = tamano
	b.BackgroundColor3 = colorFondo
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.Text = texto
	b.TextSize = tamanoTexto
	b.TextColor3 = colorTexto
	b.Parent = padre
	redondear(b, 10)
	return b
end

local tituloSala = etiqueta(
	panel,
	UDim2.fromOffset(0, 12),
	UDim2.new(1, 0, 0, 34),
	L("sala_espera"),
	32,
	CREMA,
	Enum.Font.GothamBlack
)

local subtitulo = etiqueta(
	panel,
	UDim2.fromOffset(0, 48),
	UDim2.new(1, 0, 0, 20),
	("%d–%d "):format(LobbyConfig.MinJugadores, LobbyConfig.MaxJugadores) .. L("jugadores_listos"),
	18,
	AMARILLO,
	Enum.Font.Gotham
)

-- Selector de modo: solo el host lo cambia; el resto ve el modo activo con los botones apagados.
local botonHistoria = boton(
	panel,
	"ModoHistoria",
	UDim2.fromOffset(94, 72),
	UDim2.fromOffset(180, 44),
	L("historia"),
	20,
	MADERA_BOTON,
	CREMA
)
local botonRapida = boton(
	panel,
	"ModoRapida",
	UDim2.fromOffset(286, 72),
	UDim2.fromOffset(180, 44),
	L("ronda_rapida"),
	20,
	MADERA_BOTON,
	CREMA
)

local botonesModo = {
	{ id = "historia", boton = botonHistoria },
	{ id = "rapida", boton = botonRapida },
}

-- Lista de 8 filas fijas: se actualizan por índice con el payload, nunca se recrean.
local filas = {}
for i = 1, MAX_JUGADORES do
	local fondo = Instance.new("Frame")
	fondo.Name = "Jugador" .. i
	fondo.Position = UDim2.fromOffset(24, 120 + (i - 1) * PASO_FILA)
	fondo.Size = UDim2.fromOffset(512, ALTO_FILA)
	fondo.BackgroundColor3 = MADERA_BOTON
	fondo.BorderSizePixel = 0
	fondo.Visible = false
	fondo.Parent = panel
	redondear(fondo, 8)

	-- Borde amarillo solo en tu fila: el acento no depende de un icono ni de un emoji.
	local trazo = Instance.new("UIStroke")
	trazo.Color = AMARILLO
	trazo.Thickness = 0
	trazo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	trazo.Parent = fondo

	local numero = etiqueta(
		fondo,
		UDim2.fromOffset(8, 0),
		UDim2.fromOffset(18, ALTO_FILA),
		"",
		18,
		CREMA,
		Enum.Font.GothamBold
	)

	local nombre = etiqueta(
		fondo,
		UDim2.fromOffset(30, 0),
		UDim2.fromOffset(282, ALTO_FILA),
		"",
		20,
		CREMA,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Left
	)
	nombre.TextTruncate = Enum.TextTruncate.AtEnd

	local host = etiqueta(
		fondo,
		UDim2.fromOffset(320, 3),
		UDim2.fromOffset(62, 21),
		L("host"),
		17,
		MARRON_OSCURO,
		Enum.Font.GothamBlack
	)
	host.BackgroundColor3 = AMARILLO
	host.BackgroundTransparency = 0
	host.Visible = false
	redondear(host, 5)

	local estado = etiqueta(
		fondo,
		UDim2.fromOffset(388, 0),
		UDim2.fromOffset(112, ALTO_FILA),
		"",
		18,
		CREMA,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)

	filas[i] = {
		fondo = fondo,
		trazo = trazo,
		numero = numero,
		nombre = nombre,
		host = host,
		estado = estado,
	}
end

-- Cuenta atrás y mensajes comparten franja bajo la lista: no tapan a los jugadores.
local cuenta = etiqueta(
	panel,
	UDim2.fromOffset(0, 352),
	UDim2.new(1, 0, 0, 40),
	"",
	38,
	AMARILLO,
	Enum.Font.GothamBlack
)

local mensaje = etiqueta(
	panel,
	UDim2.fromOffset(24, 392),
	UDim2.new(1, -48, 0, 20),
	"",
	17,
	AMARILLO,
	Enum.Font.GothamBold
)
mensaje.TextTruncate = Enum.TextTruncate.AtEnd

local botonListo = boton(
	panel,
	"BotonListo",
	UDim2.fromOffset(130, 416),
	UDim2.fromOffset(300, 56),
	L("listo"):upper(),
	30,
	VERDE,
	BLANCO
)
botonListo.Active = false
botonListo.AutoButtonColor = false
botonListo.Selectable = false
botonListo.BackgroundColor3 = MADERA_BOTON

local botonEmpezar = boton(
	panel,
	"BotonEmpezar",
	UDim2.fromOffset(356, 420),
	UDim2.fromOffset(180, 48),
	L("empezar"):upper(),
	26,
	VERDE,
	BLANCO
)
botonEmpezar.Visible = false

local botonRanking = boton(
	panel,
	"BotonRanking",
	UDim2.fromOffset(396, 482),
	UDim2.fromOffset(140, 44),
	L("ranking"):upper(),
	20,
	MADERA_BOTON,
	CREMA
)

local botonVolver = boton(
	panel,
	"BotonVolver",
	UDim2.fromOffset(24, 482),
	UDim2.fromOffset(120, 44),
	L("volver"):upper(),
	20,
	MADERA_BOTON,
	CREMA
)

-- Estado local mínimo: solo refleja el último payload. La lista no se toca a mano.
local estadoActual = nil
local faseActual = nil
local esHost = false
local soyParticipante = false
local listoActual = false
local modoActual = LobbyConfig.ModoPorDefecto
local mensajeServidor = L("conectando")
local mensajeTemporal = nil
local mensajeTemporalClave = nil
local tokenMensaje = 0
local ocultaPorPartida = false

local function pintarMensaje()
	local texto = mensajeTemporal or mensajeServidor
	if
		texto == ""
		and esHost
		and faseActual == "esperando"
		and estadoActual ~= nil
		and estadoActual.puedeEmpezar ~= true
	then
		texto = L("faltan_jugadores")
	end
	mensaje.Text = texto
end

local function mostrarMensajeTemporal(texto, clave)
	tokenMensaje += 1
	local token = tokenMensaje
	mensajeTemporal = texto
	mensajeTemporalClave = clave
	pintarMensaje()
	task.delay(AVISO_RANKING, function()
		if token ~= tokenMensaje then
			return
		end
		mensajeTemporal = nil
		mensajeTemporalClave = nil
		pintarMensaje()
	end)
end

local function pintarModo()
	local puedeCambiar = esHost and faseActual == "esperando"
	for _, par in ipairs(botonesModo) do
		local activo = par.id == modoActual
		par.boton.BackgroundColor3 = activo and AMARILLO or MADERA_BOTON
		par.boton.TextColor3 = activo and MARRON_OSCURO or CREMA
		par.boton.TextTransparency = puedeCambiar and 0 or 0.15
		par.boton.Active = puedeCambiar
		par.boton.AutoButtonColor = puedeCambiar
		par.boton.Selectable = puedeCambiar
	end
end

local function pintarListo()
	-- En cuenta atrás solo se puede CANCELAR (el servidor acepta listo=false y para la cuenta)
	local puedeCancelar = faseActual == "cuenta" and listoActual
	local bloqueado = not soyParticipante or estadoActual == nil or (faseActual ~= "esperando" and not puedeCancelar)
	botonListo.Text = listoActual and L("cancelar"):upper() or L("listo"):upper()
	botonListo.Active = not bloqueado
	botonListo.AutoButtonColor = not bloqueado
	botonListo.Selectable = not bloqueado
	botonListo.BackgroundColor3 = bloqueado and MADERA_BOTON or VERDE
end

local function pintarEmpezar()
	local visible = esHost and faseActual == "esperando"
	botonEmpezar.Visible = visible
	local puede = visible and estadoActual ~= nil and estadoActual.puedeEmpezar == true
	botonEmpezar.Active = puede
	botonEmpezar.AutoButtonColor = puede
	botonEmpezar.Selectable = puede
	botonEmpezar.BackgroundColor3 = puede and VERDE or MADERA_BOTON
	botonEmpezar.TextTransparency = puede and 0 or 0.1
end

local function aplicarEstado(datos)
	if type(datos) ~= "table" then
		return
	end
	local fase = datos.fase
	if fase ~= "esperando" and fase ~= "cuenta" and fase ~= "partida" and fase ~= "resultados" then
		return
	end
	if faseActual ~= nil and faseActual ~= fase then
		tokenMensaje += 1
		mensajeTemporal = nil
		mensajeTemporalClave = nil
	end
	faseActual = fase
	estadoActual = datos

	local jugadores = type(datos.jugadores) == "table" and datos.jugadores or {}
	local propio = nil
	for _, jugador in ipairs(jugadores) do
		if type(jugador) == "table" and jugador.tu == true then
			propio = jugador
			break
		end
	end
	esHost = propio ~= nil and propio.host == true
	soyParticipante = propio ~= nil
	listoActual = propio ~= nil and propio.listo == true

	local min = tonumber(datos.min) or LobbyConfig.MinJugadores
	local max = tonumber(datos.max) or LobbyConfig.MaxJugadores
	subtitulo.Text = ("%d–%d "):format(min, max) .. L("jugadores_listos")

	modoActual = datos.modo == "rapida" and "rapida" or "historia"
	mensajeServidor = type(datos.mensaje) == "string" and datos.mensaje or ""

	for i = 1, MAX_JUGADORES do
		local fila = filas[i]
		local jugador = jugadores[i]
		if type(jugador) == "table" then
			fila.fondo.Visible = true
			fila.nombre.Text = type(jugador.nombre) == "string" and jugador.nombre or L("jugador")
			fila.numero.Text = tostring(i)
			fila.host.Visible = jugador.host == true
			local listo = jugador.listo == true
			fila.estado.Text = listo and L("listo"):upper() or L("esperando"):upper()
			fila.estado.TextColor3 = listo and AMARILLO or CREMA
			local propioFila = jugador.tu == true
			fila.trazo.Thickness = propioFila and 2 or 0
			fila.numero.TextColor3 = propioFila and AMARILLO or CREMA
		else
			fila.fondo.Visible = false
			fila.trazo.Thickness = 0
		end
	end

	if fase == "cuenta" then
		local n = tonumber(datos.cuenta)
		cuenta.Text = if n
			then L("empieza_en") .. " " .. ("%d…"):format(math.max(0, math.floor(n)))
			else L("empieza_breve")
	else
		cuenta.Text = ""
	end

	-- El host ve EMPEZAR a la derecha del READY; al cancelar la cuenta no se mueve el botón.
	botonListo.Position = UDim2.fromOffset(
		(esHost and (fase == "esperando" or fase == "cuenta")) and 24 or 130,
		416
	)

	pintarModo()
	pintarListo()
	pintarEmpezar()
	pintarMensaje()

	-- La sala solo se oculta cuando el jugador entra a partida (lo hace el handler de
	-- EnJuego). Un espectador que la abre durante una partida ve «Partida en curso».
	if ocultaPorPartida
		and player:GetAttribute("EnJuego") ~= true
		and (fase == "esperando" or fase == "cuenta")
	then
		gui.Enabled = true
		ocultaPorPartida = false
	end
end

-- El servidor pone EnJuego; al volver a false reabrimos la sala con el estado ya recibido.
player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") == true then
		if gui.Enabled then
			ocultaPorPartida = true
		end
		gui.Enabled = false
	elseif ocultaPorPartida and (faseActual == "esperando" or faseActual == "cuenta") then
		gui.Enabled = true
		ocultaPorPartida = false
	end
end)

local remoteEstado = Remotes.Esperar(Remotes.Nombres.LobbyEstado)
local remoteListo = Remotes.Esperar(Remotes.Nombres.Listo)
local remoteModo = Remotes.Esperar(Remotes.Nombres.CambiarModo)
local remoteComenzar = Remotes.Esperar(Remotes.Nombres.Comenzar)

remoteEstado.OnClientEvent:Connect(aplicarEstado)

botonListo.Activated:Connect(function()
	if faseActual ~= "esperando" and not (faseActual == "cuenta" and listoActual) then
		return
	end
	-- Acuse local: el siguiente LobbyEstado (≤5 s) restaura texto y estado.
	botonListo.Text = "…"
	botonListo.Active = false
	botonListo.AutoButtonColor = false
	botonListo.Selectable = false
	remoteListo:FireServer(not listoActual)
end)

local function cambiarModo(id)
	if not esHost or faseActual ~= "esperando" or modoActual == id then
		return
	end
	remoteModo:FireServer(id)
end

botonHistoria.Activated:Connect(function()
	cambiarModo("historia")
end)
botonRapida.Activated:Connect(function()
	cambiarModo("rapida")
end)

botonEmpezar.Activated:Connect(function()
	if not esHost or faseActual ~= "esperando" or estadoActual == nil then
		return
	end
	if estadoActual.puedeEmpezar ~= true then
		return
	end
	remoteComenzar:FireServer()
end)

botonRanking.Activated:Connect(function()
	local ranking = player.PlayerGui:FindFirstChild("RankingAmigosUI")
	if ranking and ranking:IsA("ScreenGui") then
		ranking.Enabled = true -- el panel de ranking escucha su propio Enabled
	else
		mostrarMensajeTemporal(L("ranking_no_disponible"), "ranking_no_disponible")
	end
end)

botonVolver.Activated:Connect(function()
	remoteListo:FireServer(false) -- no toca EnJuego: solo salimos de la sala
	local ranking = player.PlayerGui:FindFirstChild("RankingAmigosUI")
	if ranking and ranking:IsA("ScreenGui") then
		ranking.Enabled = false -- el cierre del lobby no deja el ranking huérfano encima
	end
	gui.Enabled = false
	ocultaPorPartida = false
	tokenMensaje += 1
	mensajeTemporal = nil
	mensajeTemporalClave = nil
	local menuInicio = player.PlayerGui:FindFirstChild("MenuInicio")
	if menuInicio then
		menuInicio.Enabled = true
	end
end)

local function aplicarTextosBase()
	tituloSala.Text = L("sala_espera")
	subtitulo.Text = ("%d–%d "):format(LobbyConfig.MinJugadores, LobbyConfig.MaxJugadores)
		.. L("jugadores_listos")
	botonHistoria.Text = L("historia")
	botonRapida.Text = L("ronda_rapida")
	botonListo.Text = L("listo"):upper()
	botonEmpezar.Text = L("empezar"):upper()
	botonRanking.Text = L("ranking"):upper()
	botonVolver.Text = L("volver"):upper()
	for _, fila in ipairs(filas) do
		fila.host.Text = L("host")
	end
end

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	if mensajeTemporalClave then
		mensajeTemporal = L(mensajeTemporalClave)
	end
	aplicarTextosBase()
	if estadoActual then
		aplicarEstado(estadoActual)
	else
		mensajeServidor = L("conectando")
		pintarListo()
		pintarMensaje()
	end
end)

pintarModo()
pintarListo()
pintarEmpezar()
pintarMensaje()

print("[LobbyUI] activo")
