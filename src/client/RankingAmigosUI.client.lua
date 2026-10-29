-- Ranking de amigos del lobby (plan §4.5 y §8): panel persistente con top 10 y marca de «tú».
-- Contrato con LobbyUI: habilitar PlayerGui.RankingAmigosUI abre el panel. Vigilamos la
-- propiedad Enabled para pedir datos al abrirse, venga el clic del LobbyUI o del botón
-- flotante propio. Ese botón vive en un ScreenGui aparte porque el panel debe nacer con
-- Enabled=false y, aun así, debe existir una entrada propia si LobbyUI no está cargado.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local RankingAmigosConfig = require(ReplicatedStorage.Shared.Config.RankingAmigosConfig)

Localization.Establecer(Settings.Obtener("idioma"))
local L = Localization.L

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Paleta del ADN (docs/design/design-dna.md). Contrastes calculados en el informe:
-- crema/madera 8.5:1, crema/tarjeta 6.7:1, crema/fila alterna 10.1:1,
-- amarillo/madera 6.6:1, amarillo/tarjeta 5.2:1 y error/madera 5.1:1.
local MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21 panel
local MARRON_TARJETA = Color3.fromRGB(107, 74, 43) -- #6B4A2B filas impares
local MARRON_FILA_ALT = Color3.fromRGB(78, 48, 25) -- #4E3019 filas pares
local MARRON_OSCURO = Color3.fromRGB(62, 42, 24) -- #3E2A18 texto sobre amarillo
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C puesto 1, nota y etiqueta TÚ
local VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A acción de cierre
local ROJO_AVISO = Color3.fromRGB(255, 160, 143) -- #FFA08F rojo aclarado: 5.13:1 sobre madera

local MAX_FILAS = math.min(RankingAmigosConfig.Top or 10, 10) -- el panel está dimensionado para 10
local ANCHO_PANEL, ALTO_PANEL = 500, 460
local ANCHO_FILA, ALTO_FILA, PASO_FILA = 460, 28, 30
local Y_FILAS = 90

-- El panel: ScreenGui con el nombre y las propiedades del contrato.
local gui = Instance.new("ScreenGui")
gui.Name = "RankingAmigosUI"
gui.Enabled = false
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 57 -- tienda 58: este panel no debe taparla
gui.Parent = playerGui

-- Safe area (notch): GetGuiInset devuelve el inset superior-izquierdo y el inferior-derecho.
local insetSup, insetInf = GuiService:GetGuiInset()
insetInf = insetInf or Vector2.zero

local relleno = Instance.new("UIPadding")
relleno.PaddingTop = UDim.new(0, insetSup.Y)
relleno.PaddingBottom = UDim.new(0, insetInf.Y)
relleno.PaddingLeft = UDim.new(0, insetSup.X)
relleno.PaddingRight = UDim.new(0, insetInf.X)
relleno.Parent = gui

-- El botón flotante propio va en su propio ScreenGui: si viviera dentro del panel,
-- Enabled=false lo ocultaría también y el lobby se quedaría sin entrada al ranking.
local botonGui = Instance.new("ScreenGui")
botonGui.Name = "RankingAmigosBoton"
botonGui.Enabled = true
botonGui.ResetOnSpawn = false
botonGui.IgnoreGuiInset = true
botonGui.DisplayOrder = 54 -- debajo del LobbyUI (55): si se cruzan, manda el panel del lobby
botonGui.Parent = playerGui

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio)
	esquina.Parent = objeto
end

local botonAmigos = Instance.new("TextButton")
botonAmigos.Name = "BotonAmigos"
botonAmigos.Size = UDim2.fromOffset(140, 48)
botonAmigos.AnchorPoint = Vector2.new(1, 1)
-- En móvil el salto de Roblox ocupa la esquina inferior derecha (70x70 + margen):
-- el botón sube por encima para no taparlo (iPhone 17 Pro: 586-726 x 251-299
-- solapaba el salto en 655-725 x 233-303).
local margenInferior = 24 + insetInf.Y + (UserInputService.TouchEnabled and 96 or 0)
botonAmigos.Position = UDim2.new(
	1,
	-(24 + insetInf.X),
	1,
	-margenInferior
)
botonAmigos.BackgroundColor3 = MARRON_TARJETA
botonAmigos.BorderSizePixel = 0
botonAmigos.Font = Enum.Font.GothamBlack
botonAmigos.TextSize = 20
botonAmigos.Text = L("amigos"):upper()
botonAmigos.TextColor3 = CREMA
botonAmigos.Visible = player:GetAttribute("EnJuego") ~= true
botonAmigos.Parent = botonGui
redondear(botonAmigos, 12)

