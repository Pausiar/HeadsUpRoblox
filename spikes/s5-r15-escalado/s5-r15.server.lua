-- Spike S5 (servidor): límites de escalado del cuerpo R15 (plan §9, línea 215).
-- Código desechable: pégalo en ServerScriptService, dale a Play, lee la consola y bórralo.
-- Comprueba: (1) qué escalas existen realmente en HumanoidDescription, (2) la altura
-- real de cada caso medida con Model:GetExtentsSize(), y (3) si existe ALGUNA escala
-- de longitud independiente de brazos/piernas (respuesta esperada: NO; si no existe,
-- pasa a la versión 2 según plan §6, línea 146). Los rigs quedan en fila sobre bases
-- planas propias en workspace.S5R15 para capturar con screen_capture.

local Players = game:GetService("Players")

-- ===== Configuración (edita aquí) =====
local CASOS = {
	-- Valores del plan §6: alturas 0.9/1.0/1.05, anchos 0.7/1.0/1.3, cabezas 0.85/1.0/1.25
	{ nombre = "normal",       altura = 1.0,  ancho = 1.0, cabeza = 1.0 },
	{ nombre = "minimo",       altura = 0.9,  ancho = 0.7, cabeza = 0.85 },
	{ nombre = "maximo",       altura = 1.05, ancho = 1.3, cabeza = 1.25 },
	{ nombre = "alto_delgado", altura = 1.05, ancho = 0.7, cabeza = 1.0 },
	{ nombre = "bajo_ancho",   altura = 0.9,  ancho = 1.3, cabeza = 1.0 },
}
local ESPERA_INICIAL = 2 -- segundos al arrancar (deja entrar al jugador)
local SEPARACION = 10 -- studs entre bases en la fila (eje X)
local LADO_BASE = 8 -- lado de la base plana de cada caso
-- Nombres candidatos por rol: se usa el primero que exista en HumanoidDescription.
-- (Los nombres con prefijo Body* son la nomenclatura alternativa por si cambia la API.)
local CANDIDATAS_ROL = {
	altura = { "HeightScale", "BodyHeightScale" },
	ancho = { "WidthScale", "BodyWidthScale" },
	profundidad = { "DepthScale", "BodyDepthScale" },
	cabeza = { "HeadScale" },
	proporcion = { "ProportionScale", "BodyProportionScale" },
	tipoCuerpo = { "BodyTypeScale" },
}
-- Candidatas de longitud independiente de extremidades: se espera que NINGUNA exista.
local CANDIDATAS_EXTREMIDADES = {
	"ArmLengthScale", "LegLengthScale", "TorsoLengthScale",
	"ArmScale", "LegScale", "TorsoScale", "HandSizeScale", "FootSizeScale",
}
-- ======================================

-- Prueba si un nombre de escala existe en HumanoidDescription (set + get numérico).
local function existeEscala(nombre)
	local ok = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d[nombre] = 1
		assert(typeof(d[nombre]) == "number")
		d:Destroy()
	end)
	return ok
end

