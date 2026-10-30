-- QATestDatos: QA de Studio del esquema v2 (fase 11 · E45). Main no lo arranca;
-- se invoca con un Script temporal (MCP) y valida migración, idempotencia y fusión.
-- En un servidor publicado se niega a ejecutar.
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)

local QATestDatos = {}

local function contar(tabla)
	local n = 0
	for _ in pairs(tabla) do
		n += 1
	end
	return n
end

function QATestDatos.Ejecutar()
	if not RunService:IsStudio() then
		return false, "solo Studio"
	end
	local v1 = {
		pinas = 55,
		comprados = { "sombrero_gorro" },
		ropa = { activa = 1, disenos = {} },
		record = 900,
	}
	local primero, idempotente = DataService._ProbarMigracion(v1)
	local segundo = DataService._ProbarMigracion(primero)

	local fallos = {}
	local function revisar(nombre, ok)
		if not ok then
			table.insert(fallos, nombre)
		end
	end
	revisar("schema", primero.schema == 2 and segundo.schema == 2)
	revisar("pinas", primero.pinas == 55 and segundo.pinas == 55)
	revisar("comprados", #primero.comprados == 1 and #segundo.comprados == 1)
	revisar("ropa", primero.ropa.activa == 1 and segundo.ropa.activa == 1)
	revisar("record", primero.record == 900 and segundo.record == 900)
	revisar("idempotente", idempotente == true)
	revisar("sin campos nuevos", contar(primero) == contar(segundo))

	local guardado = { schema = 2, xp = 42, estadisticas = { partidas = 3 } }
	local fusion = DataService._ProbarFusion(guardado, { pinas = 170 })
	revisar("fusion xp", fusion.xp == 42)
	revisar("fusion partidas", fusion.estadisticas.partidas == 3)
	revisar("sesion", fusion.pinas == 170)
	revisar("defaults", fusion.tutorialVisto == false)

	if #fallos > 0 then
		warn("[QA-DATOS] FALLOS: " .. table.concat(fallos, ", "))
		return false, fallos
	end
	print("[QA-DATOS] OK migracion=v1 idempotente=true fusion=defaults<guardado<sesion")
	return true
end

return QATestDatos
