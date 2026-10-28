-- StageService: etapa 0 sobre la ruta que genera el terreno (spawn, checkpoints visuales y meta).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local TerrenoConfig = require(ReplicatedStorage.Shared.Config.TerrenoConfig)
local TerrenoService = require(script.Parent.TerrenoService)

local StageService = {}
StageService.TotalCheckpoints = 0 -- postes construidos; MatchService cobra exactamente estos

local ANCHO = TerrenoConfig.Camino.Ancho
local COLOR_MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local COLOR_POSTE = Color3.fromRGB(255, 201, 60) -- #FFC93C
local COLOR_CARTEL = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local COLOR_ROCA = Color3.fromRGB(110, 106, 100)

local function pieza(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.nombre
	p.Size = props.tamano
	p.CFrame = props.cf
	p.Color = props.color
	p.Material = props.material
	p.Parent = props.padre
	return p
end

-- Idempotente: quita la etapa anterior sin tocar el terreno ni la ruta.
function StageService.Limpiar()
	local anterior = workspace:FindFirstChild("Etapa0")
	if anterior then
		anterior:Destroy()
	end
end

function StageService.Construir()
	StageService.Limpiar()
	local ruta = TerrenoService.ConstruirHistoria()

	local carpeta = Instance.new("Folder")
	carpeta.Name = "Etapa0"
	carpeta.Parent = workspace

	local puntoInicio, tangenteInicio = ruta:PuntoEnDistancia(0)
	local centroSpawn = Vector3.new(puntoInicio.X, puntoInicio.Y - 0.5, puntoInicio.Z)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 12)
	spawn.CFrame = CFrame.lookAt(centroSpawn, centroSpawn + tangenteInicio)
	spawn.Color = COLOR_MADERA
	spawn.Material = Enum.Material.WoodPlanks
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = carpeta

	-- Postes y carteles en las mismas distancias que usa MatchService para los checkpoints
	local cada = Config.Etapa0.CheckpointCada
	local checkpoints = 0
	for d = cada, ruta.Longitud - 20, cada do
		local punto, tangente = ruta:PuntoEnDistancia(d)
		local normal = tangente:Cross(Vector3.yAxis).Unit
		local base = punto + normal * (ANCHO / 2 + 2)
		local suelo = TerrenoService.AlturaSuelo(base)
		local poste = Vector3.new(base.X, suelo + 2.8, base.Z)
		local cartel = Vector3.new(base.X, suelo + 5.2, base.Z)

		pieza({
			nombre = "PosteCheckpoint",
			tamano = Vector3.new(0.6, 6, 0.6),
			cf = CFrame.new(poste),
			color = COLOR_POSTE,
			material = Enum.Material.Wood,
			padre = carpeta,
		})
		pieza({
			nombre = "CartelCheckpoint",
			tamano = Vector3.new(2.4, 1.6, 0.3),
			cf = CFrame.lookAt(cartel, Vector3.new(punto.X, cartel.Y, punto.Z)),
			color = COLOR_CARTEL,
			material = Enum.Material.Wood,
			padre = carpeta,
		})
		checkpoints += 1
	end
	StageService.TotalCheckpoints = checkpoints

	-- Mojón de meta: tres rocas Slate apiladas al final de la ruta
	local puntoMeta = ruta:PuntoEnDistancia(ruta.Longitud)
	local apilado = {
		{ tamano = Vector3.new(3.2, 2.4, 3.2), altura = 0 },
		{ tamano = Vector3.new(2.4, 1.8, 2.4), altura = 2.4 },
		{ tamano = Vector3.new(1.6, 1.4, 1.6), altura = 4.2 },
	}
	for _, roca in ipairs(apilado) do
		pieza({
			nombre = "MojonMeta",
			tamano = roca.tamano,
			cf = CFrame.new(puntoMeta.X, puntoMeta.Y + roca.altura + roca.tamano.Y / 2, puntoMeta.Z),
			color = COLOR_ROCA,
			material = Enum.Material.Slate,
			padre = carpeta,
		})
	end

	print(("[Stage] etapa 0 construida: %d studs, %d checkpoints"):format(ruta.Longitud, checkpoints))
end

return StageService
