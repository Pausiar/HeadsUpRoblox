-- Estamina autoritativa (E43, plan §3.3): el servidor lleva el drenaje, la
-- regeneración y la WalkSpeed; el cliente solo pide sprint y pinta el estado.
--
-- Riesgo residual: la física del personaje pertenece al cliente, así que un
-- exploit puede fijar su propia WalkSpeed local sin que el servidor lo impida.
-- Mitigación: MatchService limita el progreso de ruta a 32 studs/s (el sprint
-- real son 24), de modo que el exceso no cobra checkpoints ni meta.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local Ajustes = Config.Estamina

local EstaminaService = {}
local estados = {} -- [player] = { valor, esprintando, bloqueado, enviado }

local remotoEstado
local permitirSprint
local playerState
local renacer -- asignado en Iniciar() con pcall; nil = drenaje sin renacimiento

local function humano(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return hum
	end
	return nil
end

local function publicar(player, st)
	local valor = math.floor(st.valor * 10 + 0.5) / 10
	local enviado = st.enviado
	if
		enviado
		and enviado.valor == valor
		and enviado.esprintando == st.esprintando
		and enviado.bloqueado == st.bloqueado
	then
		return
	end
	st.enviado = { valor = valor, esprintando = st.esprintando, bloqueado = st.bloqueado }
	remotoEstado:FireClient(player, {
		estamina = valor,
		max = Ajustes.Max,
		esprintando = st.esprintando,
		bloqueado = st.bloqueado,
	})
end

local function simular(player, st, dt)
	local hum = humano(player)
	if not hum or hum.PlatformStand or playerState.EstaCaido(player) then
		-- Caído o sin personaje: la estamina se congela y se conserva la intención,
		-- igual que hacía el cliente (si sigue pulsado, reanuda al revivir).
		-- PlayerStateService manda sobre la WalkSpeed mientras está en el suelo.
		return
	end

	local enJuego = player:GetAttribute("EnJuego") == true
	if not enJuego then
		st.esprintando = false
	end

	if st.esprintando and not st.bloqueado and st.valor > 0 then
		local cansancio = math.clamp(tonumber(player:GetAttribute("Cansancio")) or 1, Ajustes.CansancioMinimo, 1)
		-- Renacimiento (L5b): «aguanta un poco más la velocidad» — cada renacer
		-- baja el drenaje un 5 % (máx. −25 %): el sprint lleno dura ~33 % más.
		local aguante = renacer and renacer.Aguante(player) or 0
		st.valor -= Ajustes.Drenaje * (1 - math.clamp(aguante, 0, 0.25)) * cansancio * dt
		if st.valor <= 0 then
			st.valor = 0
			st.bloqueado = true
			-- Se suelta la intención: tras recuperar el umbral hay que volver a pulsar
			-- (evita el ciclo automático de sprint a tirones con la tecla mantenida).
			st.esprintando = false
		end
		hum.WalkSpeed = Ajustes.VelocidadSprint
	else
		hum.WalkSpeed = Ajustes.VelocidadBase
		st.valor = math.min(Ajustes.Max, st.valor + Ajustes.Regeneracion * dt)
		if st.bloqueado and st.valor >= Ajustes.UmbralMinimo then
			st.bloqueado = false
		end
	end

	publicar(player, st)
end

-- TiendaService la llama al beber: repone sin tocar stock ni persistencia.
function EstaminaService.Reponer(player, cantidad)
	local st = estados[player]
	if not st or type(cantidad) ~= "number" then
		return
	end
	st.valor = math.clamp(st.valor + cantidad, 0, Ajustes.Max)
	if st.bloqueado and st.valor >= Ajustes.UmbralMinimo then
		st.bloqueado = false
	end
end

-- Lectura para QA y telemetría; no expone la tabla interna.
function EstaminaService.Estado(player)
	local st = estados[player]
	if not st then
		return nil
	end
	return { estamina = st.valor, esprintando = st.esprintando, bloqueado = st.bloqueado }
end

function EstaminaService.Iniciar()
	playerState = require(script.Parent.PlayerStateService)
	remotoEstado = Remotes.Crear(Remotes.Nombres.EstaminaEstado)
	permitirSprint = RateLimiter.nuevo(0.02) -- solo frena spam; la intención es idempotente

	local okRen, resRen = pcall(require, script.Parent.RenacimientoService)
	if okRen then
		renacer = resRen
	else
		warn("[Estamina] sin RenacimientoService: drenaje sin aguante")
	end

	local remotoSprint = Remotes.Crear(Remotes.Nombres.Sprint)
	remotoSprint.OnServerEvent:Connect(function(player, valor)
		if type(valor) ~= "boolean" or not permitirSprint(player) then
			return
		end
		local st = estados[player]
		if st then
			st.esprintando = valor
		end
	end)

	local function alEntrar(player)
		estados[player] = { valor = Ajustes.Max, esprintando = false, bloqueado = false }
		player.CharacterAdded:Connect(function()
			local st = estados[player]
			if st then
				st.valor = Ajustes.Max
				st.esprintando = false
				st.bloqueado = false
				st.enviado = nil
			end
		end)
	end

	Players.PlayerAdded:Connect(alEntrar)
	for _, player in ipairs(Players:GetPlayers()) do
		alEntrar(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		estados[player] = nil
	end)

	task.spawn(function()
		local anterior = os.clock()
		while true do
			task.wait(1 / Ajustes.Ritmo)
			local ahora = os.clock()
			local dt = ahora - anterior
			anterior = ahora
			for player, st in estados do
				simular(player, st, dt)
			end
		end
	end)
end

return EstaminaService
