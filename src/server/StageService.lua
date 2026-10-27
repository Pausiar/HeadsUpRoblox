-- StageService: construye el sendero de la etapa 0 desde Config (todo por código)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)

local StageService = {}

local function pieza(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.nombre
	p.Size = props.tamano
	p.CFrame = props.cf
	p.Color = props.color
	p.Material = props.material or Enum.Material.Grass
	p.Parent = props.padre
	return p
end

function StageService.Construir()
	local etapa = Config.Etapa0
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Etapa0"
	carpeta.Parent = workspace

	-- Sendero de tierra a lo largo del eje X
	pieza({
		nombre = "Sendero",
		tamano = Vector3.new(etapa.Longitud, 1, etapa.Ancho),
		cf = CFrame.new(etapa.Longitud / 2, 0.5, 0),
		color = Color3.fromRGB(139, 110, 78),
		material = Enum.Material.Ground,
		padre = carpeta,
	})

	-- Spawn al inicio
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, etapa.Ancho)
	spawn.CFrame = CFrame.new(-8, 0.5, 0)
	spawn.Color = Color3.fromRGB(92, 58, 33)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = carpeta

	-- Checkpoints visuales (los checkpoints con lógica llegan en fase 2)
	for x = etapa.CheckpointCada, etapa.Longitud - 20, etapa.CheckpointCada do
		pieza({
			nombre = "PosteCheckpoint",
			tamano = Vector3.new(0.6, 6, 0.6),
			cf = CFrame.new(x, 3.5, -etapa.Ancho / 2 + 1),
			color = Color3.fromRGB(255, 201, 60),
			material = Enum.Material.Wood,
			padre = carpeta,
		})
		pieza({
			nombre = "CartelCheckpoint",
			tamano = Vector3.new(2.4, 1.6, 0.3),
			cf = CFrame.new(x, 6, -etapa.Ancho / 2 + 1),
			color = Color3.fromRGB(245, 235, 216),
			material = Enum.Material.Wood,
			padre = carpeta,
		})
	end

	-- Árboles de adorno a los lados (los .glb de verdad llegan tras S2)
	local rng = Random.new(42)
	for i = 1, 24 do
		local x = rng:NextNumber(0, etapa.Longitud)
		local lado = rng:NextInteger(0, 1) == 0 and -1 or 1
		local z = lado * (etapa.Ancho / 2 + rng:NextNumber(4, 14))
		local altura = rng:NextNumber(9, 15)
		pieza({
			nombre = "Tronco",
			tamano = Vector3.new(1.2, altura, 1.2),
			cf = CFrame.new(x, altura / 2, z),
			color = Color3.fromRGB(92, 58, 33),
			material = Enum.Material.Wood,
			padre = carpeta,
		})
		pieza({
			nombre = "Copa",
			tamano = Vector3.new(6, 5, 6),
			cf = CFrame.new(x, altura + 2, z),
			color = Color3.fromRGB(76, 140, 74),
			material = Enum.Material.Grass,
			padre = carpeta,
		})
	end

	print("[Stage] etapa 0 construida:", etapa.Nombre)
end

return StageService
