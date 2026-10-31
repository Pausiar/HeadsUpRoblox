-- Avisos visuales de sonido (fase 11 · L9/D39): la alternativa visual a los
-- avisos sonoros (plan §8): se ven SIN audio y no tapan el HUD.
-- Columna bajo el HUD izquierdo: HudCaidas acaba en y=290 (20 + 190 + 100),
-- así que la columna empieza en y=298 con 220 px de ancho.
-- Los 4 momentos del plan y su fuente real:
--   checkpoint      -> remote Puntos { puntos, motivo = "checkpoint" } (PuntosService
--                      escucha MatchService.CheckpointAlcanzado). Sonido "Checkpoint"
--                      viaja en el mismo instante al mismo jugador: se ignora para no duplicar.
--   reanimar        -> remote Sonido id "Reanimar" al REANIMADO (PlayerStateService)
--                      y remote Puntos motivo = "reanimar" al AYUDANTE (PuntosService
--                      escucha PlayerStateService.Reanimado; autocurarse no puntúa).
--   susto           -> remote Sonido con id de AudioConfig.Sustos, sin subtítulo
--                      (HazardService, cada 18-40 s). Tarjeta genérica: no delata cuál.
--   pasos del Doble -> PENDIENTE (B15/L6): hoy no existe ningún evento de pasos
--                      (sin Sonido ni remote para ello). Cuando exista, aquí va su
--                      tarjeta «Pasos cercanos» en ámbar #F28C28.
-- NOTA para el coordinador (D40/D42): el botón «Avisos: ON/OFF» es un toggle LOCAL
-- de sesión, no pasa por Settings. No se usa reducirEfectos como condición: este
-- aviso ES la alternativa visual al sonido (accesibilidad) y debe verse siempre
-- que esté activo. Migrar el toggle a Settings + pestaña de Ajustes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Settings = require(ReplicatedStorage.Shared.Settings)

-- Paleta del ADN (docs/design/design-dna.md)
local MADERA = Color3.fromRGB(62, 42, 24) -- #3E2A18
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C
local VERDE_LIMA = Color3.fromRGB(139, 195, 74) -- #8BC34A
local ROJO = Color3.fromRGB(255, 111, 97) -- #FF6F61
local NARANJA = Color3.fromRGB(255, 165, 0) -- #FFA500, D40: alternativa al rojo con daltónico

local DURACION = 2.5
local MAX = 4

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "AvisosVisuales"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 58 -- bajo Subtitulos (59) y ajustes (60)
gui.Parent = player:WaitForChild("PlayerGui")

local inset = GuiService:GetGuiInset()
local safeArea = Instance.new("UIPadding")
safeArea.PaddingTop = UDim.new(0, inset.Y)
safeArea.PaddingLeft = UDim.new(0, inset.X)
safeArea.Parent = gui

-- Columna transparente: solo las tarjetas y el botón se ven.
local columna = Instance.new("Frame")
columna.Name = "ColumnaAvisos"
columna.Size = UDim2.fromOffset(220, 180) -- 4 tarjetas de 30 + 4 huecos de 6 + botón 24
columna.Position = UDim2.new(0, 20, 0, 298) -- 8 px bajo HudCaidas
columna.BackgroundTransparency = 1
columna.Parent = gui

local lista = Instance.new("UIListLayout")
lista.FillDirection = Enum.FillDirection.Vertical
lista.Padding = UDim.new(0, 6)
lista.SortOrder = Enum.SortOrder.LayoutOrder
lista.Parent = columna

local activo = true
local tarjetas = {} -- en orden de llegada
local orden = 0

local function desvanecer(tarjeta)
	if not tarjeta or tarjeta:GetAttribute("desvaneciendo") then
		return
	end
	tarjeta:SetAttribute("desvaneciendo", true)
	local info = TweenInfo.new(0.3) -- solo transparencia
	TweenService:Create(tarjeta, info, { BackgroundTransparency = 1 }):Play()
	for _, hijo in tarjeta:GetChildren() do
		if hijo:IsA("TextLabel") then
			TweenService:Create(hijo, info, { TextTransparency = 1 }):Play()
		end
	end
	task.delay(0.3, function()
		tarjeta:Destroy()
	end)
end