-- Velo modal: separa el panel de la sala de detrás y absorbe los clics fuera del panel.
local velo = Instance.new("Frame")
velo.Name = "Velo"
velo.Size = UDim2.fromScale(1, 1)
velo.BackgroundColor3 = MARRON_OSCURO
velo.BackgroundTransparency = 0.35
velo.BorderSizePixel = 0
velo.Active = true
velo.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(ANCHO_PANEL, ALTO_PANEL)
panel.BackgroundColor3 = MADERA
panel.BorderSizePixel = 0
panel.Parent = gui
redondear(panel, 16)

-- Mismo patrón que LobbyUI/FinScreen: el panel nominal sigue siendo 500x460, pero se
-- encoge en viewports estrechos para no recortarse. En móvil el texto nominal de 16 px
-- también se reduce: aceptable como respaldo, pendiente de revisión táctil real.
local escala = Instance.new("UIScale")
escala.Parent = panel
local function ajustarEscala()
	local ancho, alto = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	escala.Scale = math.clamp(math.min(ancho / 540, alto / 500), 0.68, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
ajustarEscala()

local titulo = Instance.new("TextLabel")
titulo.Name = "Titulo"
titulo.Size = UDim2.new(1, -40, 0, 32)
titulo.Position = UDim2.fromOffset(20, 12)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 28
titulo.Text = L("ranking_amigos")
titulo.TextColor3 = CREMA
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.Parent = panel

local subtitulo = Instance.new("TextLabel")
subtitulo.Name = "Subtitulo"
subtitulo.Size = UDim2.new(1, -40, 0, 20)
subtitulo.Position = UDim2.fromOffset(20, 46)
subtitulo.BackgroundTransparency = 1
subtitulo.Font = Enum.Font.Gotham
subtitulo.TextSize = 16
subtitulo.Text = L("ranking_amigos_sub")
subtitulo.TextColor3 = CREMA
subtitulo.TextXAlignment = Enum.TextXAlignment.Left
subtitulo.Parent = panel

-- Nota de fallback global: solo aparece con fuente «global».
local nota = Instance.new("TextLabel")
nota.Name = "Nota"
nota.Size = UDim2.new(1, -40, 0, 20)
nota.Position = UDim2.fromOffset(20, 68)
nota.BackgroundTransparency = 1
nota.Font = Enum.Font.GothamBold
nota.TextSize = 16
nota.Text = L("ranking_global")
nota.TextColor3 = AMARILLO
nota.TextXAlignment = Enum.TextXAlignment.Left
nota.TextTruncate = Enum.TextTruncate.AtEnd
nota.RichText = false
nota.Visible = false
nota.ZIndex = 2
nota.Parent = panel

-- Mensaje central para Cargando / vacío / ninguna / error. Ocupa justo el área de la lista.
local estado = Instance.new("TextLabel")
estado.Name = "Estado"
estado.Size = UDim2.new(1, -40, 0, 298)
estado.Position = UDim2.fromOffset(20, Y_FILAS)
estado.BackgroundTransparency = 1
estado.Font = Enum.Font.GothamBold
estado.TextSize = 18
estado.Text = ""
estado.TextColor3 = CREMA
estado.TextWrapped = true
estado.RichText = false
estado.TextXAlignment = Enum.TextXAlignment.Center
estado.TextYAlignment = Enum.TextYAlignment.Center
estado.Visible = false
estado.ZIndex = 3
estado.Parent = panel

-- Filas fijas: se reutilizan en cada respuesta (sin crear objetos por refresco).
local filas = {}
for i = 1, MAX_FILAS do
	local fondo = Instance.new("Frame")
	fondo.Name = "Fila" .. i
	fondo.Size = UDim2.fromOffset(ANCHO_FILA, ALTO_FILA)
	fondo.Position = UDim2.fromOffset(20, Y_FILAS + (i - 1) * PASO_FILA)
	fondo.BackgroundColor3 = (i % 2 == 1) and MARRON_TARJETA or MARRON_FILA_ALT
	fondo.BorderSizePixel = 0
	fondo.Visible = false
	fondo.ZIndex = 2
	fondo.Parent = panel
	redondear(fondo, 6)

	local puesto = Instance.new("TextLabel")
	puesto.Name = "Puesto"
	puesto.Size = UDim2.fromOffset(26, ALTO_FILA)
	puesto.Position = UDim2.fromOffset(10, 0)
	puesto.BackgroundTransparency = 1
	puesto.Font = Enum.Font.GothamBold
	puesto.TextSize = 16
	puesto.Text = ""
	puesto.TextColor3 = CREMA
	puesto.TextXAlignment = Enum.TextXAlignment.Right
	puesto.Parent = fondo

	local nombre = Instance.new("TextLabel")
	nombre.Name = "Nombre"
	nombre.Size = UDim2.fromOffset(274, ALTO_FILA)
	nombre.Position = UDim2.fromOffset(42, 0)
	nombre.BackgroundTransparency = 1
	nombre.Font = Enum.Font.GothamBold
	nombre.TextSize = 17
	nombre.Text = ""
	nombre.TextColor3 = CREMA
	nombre.TextXAlignment = Enum.TextXAlignment.Left
	nombre.TextTruncate = Enum.TextTruncate.AtEnd
	nombre.RichText = false -- el DisplayName llega del servidor; nunca se interpreta como marcado
	nombre.Parent = fondo

	-- Etiqueta TÚ separada del nombre: no se trunca y no depende de concatenar texto ajeno.
	local tu = Instance.new("TextLabel")
	tu.Name = "Tu"
	tu.Size = UDim2.fromOffset(38, 20)
	tu.Position = UDim2.fromOffset(278, 4)
	tu.BackgroundColor3 = AMARILLO
	tu.BorderSizePixel = 0
	tu.Font = Enum.Font.GothamBlack
	tu.TextSize = 16
	tu.Text = L("tu_etiqueta")
	tu.TextColor3 = MARRON_OSCURO
	tu.Visible = false
	tu.Parent = fondo
	redondear(tu, 6)

	local distancia = Instance.new("TextLabel")
	distancia.Name = "Distancia"
	distancia.Size = UDim2.fromOffset(128, ALTO_FILA)
	distancia.Position = UDim2.fromOffset(322, 0)
	distancia.BackgroundTransparency = 1
	distancia.Font = Enum.Font.GothamBold
	distancia.TextSize = 17
	distancia.Text = ""
	distancia.TextColor3 = CREMA
	distancia.TextXAlignment = Enum.TextXAlignment.Right
	distancia.TextTruncate = Enum.TextTruncate.AtEnd
	distancia.Parent = fondo

	filas[i] = {
		fondo = fondo,
		puesto = puesto,
		nombre = nombre,
		tu = tu,
		distancia = distancia,
	}
end

local cerrar = Instance.new("TextButton")
cerrar.Name = "Cerrar"
cerrar.Size = UDim2.fromOffset(160, 48)
cerrar.Position = UDim2.fromOffset(170, 398)
cerrar.BackgroundColor3 = VERDE
cerrar.BorderSizePixel = 0
cerrar.Font = Enum.Font.GothamBlack
cerrar.TextSize = 22
cerrar.Text = L("cerrar"):upper()
cerrar.TextColor3 = CREMA
cerrar.Parent = panel
redondear(cerrar, 12)

-- Estados de la lista. Un único TextLabel evita apilar mensajes y garantiza que
-- «ninguna» no deje filas viejas visibles.
local estadoClave = nil
local ultimasFilas = nil
local ultimoGlobal = false

local function ocultarFilas()
	for i = 1, MAX_FILAS do
		filas[i].fondo.Visible = false
	end
end

local function mostrarEstado(texto, color, clave)
	ocultarFilas()
	nota.Visible = false
	estado.Text = texto
	estado.TextColor3 = color or CREMA
	estado.Visible = true
	estadoClave = clave
end

local function mostrarCargando()
	mostrarEstado(L("cargando"), CREMA, "cargando")
end

local function mostrarError(texto, clave)
	mostrarEstado(texto, ROJO_AVISO, clave)
end

local function mostrarVacio(esGlobal)
	mostrarEstado(L("sin_marcas"), CREMA, "sin_marcas")
	nota.Visible = esGlobal == true
end

local function pintarFilas(entradas, esGlobal)
	estado.Visible = false
	nota.Visible = esGlobal == true
	estadoClave = nil
	ultimasFilas = entradas
	ultimoGlobal = esGlobal == true

	for i = 1, MAX_FILAS do
		local fila = filas[i]
		local entrada = entradas[i]
		if entrada then
			local color = (i == 1) and AMARILLO or CREMA -- el líder se sugiere con el amarillo del ADN
			fila.fondo.Visible = true
			fila.puesto.Text = entrada.puesto or ("%d"):format(i)
			fila.puesto.TextColor3 = color
			fila.nombre.Text = entrada.nombre
			fila.nombre.Size = UDim2.fromOffset(entrada.tu and 230 or 274, ALTO_FILA)
			fila.nombre.TextColor3 = CREMA
			fila.tu.Visible = entrada.tu == true
			fila.distancia.Text = ("%d m"):format(entrada.distancia)
			fila.distancia.TextColor3 = color
		else
			fila.fondo.Visible = false
		end
	end
end

-- Remotes del contrato (el servidor los crea; el cliente los espera).
local remoteRanking = Remotes.Esperar(Remotes.Nombres.RankingAmigos)
local remotePedir = Remotes.Esperar(Remotes.Nombres.PedirRankingAmigos)

local ENFRIAMIENTO = (RankingAmigosConfig.EnfriamientoPeticion or 10) + 1 -- margen: el servidor mide al recibir
local INTERVALO_REFRESCO = math.max(ENFRIAMIENTO, RankingAmigosConfig.IntervaloRefrescoUI or 60)
local ESPERA_RESPUESTA = 15 -- s antes de mostrar error local si el servidor no contesta

local ultimoEnvio = -math.huge
local pendiente = false
local tareaTimeout = nil
local tareaDiferida = nil
local hiloRefresco = nil

local function cancelarTareas()
	if tareaTimeout then
		task.cancel(tareaTimeout)
		tareaTimeout = nil
	end
	if tareaDiferida then
		task.cancel(tareaDiferida)
		tareaDiferida = nil
	end
	pendiente = false
end

-- Pide el ranking respetando EnfriamientoPeticion (el servidor limita a 10 s). Si el
-- panel se acaba de cerrar y abrir, la petición se difiere en vez de perder el turno.
local function pedirRanking(mostrarCargandoEstado)
	if mostrarCargandoEstado then
		mostrarCargando()
	end
	if not gui.Enabled or pendiente then
		return
	end
	pendiente = true

	local function enviar()
		if not gui.Enabled or not pendiente then
			return
		end
		ultimoEnvio = os.clock()
		remotePedir:FireServer()

		-- El timeout cuenta desde el envío real, no desde que se encoló la petición.
		if tareaTimeout then
			task.cancel(tareaTimeout)
		end
		tareaTimeout = task.delay(ESPERA_RESPUESTA, function()
			tareaTimeout = nil
			if pendiente and gui.Enabled then
				pendiente = false
				mostrarError(L("sin_respuesta"), "sin_respuesta")
			end
		end)
	end

	local espera = ENFRIAMIENTO - (os.clock() - ultimoEnvio)
	if espera > 0 then
		tareaDiferida = task.delay(espera, function()
			tareaDiferida = nil
			enviar()
		end)
	else
		enviar()
	end
end

local function detenerRefresco()
	if hiloRefresco then
		task.cancel(hiloRefresco)
		hiloRefresco = nil
	end
end

local function iniciarRefresco()
	detenerRefresco()
	hiloRefresco = task.spawn(function()
		while gui.Enabled do
			task.wait(INTERVALO_REFRESCO)
			if not gui.Enabled then
				break
			end
			pedirRanking(false) -- refresco silencioso: conserva las filas hasta la respuesta
		end
		hiloRefresco = nil
	end)
end

local function actualizarBotonFlotante()
	botonAmigos.Visible = (not gui.Enabled) and player:GetAttribute("EnJuego") ~= true
end

local function alAbrir()
	if player:GetAttribute("EnJuego") == true then
		gui.Enabled = false -- nunca tapar el HUD de partida
		return
	end
	actualizarBotonFlotante()
	pedirRanking(true)
	iniciarRefresco()
end

local function alCerrar()
	detenerRefresco()
	cancelarTareas()
	actualizarBotonFlotante()
end

-- LobbyUI puede abrir el panel con gui.Enabled = true; aquí se piden los datos.
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then
		alAbrir()
	else
		alCerrar()
	end
end)

