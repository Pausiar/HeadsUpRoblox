-- CargarService (B9, fase 11 · L5): cargar compañeros caídos por la ruta.
-- Servidor autoritativo (plan §3.3): validación, arrastre y cancelaciones viven
-- aquí; el cliente solo envía la intención por el remote Cargar y pinta estado.
--
-- Estado: porte[portador] = objetivo y cargadoPor[objetivo] = portador
-- (PortadoresMax = 1 hoy; el recuento de porteadores ya admite 2 más adelante,
-- pero cargadoPor sigue siendo único: el arrastre pivotarían dos portadores).
--
-- Decisiones documentadas:
--  - El Doble (MonsterService) no expone a su víctima; "en rescate" se detecta
--    con lo observable: prompt "Liberar" activo en el clon + víctima a ≤20 studs
--    del clon. (Además el Doble nunca elige caídos como víctima, §5.1.)
--  - PlayerStateService.Reanimar llama a CancelarSiPorta con un require
--    perezoso dentro de la función: rompe el ciclo de requires sin Bindable.
--  - EstaminaService escribe WalkSpeed a 10 Hz (16/24): mientras dura el porte
--    este servicio la reimpone cada Heartbeat; al acabar no vuelve a tocarla y
--    EstaminaService retoma el control en su siguiente tick.
--  - Riesgo residual de física cliente (igual que E43): el exploit solo mueve
--    a su propio personaje; el objetivo lo coloca siempre el servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local Ajustes = Config.Etapa0.Cargar
local CLON = "ElDoble" -- MonsterService.NOMBRE_CLON (no exportado; sincronizado a mano)
-- Constantes migradas a Config (deuda del lote L5 cerrada): Detras, AlejamientoRapto,
-- RadioRescate y RitmoPrompts viven ahora en Config.Etapa0.Cargar.

local CargarService = {}
local iniciado = false
local porte = {} -- [portador (Player)] = objetivo (Player)
local cargadoPor = {} -- [objetivo (Player)] = portador (Player); uno por objetivo

local remotoCargar, remotoEstado
local permitirAccion
local playerState

------------------------------------------------------------------ Helpers ----

