-- RachaService: racha diaria (plan §L8 · C27). Un registro por día UTC,
-- recompensa de 1 a 7 Piñas según el día de racha y sin castigo por saltarse
-- UN día. Servidor autoritativo: el día se decide aquí y se persiste en
-- datos.racha = { ultimoDia = yyyymmdd, dias, pinasPendientes } vía DataService.
-- PinasService aún no expone Sumar: las Piñas del día se ACUMULAN en
-- datos.racha.pinasPendientes (persistidas con la racha). Cuando exista Sumar,
-- abonar con PinasService.Sumar(player, racha.pinasPendientes) y poner
-- racha.pinasPendientes = 0 + DataService.Guardar(player, "racha", racha).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local INTERVALO_BARRIDO = 60 -- s entre barridos (cubre la medianoche UTC con el servidor vivo)
local PINA_MAX = 7 -- tope de la recompensa (día 7 en adelante)

local RachaService = {}

local dataService -- asignado en Iniciar() con pcall; nil = sin persistencia
local remotoRacha

-- Día UTC actual como número yyyymmdd (formato de racha.ultimoDia).
local function hoyYyyymmdd()
	local t = os.date("!*t")
	return t.year * 10000 + t.month * 100 + t.day
end

-- yyyymmdd → días desde la época (1970-01-01 = 0). «days from civil» puro:
-- restar sobre yyyymmdd rompe en el cambio de mes (20261101 - 2 = 20261099) y
-- os.time(tabla) interpreta la tabla en la zona horaria del host (Studio no es UTC).
local function aDias(yyyymmdd)
	local y = math.floor(yyyymmdd / 10000)
	local m = math.floor(yyyymmdd / 100) % 100
	local d = yyyymmdd % 100
	if m <= 2 then
		y -= 1
	end
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local doy = math.floor((153 * ((m + 9) % 12) + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

-- Recompensa del día de racha: día 1 → 1 Piña, 2 → 2, ..., 7 o más → 7.
local function pinasDelDia(dias)
	return math.min(dias, PINA_MAX)
end

-- Registra HOY para el jugador si toca. Idempotente dentro del día: lo llama
-- AlCargar y el barrido de 60 s. Casos (hueco en días UTC desde el último registro):
--   sin registro previo → dias = 1   (primera vez)
--   hueco 1 (jugó ayer) → dias += 1  (día consecutivo)
--   hueco 2 (se saltó 1) → dias += 1 (sin castigo por saltarse uno)
--   hueco 3 o más       → dias = 1   (recomienza)
local function registrarJugador(player)
	if not dataService then
		return
	end
	local racha = dataService.Obtener(player).racha
	if type(racha) ~= "table" then
		return -- perfil aún sin cargar; AlCargar o el barrido lo reintentarán
	end
	local hoy = aDias(hoyYyyymmdd())
	local ultimo = tonumber(racha.ultimoDia) or 0
	if ultimo > 0 and aDias(ultimo) >= hoy then
		return -- ya registró hoy (o fecha futura: no tocar)
	end
	local hueco = ultimo > 0 and (hoy - aDias(ultimo)) or nil
	local dias = tonumber(racha.dias) or 0
	if hueco and hueco <= 2 then
		dias += 1
	else
		dias = 1 -- primera vez o hueco largo
	end
	racha.dias = dias
	racha.ultimoDia = hoyYyyymmdd()
	local recompensa = pinasDelDia(dias)
	racha.pinasPendientes = (racha.pinasPendientes or 0) + recompensa
	dataService.Guardar(player, "racha", racha)
	remotoRacha:FireClient(player, { dias = dias, recompensa = recompensa })
	print("[Racha] " .. player.Name .. ": día " .. dias .. " (recompensa " .. recompensa .. " Piñas pendientes)")
end

function RachaService.Iniciar()
	remotoRacha = Remotes.Crear(Remotes.Nombres.Racha)

	-- DataService puede no existir aún en una fase temprana: require con pcall
	local ok, res = pcall(function()
		return require(script.Parent.DataService)
	end)
	if ok then
		dataService = res
	else
		warn("[Racha] sin DataService: la racha no se registra esta sesión")
		return
	end

	-- Al cargar el perfil: registrar el día en el momento.
	dataService.AlCargar.Event:Connect(function(player)
		registrarJugador(player)
	end)
	-- Carrera: perfil ya cargado antes de conectar AlCargar (registrarJugador
	-- no hace nada si el perfil de ese jugador todavía no está).
	for _, player in ipairs(Players:GetPlayers()) do
		registrarJugador(player)
	end

	-- Barrido cada 60 s: cubre el cambio de día UTC con el servidor vivo y a
	-- quien no llegó a cargar antes. Repetir es gratis: registrarJugador no-op
	-- si ya registró hoy.
	task.spawn(function()
		while true do
			task.wait(INTERVALO_BARRIDO)
			local okTick, err = pcall(function()
				for _, player in ipairs(Players:GetPlayers()) do
					registrarJugador(player)
				end
			end)
			if not okTick then
				warn("[Racha] barrido falló: " .. tostring(err))
			end
		end
	end)

	print("[Racha] servicio listo: 1 registro/día UTC, recompensa 1–" .. PINA_MAX
		.. " Piñas (pendientes hasta que PinasService.Sumar las abone)")
end

-- Seam de Studio: calendario puro sin DataStore (invocable desde QATestDatos).
if RunService:IsStudio() then
	function RachaService._ProbarCalendario()
		assert(aDias(19700101) == 0, "época")
		assert(aDias(20261031) == 20757, "fecha conocida")
		assert(aDias(20261101) - aDias(20261031) == 1, "cambio de mes")
		assert(aDias(20270101) - aDias(20261231) == 1, "cambio de año")
	end
end

return RachaService
