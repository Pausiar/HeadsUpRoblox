-- Spike S4 (servidor): banco de pruebas de carga para físicas de rocas (plan §9).
-- Código desechable: pégalo en ServerScriptService, dale a Play, lee la consola y bórralo.
-- Mide el dt real del Heartbeat del SERVIDOR (deltas con os.clock(), no task.wait simulado)
-- por tandas de rocas activas, para fijar el presupuesto de físicas (plan §3.3 y §11).

local RunService = game:GetService("RunService")

-- ===== Configuración (edita aquí) =====
local TANDAS = {0, 50, 100, 200, 400} -- rocas activas por tanda
local DURACION_MEDICION = 6 -- segundos de medición por tanda
local PAUSA_ENTRE_TANDAS = 2 -- segundos de descanso entre tandas
local ESPERA_INICIAL = 2 -- segundos al arrancar (deja entrar al jugador)
local TAMANO_ROCA = {3, 6} -- rango de tamaño en studs (cubo uniforme)
local ALTURA_CAIDA = {60, 120} -- rango de altura de caída en studs
local RADIO_DISPERSION = 180 -- radio de caída sobre la base 400x400 (mitad del lado, con margen)
local DT_OBJETIVO = 1 / 30 -- presupuesto servidor: dt_medio < 0.033s (plan §3.3)
-- ======================================

local rng = Random.new()
local carpeta = Instance.new("Folder")
carpeta.Name = "S4Carga"

local function construirBase()
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(400, 2, 400)
	base.Position = Vector3.new(0, -1, 0) -- cara superior en y=0
	base.Anchored = true
	base.Material = Enum.Material.Grass
	base.Parent = carpeta
end

local function crearRoca(padre)
	local roca = Instance.new("Part")
	roca.Name = "Roca"
	roca.Shape = Enum.PartType.Ball
	local tam = rng:NextNumber(TAMANO_ROCA[1], TAMANO_ROCA[2])
	roca.Size = Vector3.new(tam, tam, tam)
	roca.Material = Enum.Material.Slate
	roca.Anchored = false
	roca.CanCollide = true
	roca.Position = Vector3.new(
		rng:NextNumber(-RADIO_DISPERSION, RADIO_DISPERSION),
		rng:NextNumber(ALTURA_CAIDA[1], ALTURA_CAIDA[2]),
		rng:NextNumber(-RADIO_DISPERSION, RADIO_DISPERSION)
	)
	roca.Parent = padre
end

-- Construye la tanda fuera del DataModel y la cuelga de una vez: las N rocas
-- empiezan a caer juntas y el coste de insertar en el árbol se paga una sola vez.
local function crearTanda(n)
	local tanda = Instance.new("Folder")
	tanda.Name = "Tanda_" .. n
	for _ = 1, n do
		crearRoca(tanda)
	end
	tanda.Parent = carpeta
	return tanda
end

-- Acumula deltas reales del Heartbeat en una tabla durante DURACION_MEDICION segundos
-- y calcula media/máximo al terminar. El task.wait del bucle solo acota la ventana.
local function medirTanda()
	local muestras = {}
	local previo = nil
	local conexion = RunService.Heartbeat:Connect(function()
		local ahora = os.clock()
		if previo then
			muestras[#muestras + 1] = ahora - previo
		end
		previo = ahora
	end)
	local inicio = os.clock()
	while os.clock() - inicio < DURACION_MEDICION do
		task.wait()
	end
	conexion:Disconnect()

	local suma, maximo = 0, 0
	for _, dt in ipairs(muestras) do
		suma += dt
		if dt > maximo then
			maximo = dt
		end
	end
	local media = #muestras > 0 and suma / #muestras or 0
	return media, maximo
end

task.wait(ESPERA_INICIAL)
construirBase()
carpeta.Parent = workspace
print(string.format(
	"[S4] inicio: tandas=%s, %ds de medición por tanda, objetivo dt_medio < %.3fs",
	table.concat(TANDAS, "/"),
	DURACION_MEDICION,
	DT_OBJETIVO
))

local resultados = {}
for _, n in ipairs(TANDAS) do
	local tanda = crearTanda(n)
	local media, maximo = medirTanda()
	resultados[#resultados + 1] = { rocas = n, media = media, maximo = maximo }
	print(string.format(
		"[S4] rocas=%d dt_medio=%.3fs dt_max=%.3fs (objetivo: dt_medio < %.3f)",
		n, media, maximo, DT_OBJETIVO
	))
	tanda:Destroy()
	task.wait(PAUSA_ENTRE_TANDAS)
end

local peorMedia, peorRocas = 0, 0
for _, r in ipairs(resultados) do
	if r.media > peorMedia then
		peorMedia, peorRocas = r.media, r.rocas
	end
end
if peorMedia < DT_OBJETIVO then
	print(string.format(
		"[S4] RESUMEN: CUMPLE el presupuesto (dt_medio < %.3fs); peor tanda: %d rocas con dt_medio %.3fs. Presupuesto propuesto: ~%d objetos físicos activos.",
		DT_OBJETIVO, peorRocas, peorMedia, peorRocas
	))
else
	print(string.format(
		"[S4] RESUMEN: NO CUMPLE el presupuesto; peor tanda: %d rocas con dt_medio %.3fs >= %.3fs. Reducir objetos físicos activos y activar pooling (plan §3.3).",
		peorRocas, peorMedia, DT_OBJETIVO
	))
end