-- Sondea todas las candidatas, resuelve el nombre real por rol y lo imprime.
local function sondearEscalas()
	local resueltas, encontradas = {}, {}
	for rol, candidatas in pairs(CANDIDATAS_ROL) do
		for _, nombre in ipairs(candidatas) do
			local existe = existeEscala(nombre)
			print(string.format("[S5] probe %s=%s", nombre, existe and "existe" or "no existe"))
			if existe then
				resueltas[rol] = nombre
				encontradas[#encontradas + 1] = nombre
				break
			end
		end
	end
	local algunaExtremidad = false
	for _, nombre in ipairs(CANDIDATAS_EXTREMIDADES) do
		local existe = existeEscala(nombre)
		print(string.format(
			"[S5] probe %s=%s",
			nombre, existe and "existe (INESPERADO)" or "no existe (esperado)"
		))
		if existe then
			algunaExtremidad = true
		end
	end
	return resueltas, algunaExtremidad, encontradas
end

-- Sondea si HumanoidDescription satura (clampa) los valores fuera de rango al escribir.
local function sondearClamp(propiedad)
	local leidoAlto, leidoBajo
	pcall(function()
		local d = Instance.new("HumanoidDescription")
		d[propiedad] = 10
		leidoAlto = d[propiedad]
		d[propiedad] = 0.01
		leidoBajo = d[propiedad]
		d:Destroy()
	end)
	if leidoAlto and leidoBajo then
		print(string.format(
			"[S5] probe clamp %s: set 10 -> lee %.2f | set 0.01 -> lee %.2f",
			propiedad, leidoAlto, leidoBajo
		))
	else
		print("[S5] probe clamp " .. propiedad .. ": no se pudo sondear")
	end
end

-- Crea base plana + rig R15 del caso, lo coloca en fila y devuelve su altura real
-- (lado Y del bounding box del Model, método constante entre casos) o nil + error.
local function construirCaso(caso, indice, props, carpeta)
	local ok, resultado = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc[props.altura] = caso.altura
		desc[props.ancho] = caso.ancho
		desc[props.cabeza] = caso.cabeza
		local rig = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)

		local x = (indice - 1) * SEPARACION
		local base = Instance.new("Part")
		base.Name = "Base_" .. caso.nombre
		base.Size = Vector3.new(LADO_BASE, 1, LADO_BASE)
		base.Position = Vector3.new(x, -0.5, 0) -- cara superior en y=0
		base.Anchored = true
		base.Material = Enum.Material.Grass
		base.Parent = carpeta

		rig.Name = "Caso_" .. caso.nombre
		rig:PivotTo(CFrame.new(x, 4, 0)) -- sobre su propia base
		rig.Parent = carpeta
		local raiz = rig:FindFirstChild("HumanoidRootPart")
		if raiz then
			raiz.Anchored = true -- congela el rig para medir y capturar sin caídas
		end
		return rig:GetExtentsSize().Y
	end)
	if ok then
		return resultado, nil
	end
	return nil, tostring(resultado)
end

task.wait(ESPERA_INICIAL)

local carpeta = Instance.new("Folder")
carpeta.Name = "S5R15"
carpeta.Parent = workspace

print(string.format("[S5] inicio: %d casos de escalado R15 (altura/ancho/cabeza del plan §6)", #CASOS))
local props, extremidadInesperada, encontradas = sondearEscalas()
if props.altura then
	sondearClamp(props.altura)
end

local alturas, fallos = {}, 0
for indice, caso in ipairs(CASOS) do
	local alturaReal, err
	if not props.altura or not props.ancho or not props.cabeza then
		err = "escalas no resueltas; solo existen: " .. table.concat(encontradas, ", ")
	else
		alturaReal, err = construirCaso(caso, indice, props, carpeta)
	end
	if alturaReal then
		alturas[#alturas + 1] = alturaReal
		print(string.format("[S5] caso=%s altura_real=%.2f err=no", caso.nombre, alturaReal))
	else
		fallos += 1
		print(string.format("[S5] caso=%s altura_real=n/d err=%s", caso.nombre, err))
	end
end

-- RESUMEN con los límites prácticos
local cfgMin, cfgMax = math.huge, 0
for _, c in ipairs(CASOS) do
	cfgMin = math.min(cfgMin, c.altura)
	cfgMax = math.max(cfgMax, c.altura)
end
if #alturas > 0 then
	local min, max = math.huge, 0
	for _, a in ipairs(alturas) do
		min = math.min(min, a)
		max = math.max(max, a)
	end
	print(string.format(
		"[S5] RESUMEN: altura real %.2f-%.2f studs con HeightScale %.2f-%.2f; escalas usadas: altura=%s ancho=%s cabeza=%s; fallos=%d/%d casos (rigs en workspace.S5R15).",
		min, max, cfgMin, cfgMax,
		tostring(props.altura), tostring(props.ancho), tostring(props.cabeza),
		fallos, #CASOS
	))
else
	print(string.format(
		"[S5] RESUMEN: ningún caso midió altura (fallos=%d/%d); revisar errores y las escalas existentes impresas arriba.",
		fallos, #CASOS
	))
end
print(string.format(
	"[S5] RESUMEN: longitud independiente de brazos/piernas: %s -> %s",
	extremidadInesperada and "SÍ existe (INESPERADO, ver probes)" or "NO existe en HumanoidDescription",
	extremidadInesperada and "investigar antes de decidir" or "personalización v1 con altura/ancho/cabeza (plan §6); brazos y piernas independientes pasan a la versión 2"
))
