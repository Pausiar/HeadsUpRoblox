-- RondaRapidaService: escenario de las rondas rápidas sobre la ruta que genera el terreno.
-- Solo construcción y limpieza: quién lo invoca se decide en MatchService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerrenoConfig = require(ReplicatedStorage.Shared.Config.TerrenoConfig)
local TerrenoService = require(script.Parent.TerrenoService)
local Escenario = require(script.Parent.Escenario)
local StageService = require(script.Parent.StageService)
local TiendaCampamento = require(script.Parent.TiendaCampamento)

local RondaRapidaService = {}

local ANCHO = TerrenoConfig.Camino.Ancho
local COLOR_MADERA = Escenario.Colores.Madera
local COLOR_CARTEL = Escenario.Colores.Cartel
local COLOR_ROCA = Escenario.Colores.Roca
local pieza = Escenario.pieza

local function crearSpawn(punto, tangente, padre)
	local centro = Vector3.new(punto.X, punto.Y - 0.5, punto.Z)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 12)
	spawn.CFrame = CFrame.lookAt(centro, centro + tangente)
	spawn.Color = COLOR_MADERA
	spawn.Material = Enum.Material.WoodPlanks
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = padre
end

function RondaRapidaService.ConstruirConSemilla(semilla)
	semilla = math.floor(tonumber(semilla) or os.time())
	RondaRapidaService.Limpiar()

	local ruta = TerrenoService.ConstruirRapida(semilla)
	local rng = Random.new(semilla)

	local carpeta = Instance.new("Folder")
	carpeta.Name = "RondaRapida"
	carpeta.Parent = workspace

	local puntoInicio, tangenteInicio = ruta:PuntoEnDistancia(0)
	crearSpawn(puntoInicio, tangenteInicio, carpeta)

	-- La tienda no es crítica para la carrera: un fallo se avisa y no tumba el mapa.
	local okTienda, errTienda = pcall(TiendaCampamento.Construir, carpeta, puntoInicio, tangenteInicio)
	if not okTienda then
		warn("[RondaRapida] tienda no construida: " .. tostring(errTienda))
	end

	-- Meta: cierra la ronda con medalla en vez de dejarla sin final (fase 11 · L4/B6).
	local okMeta, errMeta = pcall(StageService.ConstruirMeta, carpeta, ruta)
	if not okMeta then
		warn("[RondaRapida] meta no construida: " .. tostring(errMeta))
	end

	-- Grupos de rocas junto a los bordes, alternando de lado y sin invadir el centro
	local grupos = rng:NextInteger(6, 9)
	for i = 1, grupos do
		local punto, tangente = ruta:PuntoEnDistancia(rng:NextNumber(25, ruta.Longitud - 15))
		local normal = tangente:Cross(Vector3.yAxis).Unit
		local lado = i % 2 == 1 and 1 or -1
		for _ = 1, rng:NextInteger(1, 2) do
			local tam = rng:NextNumber(1.2, 3)
			local borde = punto + normal * (lado * (ANCHO / 2 + rng:NextNumber(1.5, 3.5)))
			local pos = borde + tangente * rng:NextNumber(-1.5, 1.5)
			local suelo = TerrenoService.AlturaSuelo(pos)
			pieza({
				nombre = "Roca",
				tamano = Vector3.new(tam, tam, tam),
				cf = CFrame.new(pos.X, suelo + tam / 2 - 0.2, pos.Z),
				forma = rng:NextInteger(0, 1) == 0 and Enum.PartType.Ball or Enum.PartType.Block,
				color = COLOR_ROCA,
				material = Enum.Material.Slate,
				padre = carpeta,
			})
		end
	end

	-- Postes decorativos en un solo lado, uno cada 40-60 studs
	local ladoPostes = rng:NextInteger(0, 1) == 0 and -1 or 1
	local d = rng:NextNumber(30, 45)
	for _ = 1, rng:NextInteger(4, 6) do
		if d > ruta.Longitud - 10 then
			break
		end
		local punto, tangente = ruta:PuntoEnDistancia(d)
		local normal = tangente:Cross(Vector3.yAxis).Unit
		local altura = rng:NextNumber(4, 6)
		local base = punto + normal * (ladoPostes * (ANCHO / 2 + 2))
		local suelo = TerrenoService.AlturaSuelo(base)
		pieza({
			nombre = "Poste",
			tamano = Vector3.new(0.6, altura, 0.6),
			cf = CFrame.new(base.X, suelo + altura / 2 - 0.2, base.Z),
			color = COLOR_MADERA,
			material = Enum.Material.Wood,
			padre = carpeta,
		})
		if rng:NextInteger(0, 1) == 0 then
			local posPiedra = base + tangente * 0.9
			pieza({
				nombre = "Piedra",
				tamano = Vector3.new(1.2, 1.2, 1.2),
				cf = CFrame.new(posPiedra.X, TerrenoService.AlturaSuelo(posPiedra) + 0.4, posPiedra.Z),
				forma = Enum.PartType.Ball,
				color = COLOR_ROCA,
				material = Enum.Material.Slate,
				padre = carpeta,
			})
		else
			local posCartel = Vector3.new(base.X, suelo + altura - 1.2, base.Z)
			pieza({
				nombre = "Cartel",
				tamano = Vector3.new(1.4, 0.9, 0.2),
				cf = CFrame.lookAt(posCartel, Vector3.new(punto.X, posCartel.Y, punto.Z)),
				color = COLOR_CARTEL,
				material = Enum.Material.Wood,
				padre = carpeta,
			})
		end
		d += rng:NextNumber(40, 60)
	end

	print(("[RondaRapida] camino con semilla %d: %d studs, %d grupos de rocas, tienda %s"):format(
		semilla,
		ruta.Longitud,
		grupos,
		okTienda and "ok" or "error"
	))
	return carpeta
end

function RondaRapidaService.Limpiar()
	local anterior = workspace:FindFirstChild("RondaRapida")
	if anterior then
		anterior:Destroy()
	end
end

return RondaRapidaService