-- Si LobbyUI habilitó la gui mientras esperábamos los remotes, abrimos ahora.
if gui.Enabled then
	alAbrir()
end

local function aplicarPayload(payload)
	if type(payload) ~= "table" then
		mostrarError(L("error_ranking"), "error_ranking")
		return
	end

	local fuente = payload.fuente
	if fuente == "ninguna" then
		local mensaje = payload.mensaje
		if type(mensaje) ~= "string" or mensaje == "" then
			mensaje = L("ranking_no_disponible_ahora")
			mostrarEstado(mensaje, CREMA, "ranking_no_disponible_ahora")
		else
			mostrarEstado(mensaje, CREMA) -- sin filas, como pide el contrato
		end
		return
	end

	if fuente ~= "amigos" and fuente ~= "global" then
		mostrarError(L("error_ranking"), "error_ranking")
		return
	end

	local entradas = payload.entradas
	if type(entradas) ~= "table" then
		mostrarError(L("error_ranking"), "error_ranking")
		return
	end

	local validas = {}
	for i = 1, #entradas do
		local entrada = entradas[i]
		if type(entrada) == "table" then
			local nombre = entrada.nombre
			local distancia = tonumber(entrada.distancia)
			if type(nombre) == "string" and nombre ~= "" and distancia and distancia == distancia
				and math.abs(distancia) ~= math.huge then
				table.insert(validas, {
					nombre = nombre,
					distancia = math.max(0, math.round(distancia)),
					tu = entrada.tu == true,
				})
			end
		end
	end

	-- El servidor añade tu entrada aunque quedes fuera del top (11 entradas). La última
	-- fila se reserva para TÚ con puesto «—»: no se inventa una posición que no conocemos.
	if #validas > MAX_FILAS then
		local propia = nil
		for i = MAX_FILAS + 1, #validas do
			if validas[i].tu then
				propia = validas[i]
				break
			end
		end
		local recorte = {}
		for i = 1, MAX_FILAS do
			recorte[i] = validas[i]
		end
		if propia then
			propia.puesto = "—"
			recorte[MAX_FILAS] = propia
		end
		validas = recorte
	end

	if #validas == 0 then
		if #entradas > 0 then
			mostrarError(L("error_ranking"), "error_ranking")
		else
			mostrarVacio(fuente == "global")
		end
		return
	end

	pintarFilas(validas, fuente == "global")
