-- MonsterService: El Doble, el monstruo que imita (plan §5).
-- Fases (§5.2): 0 Latente -> 1 Observación -> 2 Infiltración -> 3 Acecho ->
-- 4 Rapto -> 5 Retirada -> 1 ... hasta Config.Doble.MaxRaptos.
-- Servidor autoritativo. Una sola aparición activa por partida (§5.1) y el
-- Doble NUNCA mata (§5.4): la víctima queda caída con su cuenta atrás normal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TelemetriaConfig = require(ReplicatedStorage.Shared.Config.TelemetriaConfig)
local TerrenoService = require(script.Parent.TerrenoService)

local MonsterService = {}
local rng = Random.new()
local sonido = Remotes.Crear(Remotes.Nombres.Sonido) -- fase 6: revelación/rapto

local cfg = Config.Etapa0.Doble
local NOMBRE_CLON = "ElDoble" -- ChatMimicService busca este nombre para posicionar su mimo
local MADRIGUERA_POS = Vector3.new(-60, 0, -60)
local FRASES_SENUELO = { "estoy aquí, ven", "¿dónde estáis?" } -- §5.3
local TICK = 0.3

local playerState -- PlayerStateService (se requiere en Iniciar, patrón de HazardService)
local chatMimic -- ChatMimicService si existe (pcall: sus señuelos son opcionales)
local telemetriaService

local fase = 0 -- 0 Latente, 1..5 fases activas, 6 fin
local clon -- Model de El Doble; nunca hay más de uno activo (§5.1)
local victima -- Player elegido en Observación
local ultimaVictima -- NUNCA la misma dos veces seguidas (§5.2)
local raptos = 0 -- raptos COMPLETADOS (ventana de rescate expirada)
local promptRescate
local iniciado = false
local generacion = 0 -- token de partida: al cambiar, los bucles y esperas viejos mueren

---------------------------------------------------------------- Líquidos ----

local function limpiarClon()
	if promptRescate then
		promptRescate:Destroy()
		promptRescate = nil
	end
	if clon then
		clon:Destroy()
		clon = nil
	end
	victima = nil
end

local function clonVivo()
	if not clon or not clon.Parent then
		return false
	end
	local hum = clon:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
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
local function abortoFase()
	return not clonVivo() or not hayAlguienEnJuego()
end

-- Espera cancelable por partida. Devuelve (completo, cancelado): cancelado es
-- true cuando otra partida arrancó; el llamador debe salir sin tocar `fase`.
local function esperar(gen, segundos, aborto, cadaTick)
	local t = 0
	while t < segundos do
		t += task.wait(TICK)
		if gen ~= generacion then
			return false, true
		end
		if cadaTick then
			cadaTick()
		end
		if aborto and aborto() then
			return false, false
		end
	end
	return true, false
end

local function caminarHacia(pos)
	local hum = clon and clon:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum:MoveTo(pos)
	end
end

