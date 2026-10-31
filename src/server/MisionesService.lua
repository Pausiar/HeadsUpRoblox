-- MisionesService: 3 misiones diarias UTC (fase 11 · L8, C26). Servidor
-- autoritativo: el progreso solo suma aquí, enganchado a las señales reales del
-- servidor (CheckpointAlcanzado, AlTerminar, Reanimado y el atributo Distancia
-- que publica MatchService). El estado vive en DataService bajo
-- datos.misiones = { dia, progreso, reclamadas, recompensasPendientes }
-- (esquema v2 §3 + el campo de recompensas pendientes añadido por C26).
--
-- Recompensa: PinasService aún no expone Sumar (solo GetPinas/Gastar), así que
-- el cobro se acumula en datos.misiones.recompensasPendientes y el cliente ve el
-- importe en MisionesResult { ok = true, pinas }. Cuando el coordinador añada
-- PinasService.Sumar hay que consumir esa pila (restar el pendiente y llamarla).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MisionesConfig = require(ReplicatedStorage.Shared.Config.MisionesConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local MisionesService = {}

-- Ids con señal de servidor hoy. beber_1 espera una señal de beber (no existe:
-- TiendaService llama EstaminaService.Reponer sin evento) y queda fuera del pool.
local CON_SENAL = { caminar_2000 = true, reanimar_2 = true, checkpoints_10 = true, meta_1 = true }

local remotoMisiones
local remotoResultado
local remotoReclamar
local dataService -- asignado en Iniciar() con pcall; nil = misiones sin persistencia
local ultimaDistancia = {} -- [player] = último valor del atributo Distancia

local function diaActual()
	return os.date("!%Y-%m-%d") -- UTC, coherente con yday de la semilla
end

-- Selección determinista del día: misma en todos los servidores y jugadores.
local function misionesDelDia()
	local diaNum = os.date("!*t").yday
	local pool = {}
	for _, mision in ipairs(MisionesConfig.Misiones) do
		if CON_SENAL[mision.id] then
			table.insert(pool, mision)
		end
	end
	local rng = Random.new(diaNum)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local elegidas = {}
	for i = 1, math.min(MisionesConfig.PorDia, #pool) do
		elegidas[i] = pool[i]
	end
	return elegidas
end

local function esDelDia(id)
	for _, mision in ipairs(misionesDelDia()) do
		if mision.id == id then
			return true
		end
	end
	return false
end

-- Envía el estado completo del día (contrato del remote Misiones).
local function enviar(player, m)
	local lista = {}
	for _, mision in ipairs(misionesDelDia()) do
		table.insert(lista, {
			id = mision.id,
			progreso = m.progreso[mision.id] or 0,
			meta = mision.meta,
			reclamada = m.reclamadas[mision.id] == true,
		})
	end
	remotoMisiones:FireClient(player, { dia = m.dia, misiones = lista })
end

-- Estado del día del jugador; si lo guardado es de otro día UTC lo resetea
-- (nuevo día: progreso y reclamadas se pierden; recompensasPendientes NO: es
-- dinero ya ganado). Devuelve (estado, reseteo); nil si aún no cargó el perfil
-- o no hay DataService (antes de AlCargar no se lleva progreso, como en Pinas).
local function estadoDia(player)
	if not dataService then
		return nil
	end
	local datos = dataService.Obtener(player)
	if type(datos.misiones) ~= "table" then
		return nil
	end
	local m = datos.misiones
	local reseteo = m.dia ~= diaActual()
	if reseteo then
		m.dia = diaActual()
		m.progreso = {}
		m.reclamadas = {}
		dataService.Guardar(player, "misiones", m)
	end
	return m, reseteo
end

-- Suma progreso (capado a la meta) solo si la misión es de las elegidas hoy.
-- `completada` se deriva de progreso >= meta, no se guarda aparte.
local function sumar(player, id, cantidad)
	local m, _ = estadoDia(player)
	local mision = MisionesConfig.PorId(id)
	if not m or not mision or not esDelDia(id) then
		return
	end
	local antes = m.progreso[id] or 0
	if antes >= mision.meta then
		return
	end
	local despues = math.min(antes + cantidad, mision.meta)
	m.progreso[id] = despues
	dataService.Guardar(player, "misiones", m)
	enviar(player, m)
	if despues >= mision.meta then
		print(("[Misiones] %s completó %s (%d/%d)"):format(player.Name, id, despues, mision.meta))
	end
end

function MisionesService.Iniciar()
	remotoMisiones = Remotes.Crear(Remotes.Nombres.Misiones)
	remotoResultado = Remotes.Crear(Remotes.Nombres.MisionesResult)
	remotoReclamar = Remotes.Crear(Remotes.Nombres.ReclamarMision)
	local permitirReclamar = RateLimiter.nuevo(1)

	local okDatos, resDatos = pcall(require, script.Parent.DataService)
	if okDatos then
		dataService = resDatos
	else
		warn("[Misiones] sin DataService: las misiones no se llevan esta sesión")
	end

	local matchService = require(script.Parent.MatchService)
	local playerState = require(script.Parent.PlayerStateService)

	-- Caminar: MatchService publica el progreso de ruta en el atributo Distancia
	-- (1 Hz); el delta positivo suma studs y bajar (partida nueva) no resta.
	local function conectarDistancia(player)
		player:GetAttributeChangedSignal("Distancia"):Connect(function()
			local valor = tonumber(player:GetAttribute("Distancia")) or 0
			local anterior = ultimaDistancia[player] or 0
			ultimaDistancia[player] = valor
			if valor > anterior then
				sumar(player, "caminar_2000", valor - anterior)
			end
		end)
	end
	Players.PlayerAdded:Connect(conectarDistancia)
	for _, player in ipairs(Players:GetPlayers()) do
		conectarDistancia(player)
	end

	-- Checkpoints: uno por señal (solo Historia los cobra; la rápida no tiene)
	matchService.CheckpointAlcanzado.Event:Connect(function(player)
		sumar(player, "checkpoints_10", 1)
	end)

	-- Reanimar: mismo criterio que MatchService/PuntosService (ayudar a otro en partida)
	playerState.Reanimado.Event:Connect(function(reanimador, jugador)
		if reanimador and reanimador ~= jugador and reanimador:GetAttribute("EnJuego") == true then
			sumar(reanimador, "reanimar_2", 1)
		end
	end)

	-- Meta: AlTerminar con victoria (solo cerrarMeta la marca; el abandono no)
	matchService.AlTerminar.Event:Connect(function(player, stats)
		if stats and stats.victoria then
			sumar(player, "meta_1", 1)
		end
	end)

	-- beber_1: sin señal de servidor todavía; fuera del pool (ver CON_SENAL).

	-- Reclamo: limitado y validado (misión del día, completada, sin reclamar).
	remotoReclamar.OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" or not permitirReclamar(player) then
			return
		end
		local m = estadoDia(player)
		local mision = MisionesConfig.PorId(id)
		if not m or not mision or not esDelDia(id) then
			remotoResultado:FireClient(player, { ok = false, clave = "mision_invalida" })
			return
		end
		if (m.progreso[id] or 0) < mision.meta then
			remotoResultado:FireClient(player, { ok = false, clave = "mision_no_completada" })
			return
		end
		if m.reclamadas[id] then
			remotoResultado:FireClient(player, { ok = false, clave = "mision_ya_reclamada" })
			return
		end
		m.reclamadas[id] = true
		m.recompensasPendientes = (tonumber(m.recompensasPendientes) or 0) + mision.pinas
		dataService.Guardar(player, "misiones", m)
		remotoResultado:FireClient(player, { ok = true, clave = "mision_reclamada", pinas = mision.pinas })
		enviar(player, m)
		print("[Misiones] " .. player.Name .. " reclamó " .. id .. " (+" .. mision.pinas
			.. " Piñas; pendientes " .. m.recompensasPendientes .. ")")
	end)

	if dataService then
		-- Publicar al cargar el perfil
		dataService.AlCargar.Event:Connect(function(player, _datos)
			local m = estadoDia(player)
			if m then
				enviar(player, m)
			end
		end)
		-- Carrera: el perfil pudo cargar antes de conectar AlCargar
		for _, player in ipairs(Players:GetPlayers()) do
			local m = estadoDia(player)
			if m then
				enviar(player, m)
			end
		end
	end

	-- Reset diario UTC: barrido cada 60 s comparando el día guardado con el actual
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				local m, reseteo = estadoDia(player)
				if m and reseteo then
					enviar(player, m)
					print("[Misiones] nuevo día UTC para " .. player.Name .. ": misiones reiniciadas")
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ultimaDistancia[player] = nil
	end)

	print("[Misiones] servicio listo: " .. MisionesConfig.PorDia
		.. " misiones diarias de un pool con señal (beber_1 sin señal, fuera del pool)")
end

-- QA del criterio C26 (reset diario simulado): fecha el estado guardado a un día
-- viejo; el barrido de 60 s o la siguiente suma/publicación debe resetearlo.
if RunService:IsStudio() then
	function MisionesService._ProbarDiaViejo(player)
		local m = estadoDia(player)
		if not m then
			return false
		end
		m.dia = "2000-01-01"
		dataService.Guardar(player, "misiones", m)
		print("[Misiones] QA: día de " .. player.Name .. " fechado a 2000-01-01")
		return true
	end
end

return MisionesService
