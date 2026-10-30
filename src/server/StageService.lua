-- StageService: etapa 0 sobre la ruta que genera el terreno (spawn, checkpoints, meta y tienda).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local TerrenoConfig = require(ReplicatedStorage.Shared.Config.TerrenoConfig)
local TerrenoService = require(script.Parent.TerrenoService)
local Escenario = require(script.Parent.Escenario)
local TiendaCampamento = require(script.Parent.TiendaCampamento)

local StageService = {}
StageService.TotalCheckpoints = 0 -- postes construidos; MatchService cobra exactamente estos

local ANCHO = TerrenoConfig.Camino.Ancho
local COLOR_MADERA = Escenario.Colores.Madera
local COLOR_POSTE = Escenario.Colores.Poste
local COLOR_CARTEL = Escenario.Colores.Cartel
local COLOR_ROCA = Escenario.Colores.Roca
local COLOR_VERDE = Escenario.Colores.Verde
local COLOR_ROJO = Escenario.Colores.Rojo
local pieza = Escenario.pieza
local cartelTexto = Escenario.cartelTexto


-- Arco de madera, pancarta, banderines, círculo de piedras y dos antorchas.
local function construirMeta(carpeta, ruta)
	local puntoMeta, tangenteMeta = ruta:PuntoEnDistancia(ruta.Longitud)
	local base = puntoMeta.Y - 0.5 -- el corredor está carveado a esta altura; no hay AlturaSuelo
	local centro = Vector3.new(puntoMeta.X, base, puntoMeta.Z)
	local normal = tangenteMeta:Cross(Vector3.yAxis).Unit

	local meta = Instance.new("Folder")
	meta.Name = "Meta"
	meta.Parent = carpeta

	local medioAncho = ANCHO / 2 + 1.6
	for _, lado in ipairs({ -1, 1 }) do
		pieza({
			nombre = "PosteMeta",
			tamano = Vector3.new(0.9, 9, 0.9),
			cf = CFrame.new(centro + normal * (medioAncho * lado) + Vector3.new(0, 4.5, 0)),
			color = COLOR_MADERA,
			material = Enum.Material.Wood,
			padre = meta,
			consulta = false,
		})
	end

	local centroDintel = centro + Vector3.new(0, 8.6, 0)
	pieza({
		nombre = "DintelMeta",
		tamano = Vector3.new(medioAncho * 2 + 0.9, 0.8, 0.8),
		cf = CFrame.lookAt(centroDintel, centroDintel + tangenteMeta),
		color = COLOR_MADERA,
		material = Enum.Material.Wood,
		padre = meta,
		consulta = false,
	})

	-- La pancarta mira hacia atrás: el jugador la lee al llegar por el sendero.
	local centroPancarta = centro + Vector3.new(0, 6.9, 0)
	cartelTexto({
		nombre = "PancartaMeta",
		tamano = Vector3.new(6, 3, 0.3),
		cf = CFrame.lookAt(centroPancarta, centroPancarta - tangenteMeta),
		texto = Localization.L("meta"),
		fondo = COLOR_VERDE,
		colorTablero = COLOR_VERDE,
		colorTexto = COLOR_CARTEL,
		padre = meta,
	})

	local coloresBanderin = { COLOR_ROJO, COLOR_POSTE, COLOR_VERDE, COLOR_CARTEL }
	local offsetsBanderin = { -4.3, -3.45, 3.45, 4.3 }
	for i, offset in ipairs(offsetsBanderin) do
		local pos = centro + normal * offset + Vector3.new(0, 7.55, 0)
		pieza({
			nombre = "Banderin",
			tamano = Vector3.new(0.6, 1.3, 0.16),
			cf = CFrame.lookAt(pos, pos - tangenteMeta),
			color = coloresBanderin[i],
			material = Enum.Material.Fabric,
			padre = meta,
			colision = false,
			consulta = false,
		})
	end

	-- Círculo de piedras decorativo: no bloquea la marcha ni intercepta raycasts.
	local radioPiedras = 6.5
	for i = 1, 12 do
		local angulo = (i - 1) / 12 * math.pi * 2
		local pos = centro + Vector3.new(math.cos(angulo) * radioPiedras, 0.28, math.sin(angulo) * radioPiedras)
		pieza({
			nombre = "PiedraMeta",
			tamano = Vector3.new(1.4, 0.55, 1.1),
			cf = CFrame.new(pos) * CFrame.Angles(0, -angulo, 0),
			color = COLOR_ROCA,
			material = Enum.Material.Slate,
			padre = meta,
			colision = false,
			consulta = false,
		})
	end

	for _, lado in ipairs({ -1, 1 }) do
		local baseAntorcha = centro + normal * (7.2 * lado)
		pieza({
			nombre = "AntorchaMeta",
			tamano = Vector3.new(0.28, 3, 0.28),
			cf = CFrame.new(baseAntorcha + Vector3.new(0, 1.5, 0)),
			color = COLOR_MADERA,
			material = Enum.Material.Wood,
			padre = meta,
			colision = false,
			consulta = false,
		})
		local llama = pieza({
			nombre = "LlamaMeta",
			tamano = Vector3.new(0.7, 0.7, 0.7),
			cf = CFrame.new(baseAntorcha + Vector3.new(0, 3.2, 0)),
			color = COLOR_POSTE,
			material = Enum.Material.Neon,
			forma = Enum.PartType.Ball,
			padre = meta,
			colision = false,
			consulta = false,
		})
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 214, 120)
		luz.Brightness = 1.2
		luz.Range = 12
		luz.Shadows = false
		luz.Parent = llama
	end

	return true
end

-- Reutilizada por la ronda rápida para su propia meta (fase 11 · L4/B6).
StageService.ConstruirMeta = construirMeta

-- Idempotente: quita la etapa anterior sin tocar el terreno ni la ruta.
function StageService.Limpiar()
	local anterior = workspace:FindFirstChild("Etapa0")
	if anterior then
		anterior:Destroy()
	end
end

function StageService.Construir(semilla)
	StageService.Limpiar()
	local ruta = TerrenoService.ConstruirHistoria(semilla)

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

	-- Postes y carteles en las mismas distancias que usa MatchService para los checkpoints.
	-- La base es la ruta: los tiles lejanos aún no están cargados y AlturaSuelo no sirve.
	local cada = Config.Etapa0.CheckpointCada
	local checkpoints = 0
	for d = cada, ruta.Longitud - 20, cada do
		local punto, tangente = ruta:PuntoEnDistancia(d)
		local normal = tangente:Cross(Vector3.yAxis).Unit
		local base = punto + normal * (ANCHO / 2 + 2)
		local suelo = punto.Y - 0.5
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

	-- Meta y tienda no son críticas para la carrera: un fallo se avisa y no tumba el mapa.
	local okMeta, errMeta = pcall(construirMeta, carpeta, ruta)
	if not okMeta then
		warn("[Stage] meta no construida: " .. tostring(errMeta))
	end
	local okTienda, errTienda = pcall(TiendaCampamento.Construir, carpeta, puntoInicio, tangenteInicio)
	if not okTienda then
		warn("[Stage] tienda no construida: " .. tostring(errTienda))
	end

	print(("[Stage] etapa 0: %d studs, %d checkpoints, tienda %s, meta %s"):format(
		math.floor(ruta.Longitud),
		checkpoints,
		okTienda and "ok" or "error",
		okMeta and "ok" or "error"
	))
end

return StageService