local function avisar(texto, color)
	if not activo then
		return
	end
	orden += 1
	local tarjeta = Instance.new("Frame")
	tarjeta.Name = "Aviso"
	tarjeta.Size = UDim2.fromOffset(220, 30)
	tarjeta.BackgroundColor3 = MADERA
	tarjeta.BorderSizePixel = 0
	tarjeta.LayoutOrder = orden
	tarjeta.Parent = columna

	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 8)
	esquina.Parent = tarjeta

	local textoTarjeta = Instance.new("TextLabel")
	textoTarjeta.Size = UDim2.new(1, -16, 1, 0)
	textoTarjeta.Position = UDim2.fromOffset(8, 0)
	textoTarjeta.BackgroundTransparency = 1
	textoTarjeta.Font = Enum.Font.GothamBold
	textoTarjeta.TextSize = 14
	textoTarjeta.TextColor3 = color
	textoTarjeta.TextXAlignment = Enum.TextXAlignment.Center
	textoTarjeta.TextTruncate = Enum.TextTruncate.AtEnd
	textoTarjeta.Text = texto
	textoTarjeta.Parent = tarjeta

	table.insert(tarjetas, tarjeta)
	while #tarjetas > MAX do
		desvanecer(table.remove(tarjetas, 1)) -- los viejos se desvanecen
	end
	task.delay(DURACION, desvanecer, tarjeta)
end

-- checkpoint y reanimar (al ayudante) viajan por Puntos: { puntos, motivo }.
local ultimoTotal = nil
task.spawn(function()
	local ok, puntos = pcall(Remotes.Esperar, Remotes.Nombres.Puntos)
	if not ok or not puntos then
		warn("[AvisosVisuales] remote Puntos ausente: sin avisos de puntos")
		return
	end
	puntos.OnClientEvent:Connect(function(datos)
		if type(datos) ~= "table" or type(datos.puntos) ~= "number" or type(datos.motivo) ~= "string" then
			return
		end
		local anterior = ultimoTotal
		ultimoTotal = datos.puntos
		if datos.motivo == "checkpoint" then
			local delta = datos.puntos - (anterior or 0)
			avisar(delta > 0 and ("Checkpoint +" .. delta) or "Checkpoint", AMARILLO)
		elseif datos.motivo == "reanimar" then
			avisar("Reanimado", VERDE_LIMA)
		end
	end)
end)

-- susto (y reanimar al reanimado) viajan por Sonido.
task.spawn(function()
	local ok, sonido = pcall(Remotes.Esperar, Remotes.Nombres.Sonido)
	if not ok or not sonido then
		warn("[AvisosVisuales] remote Sonido ausente: sin avisos de susto")
		return
	end
	local esSusto = {}
	for _, id in AudioConfig.Sustos do
		esSusto[id] = true
	end
	sonido.OnClientEvent:Connect(function(payload)
		pcall(function()
			if type(payload) ~= "table" or type(payload.id) ~= "string" then
				return
			end
			if esSusto[payload.id] then
				avisar("¡Cuidado!", Settings.Obtener("daltónico") == true and NARANJA or ROJO)
			elseif payload.id == "Reanimar" then
				avisar("Reanimado", VERDE_LIMA)
			end
		end)
	end)
end)

-- Toggle local de sesión (el ajuste persistente llega con D40/D42).
local boton = Instance.new("TextButton")
boton.Name = "BotonAvisos"
boton.Size = UDim2.fromOffset(220, 24)
boton.BackgroundColor3 = MADERA
boton.BackgroundTransparency = 0.4
boton.BorderSizePixel = 0
boton.LayoutOrder = 2147483647 -- int32 máximo: siempre el último de la columna
boton.Font = Enum.Font.Gotham
boton.TextSize = 12
boton.TextColor3 = CREMA
boton.Text = "Avisos: ON"
boton.Parent = columna

local esquinaBoton = Instance.new("UICorner")
esquinaBoton.CornerRadius = UDim.new(0, 8)
esquinaBoton.Parent = boton

boton.Activated:Connect(function()
	activo = not activo
	boton.Text = activo and "Avisos: ON" or "Avisos: OFF"
	if not activo then
		for _, tarjeta in tarjetas do
			tarjeta:Destroy()
		end
		tarjetas = {}
	end
end)

print("[AvisosVisuales] activo")