local function raizDe(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if raiz and hum and hum.Health > 0 then
		return raiz, hum
	end
	return nil, nil
end

local function promptDe(player, nombre)
	local char = player.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	return raiz and raiz:FindFirstChild(nombre) or nil
end

local function publicar(portador, objetivo)
	remotoEstado:FireAllClients({
		portador = portador and portador.Name or nil,
		objetivo = objetivo and objetivo.Name or nil,
	})
end

-- La víctima en la ventana de rescate del Doble: prompt "Liberar" activo en el
-- clon y la víctima potencial al lado. MonsterService no marca a su víctima
-- con nada observable; esto es el mejor detector sin tocar ese servicio.
local function estaEnRescate(objetivo)
	local clon = workspace:FindFirstChild(CLON)
	if not clon or not clon:FindFirstChild("Liberar", true) then
		return false
	end
	local raizClon = clon:FindFirstChild("HumanoidRootPart") or clon:FindFirstChildWhichIsA("BasePart")
	local raizObj = objetivo.Character and objetivo.Character:FindFirstChild("HumanoidRootPart")
	if not (raizClon and raizObj) then
		return false
	end
	return (raizClon.Position - raizObj.Position).Magnitude <= Ajustes.RadioRescateDoble
end

------------------------------------------------------------------ Fin porte --

-- Único punto de salida del porte: limpia, restaura y publica. `motivo` es
-- "soltar" o la causa de cancelación (va al print).
local function acabar(portador, motivo)
	local objetivo = porte[portador]
	if not objetivo then
		return
	end
	porte[portador] = nil
	if cargadoPor[objetivo] == portador then
		cargadoPor[objetivo] = nil
	end

	local soltar = promptDe(portador, "Soltar")
	if soltar then
		soltar:Destroy()
	end

	-- El objetivo sigue caído: reactiva sus prompts; si ya no lo está,
	-- PlayerStateService ya quitó "Reanimar" y aquí retiramos "Cargar".
	if playerState.EstaCaido(objetivo) then
		for _, nombre in { "Reanimar", "Cargar" } do
			local prompt = promptDe(objetivo, nombre)
			if prompt then
				prompt.Enabled = true
			end
		end
	else
		local cargarPrompt = promptDe(objetivo, "Cargar")
		if cargarPrompt then
			cargarPrompt:Destroy()
		end
	end

	-- Restaurar 16 solo si el portador sigue en pie: si acabó de caer,
	-- PlayerStateService manda (WalkSpeed 0) y no se lo pisamos.
	local _, humP = raizDe(portador)
	if humP and not playerState.EstaCaido(portador) then
		humP.WalkSpeed = Config.Estamina.VelocidadBase
	end

	publicar(portador, nil)
	if motivo == "soltar" then
		print("[Cargar] " .. portador.Name .. " suelta a " .. objetivo.Name)
	else
		print("[Cargar] porte cancelado (" .. motivo .. ")")
	end
end

-- Guarda pública para PlayerStateService (Reanimar) y CharacterRemoving:
-- si alguien está cargando a `objetivo`, el porte termina antes.
function CargarService.CancelarSiPorta(objetivo, motivo)
	local portador = objetivo and cargadoPor[objetivo]
	if portador then
		acabar(portador, motivo or "objetivo reanimado")
	end
end

------------------------------------------------------------------- Cargar ----

local function cargar(portador, objetivo)
	if portador == objetivo or porte[portador] or cargadoPor[portador] then
		return
	end
	if portador:GetAttribute("EnJuego") ~= true or objetivo:GetAttribute("EnJuego") ~= true then
		return
	end
	if playerState.EstaCaido(portador) or not playerState.EstaCaido(objetivo) then
		return
	end
	-- Porteadores del objetivo: PortadoresMax (1 hoy; escaneo listo para 2).
	local porteadores = 0
	for _, o in porte do
		if o == objetivo then
			porteadores += 1
		end
	end
	if porteadores >= Ajustes.PortadoresMax or cargadoPor[objetivo] then
		return
	end
	if estaEnRescate(objetivo) then
		return
	end
	local raizP, humP = raizDe(portador)
	local raizO = raizDe(objetivo)
	if not (raizP and raizO) then
		return
	end
	if (raizP.Position - raizO.Position).Magnitude > Ajustes.RadioCarga then
		return
	end

	porte[portador] = objetivo
	cargadoPor[objetivo] = portador
	humP.WalkSpeed = Ajustes.VelocidadPortador

	-- No se reanima mientras se carga: prompts del objetivo fuera de servicio.
	for _, nombre in { "Reanimar", "Cargar" } do
		local prompt = promptDe(objetivo, nombre)
		if prompt then
			prompt.Enabled = false
		end
	end

	-- Soltar con prompt sobre el propio portador (solo él puede accionarlo).
	local promptSoltar = Instance.new("ProximityPrompt")
	promptSoltar.Name = "Soltar"
	promptSoltar.ActionText = "Soltar"
	promptSoltar.ObjectText = objetivo.DisplayName
	promptSoltar.HoldDuration = 0
	promptSoltar.MaxActivationDistance = Ajustes.RadioCarga
	promptSoltar.RequiresLineOfSight = false
	promptSoltar.Triggered:Connect(function(quien)
		if quien == portador and porte[portador] == objetivo then
			acabar(portador, "soltar")
		end
	end)
	promptSoltar.Parent = raizP

	publicar(portador, objetivo)
	print("[Cargar] " .. portador.Name .. " carga a " .. objetivo.Name)
end

------------------------------------------------------------------- Latido ----

-- Arrastre y cancelaciones por frame. El objetivo sigue caído (PlatformStand
-- intacto): solo se le coloca detrás del portador en el plano horizontal y su
-- altura sigue siendo física.
local function latido()
	for portador, objetivo in porte do
		local raizP, humP = raizDe(portador)
		if not raizP or playerState.EstaCaido(portador) then
			acabar(portador, "portador caído o sin personaje")
			continue
		end
		if portador:GetAttribute("EnJuego") ~= true then
			acabar(portador, "fuera de partida")
			continue
		end
		local raizO = raizDe(objetivo)
		if not raizO or not playerState.EstaCaido(objetivo) then
			acabar(portador, "objetivo ya no está caído")
			continue
		end
		-- Rapto/teleport externo: el Doble hace PivotTo de la víctima a la
		-- madriguera; se comprueba ANTES del snap para no deshacer el rapto.
		if (raizO.Position - raizP.Position).Magnitude > Ajustes.AlejamientoRapto then
			acabar(portador, "objetivo alejado de golpe (rapto o teleport)")
			continue
		end

		local detras = raizP.CFrame * CFrame.new(0, 0, Ajustes.Detras)
		local nueva = CFrame.new(detras.X, raizO.Position.Y, detras.Z) * raizO.CFrame.Rotation
		objetivo.Character:PivotTo(nueva)

		-- Velocidad reducida: EstaminaService la sobreescribe a 10 Hz; se mantiene.
		humP.WalkSpeed = Ajustes.VelocidadPortador
	end
end

-- Prompt "Cargar" sobre cada caído: aparece en cuanto lo detecta la barrida y
-- desaparece al revive/morir/respawn. El prompt de reanimar lo crea
-- PlayerStateService en Derribar; este es el segundo, gestionado aquí.
local function asegurarPromptCargar(player)
	local char = player.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end
	local prompt = raiz:FindFirstChild("Cargar")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Cargar"
		prompt.ActionText = "Cargar"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Ajustes.RadioCarga
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(quien)
			if quien and quien ~= player and permitirAccion(quien) then
				cargar(quien, player)
			end
		end)
		prompt.Parent = raiz
	end
	prompt.Enabled = true
