-- MonsterService: El Doble, el monstruo que imita (plan §5).
-- Fases (§5.2): 0 Latente -> 1 Observación -> 2 Infiltración -> 3 Acecho ->
-- 4 Rapto -> 5 Retirada -> 1 ... hasta Config.Doble.MaxRaptos.
-- Servidor autoritativo. B14 (fase 11 · L6): por partida hay una LISTA de
-- clones: 1 con 2–5 jugadores EnJuego y 2 con 6–8. Ambos comparten el retardo
-- de aparición, la madriguera y el tope TOTAL de raptos; cada clon corre su
-- propio bucle de fases y RESERVA a su víctima, así que dos clones nunca
-- cazan a la misma víctima a la vez. El Doble NUNCA mata (§5.4): la víctima
-- queda caída con su cuenta atrás normal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TelemetriaConfig = require(ReplicatedStorage.Shared.Config.TelemetriaConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local TerrenoService = require(script.Parent.TerrenoService)

local MonsterService = {}
local rng = Random.new()
local sonido = Remotes.Crear(Remotes.Nombres.Sonido) -- fase 6: revelación/rapto

local cfg = Config.Etapa0.Doble
local NOMBRE_CLON = "ElDoble" -- ChatMimicService busca este nombre para posicionar su mimo
local MADRIGUERA_POS = Vector3.new(-60, 0, -60) -- compartida por todos los clones
local FRASES_SENUELO = { "estoy aquí, ven", "¿dónde estáis?" } -- §5.3
local TICK = 0.3
-- B14: 2–5 jugadores EnJuego -> 1 clon; 6–8 -> 2 (plan fase-11 §L6).
local JUGADORES_SEGUNDO_CLON = 6

local playerState -- PlayerStateService (se requiere en Iniciar, patrón de HazardService)
local chatMimic -- ChatMimicService si existe (pcall: sus señuelos son opcionales)
local telemetriaService

-- Estado por partida (una partida = un gestor + N bucles de clon).
local clones = {} -- lista de clonData activos de la partida en curso
local raptosTotales = 0 -- raptos COMPLETADOS compartidos por TODOS los clones
local reservadas = {} -- [player] = clonData que lo tiene como víctima ahora mismo
local siguienteIndice = 1 -- índice de clon para los prints ([Doble 1], [Doble 2])
local iniciado = false
local generacion = 0 -- token de partida: al cambiar, gestor y bucles viejos mueren

---------------------------------------------------------------- Líquidos ----

-- clonData: { indice, clon, victima, raptos, fase, aturdidoHasta, ahuyentarHasta,
-- promptRescate, ultimaVictima }.
local function limpiarClon(data)
	if data.promptRescate then
		data.promptRescate:Destroy()
		data.promptRescate = nil
	end
	-- Libera la reserva: el otro clon ya puede elegir a este jugador.
	if data.victima and reservadas[data.victima] == data then
		reservadas[data.victima] = nil
	end
	if data.clon then
		data.clon:Destroy()
		data.clon = nil
	end
	data.victima = nil
end

local function clonVivo(data)
	local clon = data.clon
	if not clon or not clon.Parent then
		return false
	end
	local hum = clon:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function buscarClon(clonModel)
	for _, data in clones do
		if data.clon == clonModel then
			return data
		end
	end
	return nil
end

local function hayAlguienEnJuego()
	for _, player in Players:GetPlayers() do
		if player.Parent and player:GetAttribute("EnJuego") then
			return true
		end
	end
	return false
end

-- Elegibles (§5.1): EnJuego y vivos. Los caídos están fuera de combate (§4.4).
local function enJuego()
	local lista = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		if raiz and hum and hum.Health > 0 and not playerState.EstaCaido(player)
			and player:GetAttribute("EnJuego") then
			table.insert(lista, { player = player, pos = raiz.Position })
		end
	end
	return lista
end

-- Aborto común de fases activas: clon destruido (limpieza externa) o partida vacía.
local function abortoFase(data)
	return not clonVivo(data) or not hayAlguienEnJuego()
end

-- Espera cancelable por partida. Devuelve (completo, cancelado): cancelado es
-- true cuando otra partida arrancó; el llamador debe salir sin tocar `fase`.
-- B13/B14: mientras el clon esté aturdido (y, en acecho, ahuyentado) el reloj
-- de la fase se detiene y no se avanza ni se camina.
local function esperar(data, gen, segundos, aborto, cadaTick, congelarExtra)
	local t = 0
	while t < segundos do
		local dt = task.wait(TICK)
		if gen ~= generacion then
			return false, true
		end
		if aborto and aborto() then
			return false, false
		end
		if os.clock() < data.aturdidoHasta or (congelarExtra and congelarExtra()) then
			continue
		end
		t += dt
		if cadaTick then
			cadaTick()
		end
	end
	return true, false
end

local function caminarHacia(data, pos)
	local hum = data.clon and data.clon:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum:MoveTo(pos)
	end
end

-- §5.3: línea de señuelo solo para la víctima, vía ChatMimicService si existe.
local function senuelo(data)
	if not (chatMimic and data.victima and data.victima.Parent) then
		return
	end
	local frase = FRASES_SENUELO[rng:NextInteger(1, #FRASES_SENUELO)]
	pcall(chatMimic.HablarComo, NOMBRE_CLON, frase, data.victima)
end

---------------------------------------------------------------- Escenario ----

-- Madriguera: cueva simple en L (suelo + dos paredes + techo), una sola vez.
-- Compartida: todos los clones arrastran a sus víctimas a la misma.
local function construirMadriguera()
	if workspace:FindFirstChild("MadrigueraDoble") then
		return
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = "MadrigueraDoble"
	local marron = Color3.fromRGB(58, 38, 24)
	local piezas = {
		{ "Suelo", Vector3.new(16, 1, 16), CFrame.new(-60, -0.5, -60) },
		{ "ParedA", Vector3.new(16, 7, 2), CFrame.new(-60, 3.5, -67) }, -- L: pared trasera
		{ "ParedB", Vector3.new(2, 7, 16), CFrame.new(-67, 3.5, -60) }, -- L: pared lateral
		{ "Techo", Vector3.new(16, 1, 16), CFrame.new(-60, 7.5, -60) },
	}
	for _, pieza in piezas do
		local parte = Instance.new("Part")
		parte.Name = "Madriguera_" .. pieza[1]
		parte.Size = pieza[2]
		parte.CFrame = pieza[3]
		parte.Color = marron
		parte.Material = Enum.Material.Slate
		parte.Anchored = true
		parte.Parent = carpeta
	end
	carpeta.Parent = workspace
end

------------------------------------------------------------------- Fases -----

local function cercaDelGrupo(data)
	local grupo = enJuego()
	local centro = Vector3.zero
	if #grupo > 0 then
		local suma = Vector3.zero
		for _, o in grupo do
			suma += o.pos
		end
		centro = suma / #grupo
	elseif data.victima and data.victima.Character then
		local raiz = data.victima.Character:FindFirstChild("HumanoidRootPart")
		centro = raiz and raiz.Position or centro
	end
	local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	offset = offset.Magnitude > 0.05 and offset.Unit or Vector3.new(1, 0, 0)
	local destino = centro + offset * 14
	local base = TerrenoService.AlturaSuelo(Vector3.new(destino.X, 0, destino.Z))
	return CFrame.new(destino.X, base + 3, destino.Z)
end

-- Copia el aspecto de la víctima (§5.2): Archivable + Clone, sin scripts.
local function clonarComo(jugador)
	local char = jugador.Character
	if not char or not char.Parent then
		return nil
	end
	char.Archivable = true
	local nuevo = char:Clone()
	if not nuevo then
		return nil
	end
	nuevo.Name = NOMBRE_CLON
	for _, obj in nuevo:GetDescendants() do
		-- Los scripts clonados se ejecutarían en workspace; sin prompts heredados.
		if obj:IsA("BaseScript") or obj:IsA("ProximityPrompt") then
			obj:Destroy()
		end
	end
	local hum = nuevo:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = cfg.VelocidadDoble
	end
	-- Ojos rojos (§5.3): dos esferas Neon soldadas a la cara, a la altura de los ojos.
	-- Neon pero con transparencia y tono apagado: se leen en la oscuridad sin deslumbrar.
	local cabeza = nuevo:FindFirstChild("Head")
	if cabeza then
		for _, ladoX in { -0.15, 0.15 } do
			local ojo = Instance.new("Part")
			ojo.Name = "OjoDoble"
			ojo.Shape = Enum.PartType.Ball
			ojo.Size = Vector3.new(0.13, 0.13, 0.13)
			ojo.Color = Color3.fromRGB(190, 20, 20)
			ojo.Material = Enum.Material.Neon
			ojo.Transparency = 0.2
			ojo.CanCollide = false
			ojo.CanQuery = false
			ojo.CanTouch = false
			ojo.Massless = true
			-- +0,02 en Z: apoyados en la cara, no dentro del casco.
			ojo.CFrame = cabeza.CFrame * CFrame.new(ladoX, cabeza.Size.Y * 0.28, -cabeza.Size.Z / 2 + 0.02)
			local soldadura = Instance.new("WeldConstraint")
			soldadura.Part0 = cabeza
			soldadura.Part1 = ojo
			soldadura.Parent = ojo
			ojo.Parent = cabeza
		end
	end
	return nuevo
end

local function observacion(data, gen)
	-- Víctima: EnJuego, viva, distinta de la anterior de ESTE clon y no
	-- reservada por OTRO clon (B14); si no hay, siguiente tick.
	data.victima = nil
	while not data.victima do
		if gen ~= generacion then
			return
		end
		local candidatos = {}
		for _, o in enJuego() do
			local reservadaPor = reservadas[o.player]
			if o.player ~= data.ultimaVictima and (reservadaPor == nil or reservadaPor == data) then
				table.insert(candidatos, o.player)
			end
		end
		if #candidatos > 0 then
			data.victima = candidatos[rng:NextInteger(1, #candidatos)]
		else
			task.wait(1)
		end
	end
	reservadas[data.victima] = data
	print("[Doble " .. data.indice .. "] fase 1: observando a " .. data.victima.Name)

	data.clon = clonarComo(data.victima)
	if not data.clon then
		data.fase = 5
		return
	end
	data.ultimaVictima = data.victima
	data.clon.Parent = workspace
	data.clon:PivotTo(cercaDelGrupo(data))
	local completo, cancelado = esperar(data, gen, cfg.DuracionObservacion, function()
		return abortoFase(data)
	end)
	if cancelado then
		return
	end
	data.fase = completo and 2 or 5
end

local function seguirGrupo(data)
	local grupo = enJuego()
	if #grupo == 0 then
		return
	end
	local suma = Vector3.zero
	for _, o in grupo do
		suma += o.pos
	end
	caminarHacia(data, suma / #grupo)
end

local function infiltracion(data, gen)
	print("[Doble " .. data.indice .. "] fase 2: infiltración en el grupo")
	local completo, cancelado = esperar(data, gen, cfg.DuracionInfiltracion, function()
		return abortoFase(data)
	end, function()
		seguirGrupo(data)
	end)
	if cancelado then
		return
	end
	data.fase = completo and 3 or 5
end

local function acercarseAVictima(data)
	local raiz = data.victima and data.victima.Character and data.victima.Character:FindFirstChild("HumanoidRootPart")
	if not (raiz and clonVivo(data)) then
		return
	end
	if (raiz.Position - data.clon:GetPivot().Position).Magnitude > 5 then
		caminarHacia(data, raiz.Position)
	end
end

local function acecho(data, gen)
	print("[Doble " .. data.indice .. "] fase 3: acechando a " .. (data.victima and data.victima.Name or "?"))
	senuelo(data)
	local completo, cancelado = esperar(data, gen, cfg.DuracionAcecho, function()
		return abortoFase(data)
	end, function()
		acercarseAVictima(data)
	end, function()
		return os.clock() < data.ahuyentarHasta -- B15: ahuyentado, el acecho espera
	end)
	if cancelado then
		return
	end
	data.fase = completo and 4 or 5
end

-- §5.2 fase 4 + §5.4: revela su forma, arrastra a la víctima a la madriguera
-- (simplificado con PivotTo de ambos) y abre la ventana de rescate.
local function rapto(data, gen)
	local charV = data.victima and data.victima.Character
	local humV = charV and charV:FindFirstChildOfClass("Humanoid")
	if not charV or not humV or humV.Health <= 0 or playerState.EstaCaido(data.victima) then
		data.fase = 5
		return
	end

	local revelado = Instance.new("Highlight")
	revelado.Name = "Revelado"
	revelado.FillColor = Color3.fromRGB(255, 0, 0)
	revelado.FillTransparency = 0.4
	revelado.OutlineColor = Color3.fromRGB(255, 60, 60)
	revelado.Parent = data.clon

	print("[Doble " .. data.indice .. "] rapto de " .. data.victima.Name)
	if telemetriaService then
		telemetriaService.Evento(data.victima, TelemetriaConfig.Eventos.Rapto)
	end
	-- Una vez por fase 4 (no está en el bucle de ticks): alarma para todos.
	sonido:FireAllClients({ id = "Monstruo", subtitulo = AudioConfig.Efectos.Monstruo.subtitulo })
	-- Derribo y arrastre (PivotTo de ambos) síncronos, antes del señuelo:
	-- HablarComo puede esperar (filtro) y la limpieza externa podría destruir el clon.
	playerState.Derribar(data.victima, "doble")
	charV:PivotTo(CFrame.new(MADRIGUERA_POS + Vector3.new(3, 3, 3)))
	data.clon:PivotTo(CFrame.new(MADRIGUERA_POS + Vector3.new(-2, 3, -2)))
	senuelo(data)
	if gen ~= generacion or not clonVivo(data) then
		return -- la partida terminó durante el filtro del señuelo
	end

	-- Rescate: "Liberar" (HoldDuration 1) en el clon, activado por OTRO jugador.
	local raizClon = data.clon:FindFirstChild("HumanoidRootPart") or data.clon:FindFirstChildWhichIsA("BasePart")
	data.promptRescate = Instance.new("ProximityPrompt")
	data.promptRescate.Name = "Liberar"
	data.promptRescate.ActionText = "Liberar"
	data.promptRescate.ObjectText = "El Doble"
	data.promptRescate.HoldDuration = 1
	data.promptRescate.RequiresLineOfSight = false
	data.promptRescate.Parent = raizClon
	local liberador = nil
	data.promptRescate.Triggered:Connect(function(quien)
		if quien and quien ~= data.victima and quien.Parent then
			liberador = quien
		end
	end)

	local expiro, cancelado = esperar(data, gen, cfg.VentanaRescate, function()
		return liberador ~= nil or not clonVivo(data) or not hayAlguienEnJuego()
			or not data.victima or not data.victima.Parent
	end)
	if cancelado then
		return -- limpiarClon ya destruyó el prompt y el clon
	end
	if data.promptRescate then
		data.promptRescate:Destroy()
		data.promptRescate = nil
	end

	if liberador and data.victima and data.victima.Parent then
		playerState.Reanimar(data.victima, liberador)
		print("[Doble " .. data.indice .. "] " .. data.victima.Name .. " liberada por " .. liberador.Name)
	elseif expiro and data.victima and data.victima.Parent then
		-- Ventana expirada: rapto completado; la víctima sigue caída en la
		-- madriguera con SU cuenta atrás normal (PlayerStateService, no el Doble).
		-- Tope compartido (B14): si el otro clon agotó el máximo durante esta
		-- ventana, el rapto no supera el tope (la víctima sigue capturada igual).
		if raptosTotales < cfg.MaxRaptos then
			raptosTotales += 1
		end
		data.raptos += 1
	end
	-- Aborto (clon o víctima desaparecieron): no cuenta como rapto.
	data.fase = 5
end

local function retirada(data, gen)
	limpiarClon(data)
	print("[Doble " .. data.indice .. "] retirada (raptos " .. raptosTotales .. "/" .. cfg.MaxRaptos .. ")")
	local _, cancelado = esperar(data, gen, cfg.EnfriamientoRetirada)
	if cancelado then
		return
	end
	-- Tope COMPARTIDO (B14): MaxRaptos es el total de ambos clones.
	if raptosTotales >= cfg.MaxRaptos then
		data.fase = 6
	else
		data.fase = 1
	end
end

-- B13/B14: con el clon aturdido, su hilo de fases espera sin avanzar.
local function esperarAturdimiento(data, gen)
	while os.clock() < data.aturdidoHasta do
		task.wait(TICK)
		if gen ~= generacion then
			return
		end
	end
end

-- Bucle de fases POR CLON (B14): mismo flujo 1..5 que antes, sobre clonData.
local function bucleClon(data, gen)
	data.fase = 1
	while data.fase >= 1 and data.fase <= 5 do
		if gen ~= generacion then
			return -- nueva partida: el hilo viejo muere en silencio (limpieza externa)
		end
		-- Tope compartido agotado: este clon también termina (sin rapto extra).
		if data.fase ~= 5 and raptosTotales >= cfg.MaxRaptos then
			data.fase = 6
			break
		end
		esperarAturdimiento(data, gen)
		if gen ~= generacion then
			return
		end
		if data.fase == 1 then
			observacion(data, gen)
		elseif data.fase == 2 then
			infiltracion(data, gen)
		elseif data.fase == 3 then
			acecho(data, gen)
		elseif data.fase == 4 then
			rapto(data, gen)
		elseif data.fase == 5 then
			retirada(data, gen)
		end
	end
	-- Salida normal (fase 6): limpia modelo/reserva y deja libre la plaza.
	limpiarClon(data)
	local i = table.find(clones, data)
	if i then
		table.remove(clones, i)
	end
	print("[Doble " .. data.indice .. "] fin: máximo de raptos (" .. raptosTotales .. "/" .. cfg.MaxRaptos .. ") alcanzado")
end

--------------------------------------------------------------- Gestor -------

-- Lanza un clon de la partida en curso con su propio bucle de fases.
local function lanzarClon(gen)
	if raptosTotales >= cfg.MaxRaptos then
		return
	end
	local data = {
		indice = siguienteIndice,
		clon = nil,
		victima = nil,
		raptos = 0,
		fase = 1,
		aturdidoHasta = 0,
		ahuyentarHasta = 0,
		promptRescate = nil,
		ultimaVictima = nil,
	}
	siguienteIndice += 1
	table.insert(clones, data)
	task.spawn(bucleClon, data, gen)
end

-- Una partida = un gestor. Fase 0 compartida: el retardo de aparición cuenta
-- solo con jugadores EnJuego (§5.1) y es el MISMO para ambos clones. Después
-- vigila el conteo: al cruzar de 5 a 6 EnJuego lanza el segundo clon (el
-- primero no se destruye; bajar de 6 no retira nada).
local function gestor(gen)
	local acumulado = 0
	while acumulado < cfg.RetardoAparicion do
		task.wait(1)
		if gen ~= generacion then
			return
		end
		if #enJuego() > 0 then
			acumulado += 1
		end
	end
	if gen ~= generacion then
		return
	end
	lanzarClon(gen)
	while gen == generacion do
		task.wait(1)
		if gen ~= generacion then
			return
		end
		if #clones < 2 and #enJuego() >= JUGADORES_SEGUNDO_CLON then
			lanzarClon(gen)
		end
	end
end

--------------------------------------------------------------------- API -----

-- B14: número de clones activos (bucles de fases en marcha) de la partida.
function MonsterService.ContarClones()
	return #clones
end

-- B13 (bengala) / B14: congela el clon dado durante `segundos` (WalkSpeed 0,
-- MoveTo cancelado, sin rapto: su hilo de fases espera). Marca visual breve.
function MonsterService.Aturdir(clonModel, segundos)
	if type(segundos) ~= "number" or segundos <= 0 then
		return false
	end
	local data = buscarClon(clonModel)
	if not data or not clonVivo(data) then
		return false
	end
	data.aturdidoHasta = math.max(data.aturdidoHasta, os.clock() + segundos)
	local hum = data.clon:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		local raiz = data.clon:FindFirstChild("HumanoidRootPart") or data.clon:FindFirstChildWhichIsA("BasePart")
		if raiz then
			hum:MoveTo(raiz.Position) -- cancela el MoveTo en curso
		end
	end
	if not data.clon:FindFirstChild("Aturdido") then
		local destacado = Instance.new("Highlight")
		destacado.Name = "Aturdido"
		destacado.FillColor = Color3.fromRGB(70, 130, 255)
		destacado.FillTransparency = 0.45
		destacado.OutlineColor = Color3.fromRGB(130, 180, 255)
		destacado.Parent = data.clon
	end
	-- Restauración con token: solo el ÚLTIMO aturdimiento suelta el clon.
	data.aturdidoToken = (data.aturdidoToken or 0) + 1
	local token = data.aturdidoToken
	task.spawn(function()
		while os.clock() < data.aturdidoHasta do
			task.wait(TICK)
		end
		if token ~= data.aturdidoToken or not data.clon or not data.clon.Parent then
			return
		end
		data.aturdidoHasta = 0
		local marcado = data.clon:FindFirstChild("Aturdido")
		if marcado then
			marcado:Destroy()
		end
		local hum = data.clon:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.WalkSpeed = cfg.VelocidadDoble
		end
	end)
	return true
end

-- B15 (linterna) / B14: el clon retrocede 15 studs y su hilo de acecho espera
-- 3 s. No muere ni se aturde: solo retrocede.
function MonsterService.Ahuyentar(clonModel)
	local data = buscarClon(clonModel)
	if not data or not clonVivo(data) then
		return false
	end
	local pivot = data.clon:GetPivot()
	local destino = pivot.Position - pivot.LookVector * 15
	local base = TerrenoService.AlturaSuelo(Vector3.new(destino.X, 0, destino.Z))
	caminarHacia(data, Vector3.new(destino.X, base + 3, destino.Z))
	data.ahuyentarHasta = os.clock() + 3
	return true
end

function MonsterService.Iniciar()
	if iniciado then
		return
	end
	iniciado = true

	playerState = require(script.Parent.PlayerStateService)
	telemetriaService = require(script.Parent.TelemetriaService)
	local okChat, modChat = pcall(require, script.Parent.ChatMimicService)
	if okChat then
		chatMimic = modChat -- §5.3: señuelos; si el servicio aún no existe, seguimos sin él
	end

	construirMadriguera()

	-- Limpieza si la víctima se va: la fase de ESE clon aborta sola y su
	-- reserva se libera.
	Players.PlayerRemoving:Connect(function(player)
		for _, data in clones do
			if data.victima == player then
				limpiarClon(data)
			end
		end
		reservadas[player] = nil
	end)

	-- Una partida = un gestor. Al empezar otra, el token invalida el gestor y
	-- los bucles de clones anteriores.
	local matchService = require(script.Parent.MatchService)
	matchService.AlEmpezar.Event:Connect(function()
		generacion += 1
		for _, data in clones do
			limpiarClon(data)
		end
		clones = {}
		reservadas = {}
		raptosTotales = 0
		siguienteIndice = 1
		local gen = generacion
		task.spawn(function()
			gestor(gen)
		end)
	end)
	matchService.AlTerminarPartida.Event:Connect(function()
		generacion += 1
		for _, data in clones do
			limpiarClon(data)
		end
		clones = {}
		reservadas = {}
	end)

	-- B15 (linterna, GANCHO_DELATE): receptor de LinternaAim. El cliente envía
	-- la dirección de su haz a 5 Hz (limitado con RateLimiter a la misma
	-- cadencia); el servidor valida el payload y al empujador (EnJuego, vivo,
	-- no caído, con Head) y, para cada clon activo a ≤25 studs cuyo ángulo con
	-- la dirección sea ≤35° (producto punto ≥ cos 35°, plan §5.3), lo ahuyenta.
	-- El Doble nunca muere (§5.4): Ahuyentar solo lo hace retroceder. Todo en
	-- pcall; el bucle de fases del refactor B14 no se toca.
	local permitirHaz = RateLimiter.nuevo(0.2)
	local COS_CONO = math.cos(math.rad(35)) -- cono de delate, más estricto que el haz visual (46°)
	local ALCANCE_DELATE = 25 -- criterio B15: «haz a 25 studs lo ahuyenta»
	Remotes.Crear(Remotes.Nombres.LinternaAim).OnServerEvent:Connect(function(player, datos)
		local ok, err = pcall(function()
			if not permitirHaz(player) then
				return
			end
			if typeof(datos) ~= "table" or typeof(datos.direccion) ~= "Vector3"
				or datos.direccion.Magnitude < 1e-6 then
				return
			end
			if player:GetAttribute("EnJuego") ~= true or playerState.EstaCaido(player) then
				return
			end
			local char = player.Character
			local cabeza = char and char:FindFirstChild("Head")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (cabeza and hum and hum.Health > 0) then
				return
			end
			local direccion = datos.direccion.Unit
			for _, data in clones do
				-- ahuyentarHasta evita repetir el retroceso (y el print) cada
				-- tick mientras el haz se mantiene sobre el clon (ventana 3 s).
				if clonVivo(data) and os.clock() >= data.ahuyentarHasta then
					local hacia = data.clon:GetPivot().Position - cabeza.Position
					if hacia.Magnitude > 1e-6 and hacia.Magnitude <= ALCANCE_DELATE
						and hacia.Unit:Dot(direccion) >= COS_CONO
						and MonsterService.Ahuyentar(data.clon) then
						print("[Doble] ahuyentado por la linterna de " .. player.Name)
					end
				end
			end
		end)
		if not ok then
			warn("[Doble] receptor linterna: " .. tostring(err))
		end
	end)

	print("[Doble] servicio iniciado (aparece tras " .. cfg.RetardoAparicion .. " s de partida)")
end

return MonsterService