-- §5.3: línea de señuelo solo para la víctima, vía ChatMimicService si existe.
local function senuelo()
	if not (chatMimic and victima and victima.Parent) then
		return
	end
	local frase = FRASES_SENUELO[rng:NextInteger(1, #FRASES_SENUELO)]
	pcall(chatMimic.HablarComo, NOMBRE_CLON, frase, victima)
end

---------------------------------------------------------------- Escenario ----

-- Madriguera: cueva simple en L (suelo + dos paredes + techo), una sola vez.
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

local function cercaDelGrupo()
	local grupo = enJuego()
	local centro = Vector3.zero
	if #grupo > 0 then
		local suma = Vector3.zero
		for _, o in grupo do
			suma += o.pos
		end
		centro = suma / #grupo
	elseif victima and victima.Character then
		local raiz = victima.Character:FindFirstChild("HumanoidRootPart")
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

local function observacion(gen)
	-- Víctima: EnJuego, viva y distinta de la anterior; si no hay, siguiente tick.
	victima = nil
	while not victima do
		if gen ~= generacion then
			return
		end
		local candidatos = {}
		for _, o in enJuego() do
			if o.player ~= ultimaVictima then
				table.insert(candidatos, o.player)
			end
		end
		if #candidatos > 0 then
			victima = candidatos[rng:NextInteger(1, #candidatos)]
		else
			task.wait(1)
		end
	end
	print("[Doble] fase 1: observando a " .. victima.Name)

	clon = clonarComo(victima)
	if not clon then
		fase = 5
		return
	end
	ultimaVictima = victima
	clon.Parent = workspace
	clon:PivotTo(cercaDelGrupo())
	local completo, cancelado = esperar(gen, cfg.DuracionObservacion, abortoFase)
	if cancelado then
		return
	end
	fase = completo and 2 or 5
end

local function seguirGrupo()
	local grupo = enJuego()
	if #grupo == 0 then
		return
	end
	local suma = Vector3.zero
	for _, o in grupo do
		suma += o.pos
	end
	caminarHacia(suma / #grupo)
end

local function infiltracion(gen)
	print("[Doble] fase 2: infiltración en el grupo")
	local completo, cancelado = esperar(gen, cfg.DuracionInfiltracion, abortoFase, seguirGrupo)
	if cancelado then
		return
	end
	fase = completo and 3 or 5
end

local function acercarseAVictima()
	local raiz = victima and victima.Character and victima.Character:FindFirstChild("HumanoidRootPart")
	if not (raiz and clonVivo()) then
		return
	end
	if (raiz.Position - clon:GetPivot().Position).Magnitude > 5 then
		caminarHacia(raiz.Position)
	end
end

local function acecho(gen)
	print("[Doble] fase 3: acechando a " .. (victima and victima.Name or "?"))
	senuelo()
	local completo, cancelado = esperar(gen, cfg.DuracionAcecho, abortoFase, acercarseAVictima)
	if cancelado then
		return
	end
	fase = completo and 4 or 5
end

-- §5.2 fase 4 + §5.4: revela su forma, arrastra a la víctima a la madriguera
-- (simplificado con PivotTo de ambos) y abre la ventana de rescate.
local function rapto(gen)
	local charV = victima and victima.Character
	local humV = charV and charV:FindFirstChildOfClass("Humanoid")
	if not charV or not humV or humV.Health <= 0 or playerState.EstaCaido(victima) then
		fase = 5
		return
	end

	local revelado = Instance.new("Highlight")
	revelado.Name = "Revelado"
	revelado.FillColor = Color3.fromRGB(255, 0, 0)
	revelado.FillTransparency = 0.4
	revelado.OutlineColor = Color3.fromRGB(255, 60, 60)
	revelado.Parent = clon

	print("[Doble] rapto de " .. victima.Name)
	if telemetriaService then
		telemetriaService.Evento(victima, TelemetriaConfig.Eventos.Rapto)
	end
	-- Una vez por fase 4 (no está en el bucle de ticks): alarma para todos.
	sonido:FireAllClients({ id = "Monstruo", subtitulo = AudioConfig.Efectos.Monstruo.subtitulo })
	-- Derribo y arrastre (PivotTo de ambos) síncronos, antes del señuelo:
	-- HablarComo puede esperar (filtro) y la limpieza externa podría destruir el clon.
	playerState.Derribar(victima, "doble")
	charV:PivotTo(CFrame.new(MADRIGUERA_POS + Vector3.new(3, 3, 3)))
	clon:PivotTo(CFrame.new(MADRIGUERA_POS + Vector3.new(-2, 3, -2)))
	senuelo()
	if gen ~= generacion or not clonVivo() then
		return -- la partida terminó durante el filtro del señuelo
	end

	-- Rescate: "Liberar" (HoldDuration 1) en el clon, activado por OTRO jugador.
	local raizClon = clon:FindFirstChild("HumanoidRootPart") or clon:FindFirstChildWhichIsA("BasePart")
	promptRescate = Instance.new("ProximityPrompt")
	promptRescate.Name = "Liberar"
	promptRescate.ActionText = "Liberar"
	promptRescate.ObjectText = "El Doble"
	promptRescate.HoldDuration = 1
	promptRescate.RequiresLineOfSight = false
	promptRescate.Parent = raizClon
	local liberador = nil
	promptRescate.Triggered:Connect(function(quien)
		if quien and quien ~= victima and quien.Parent then
			liberador = quien
		end
	end)

	local expiro, cancelado = esperar(gen, cfg.VentanaRescate, function()
		return liberador ~= nil or not clonVivo() or not hayAlguienEnJuego()
			or not victima or not victima.Parent
	end)
	if cancelado then
		return -- limpiarClon ya destruyó el prompt y el clon
	end
	if promptRescate then
		promptRescate:Destroy()
		promptRescate = nil
	end

	if liberador and victima and victima.Parent then
		playerState.Reanimar(victima, liberador)
		print("[Doble] " .. victima.Name .. " liberada por " .. liberador.Name)
	elseif expiro and victima and victima.Parent then
		-- Ventana expirada: rapto completado; la víctima sigue caída en la
		-- madriguera con SU cuenta atrás normal (PlayerStateService, no el Doble).
		raptos += 1
	end
	-- Aborto (clon o víctima desaparecieron): no cuenta como rapto.
	fase = 5
end

local function retirada(gen)
	limpiarClon()
	print("[Doble] retirada (raptos " .. raptos .. "/" .. cfg.MaxRaptos .. ")")
	local _, cancelado = esperar(gen, cfg.EnfriamientoRetirada)
	if cancelado then
		return
	end
	if raptos >= cfg.MaxRaptos then
		fase = 6
	else
		fase = 1
	end
end

local function bucle(gen)
	-- Fase 0 (Latente): no existe; el retardo solo cuenta con jugadores EnJuego (§5.1).
	local acumulado = 0
	while acumulado < cfg.RetardoAparicion and fase == 0 do
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
	if fase == 0 then
		fase = 1
	end

	while fase >= 1 and fase <= 5 do
		if gen ~= generacion then
			return
		end
		if fase == 1 then
			observacion(gen)
		elseif fase == 2 then
			infiltracion(gen)
		elseif fase == 3 then
			acecho(gen)
		elseif fase == 4 then
			rapto(gen)
		elseif fase == 5 then
			retirada(gen)
		end
	end

	print("[Doble] fin: máximo de raptos (" .. raptos .. "/" .. cfg.MaxRaptos .. ") alcanzado")
end

--------------------------------------------------------------------- API -----

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

	-- Limpieza total si la víctima se va: la fase en curso aborta sola.
	Players.PlayerRemoving:Connect(function(player)
		if player == victima then
			limpiarClon()
		end
	end)

	-- Una partida = un hilo. Al empezar otra, el token invalida el hilo anterior
	-- (antes el Doble aparecía una sola vez por servidor, no por partida).
	local matchService = require(script.Parent.MatchService)
	matchService.AlEmpezar.Event:Connect(function()
		generacion += 1
		limpiarClon()
		fase = 0
		raptos = 0
		ultimaVictima = nil
		local gen = generacion
		task.spawn(function()
			bucle(gen)
		end)
	end)
	matchService.AlTerminarPartida.Event:Connect(function()
		generacion += 1
		limpiarClon()
		fase = 0
	end)

	print("[Doble] servicio iniciado (aparece tras " .. cfg.RetardoAparicion .. " s de partida)")
end

return MonsterService