end

local function mantenerPrompts()
	for _, player in ipairs(Players:GetPlayers()) do
		local prompt = promptDe(player, "Cargar")
		if playerState.EstaCaido(player) then
			if not cargadoPor[player] then
				asegurarPromptCargar(player)
			end
			-- cargado: el prompt existe deshabilitado; no se toca.
		elseif prompt then
			prompt:Destroy()
		end
	end
end

--------------------------------------------------------------------- API -----

function CargarService.Iniciar()
	if iniciado then
		return
	end
	iniciado = true

	playerState = require(script.Parent.PlayerStateService) -- patrón MonsterService
	remotoCargar = Remotes.Crear(Remotes.Nombres.Cargar)
	remotoEstado = Remotes.Crear(Remotes.Nombres.CargarEstado)
	permitirAccion = RateLimiter.nuevo(Ajustes.Enfriamiento)

	remotoCargar.OnServerEvent:Connect(function(player, datos)
		if type(datos) ~= "table" or not permitirAccion(player) then
			return
		end
		local accion = datos.accion
		local idObjetivo = datos.objetivo
		if accion ~= "cargar" and accion ~= "soltar" then
			return
		end
		if type(idObjetivo) ~= "number" then
			return
		end
		local objetivo
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == idObjetivo then
				objetivo = p
				break
			end
		end
		if not objetivo then
			return
		end
		if accion == "cargar" then
			cargar(player, objetivo)
		elseif porte[player] == objetivo then
			acabar(player, "soltar") -- solo el portador, y del objetivo indicado
		end
	end)

	local function alEntrar(player)
		player.CharacterRemoving:Connect(function()
			if porte[player] then
				acabar(player, "portador respawneó")
			end
			CargarService.CancelarSiPorta(player, "objetivo respawneó")
		end)
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, player in ipairs(Players:GetPlayers()) do
		alEntrar(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if porte[player] then
			acabar(player, "portador se fue")
		end
		CargarService.CancelarSiPorta(player, "objetivo se fue")
		porte[player] = nil
		cargadoPor[player] = nil
	end)

	RunService.Heartbeat:Connect(latido)
	task.spawn(function()
		while true do
			task.wait(Ajustes.RitmoPrompts)
			mantenerPrompts()
		end
	end)

	print("[Cargar] servicio iniciado (radio " .. Ajustes.RadioCarga
		.. ", velocidad " .. Ajustes.VelocidadPortador
		.. ", portadores " .. Ajustes.PortadoresMax .. ")")
end

return CargarService