end

remoteRanking.OnClientEvent:Connect(function(payload)
	if not gui.Enabled then
		return
	end
	pendiente = false
	if tareaTimeout then
		task.cancel(tareaTimeout)
		tareaTimeout = nil
	end
	if tareaDiferida then
		task.cancel(tareaDiferida)
		tareaDiferida = nil
	end
	aplicarPayload(payload)
end)

botonAmigos.Activated:Connect(function()
	if player:GetAttribute("EnJuego") == true then
		return
	end
	gui.Enabled = true -- la señal de propiedad hace el resto
end)

cerrar.Activated:Connect(function()
	gui.Enabled = false
end)

-- El botón flotante solo existe fuera de partida; el panel se cierra si la partida empieza.
player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") == true and gui.Enabled then
		gui.Enabled = false
	end
	actualizarBotonFlotante()
end)

actualizarBotonFlotante()

gui.Destroying:Connect(function()
	detenerRefresco()
	cancelarTareas()
	botonGui:Destroy()
end)

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave ~= "idioma" then
		return
	end
	Localization.Establecer(valor)
	botonAmigos.Text = L("amigos"):upper()
	titulo.Text = L("ranking_amigos")
	subtitulo.Text = L("ranking_amigos_sub")
	nota.Text = L("ranking_global")
	cerrar.Text = L("cerrar"):upper()
	for i = 1, MAX_FILAS do
		filas[i].tu.Text = L("tu_etiqueta")
	end
	if estado.Visible and estadoClave then
		estado.Text = L(estadoClave)
	elseif ultimasFilas and filas[1].fondo.Visible then
		pintarFilas(ultimasFilas, ultimoGlobal)
	end
end)

print("[RankingAmigosUI] activo")
