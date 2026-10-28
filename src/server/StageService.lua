-- StageService: etapa 0 sobre la ruta que genera el terreno (spawn, checkpoints, meta y tienda).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local TerrenoConfig = require(ReplicatedStorage.Shared.Config.TerrenoConfig)
local TerrenoService = require(script.Parent.TerrenoService)

local StageService = {}
StageService.TotalCheckpoints = 0 -- postes construidos; MatchService cobra exactamente estos

local ANCHO = TerrenoConfig.Camino.Ancho
local COLOR_MADERA = Color3.fromRGB(92, 58, 33) -- #5C3A21
local COLOR_POSTE = Color3.fromRGB(255, 201, 60) -- #FFC93C
local COLOR_CARTEL = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local COLOR_ROCA = Color3.fromRGB(110, 106, 100)
local COLOR_VERDE = Color3.fromRGB(76, 140, 74) -- #4C8C4A
local COLOR_ROJO = Color3.fromRGB(224, 69, 58) -- #E0453A

local function pieza(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.colision ~= false
	p.CanQuery = props.consulta ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.nombre
	p.Size = props.tamano
	p.CFrame = props.cf
	p.Color = props.color
	p.Material = props.material
	p.Shape = props.forma or Enum.PartType.Block
	p.Parent = props.padre
	return p
end

-- Cartel de madera con texto fijo del mundo (el servidor no cambia de idioma).
local function cartelTexto(props)
	local tablero = pieza({
		nombre = props.nombre,
		tamano = props.tamano,
		cf = props.cf,
		color = props.colorTablero or COLOR_MADERA,
		material = props.material or Enum.Material.Wood,
		padre = props.padre,
		colision = false,
		consulta = false,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Texto"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Adornee = tablero
	gui.Parent = tablero

	local texto = Instance.new("TextLabel")
	texto.Name = "Texto"
	texto.Size = UDim2.fromScale(1, 1)
	texto.BackgroundColor3 = props.fondo
	texto.BorderSizePixel = 0
	texto.Font = Enum.Font.GothamBlack
	texto.Text = props.texto
	texto.TextColor3 = props.colorTexto
	texto.TextScaled = true
	texto.TextWrapped = true
	texto.Parent = gui

	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop = UDim.new(0.08, 0)
	relleno.PaddingBottom = UDim.new(0.08, 0)
	relleno.PaddingLeft = UDim.new(0.06, 0)
	relleno.PaddingRight = UDim.new(0.06, 0)
	relleno.Parent = texto
	return tablero
end

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

-- Puesto del campamento a 12 studs del spawn, dentro de ProteccionInicio.
local function construirTienda(carpeta, puntoInicio, tangenteInicio)
	local normal = tangenteInicio:Cross(Vector3.yAxis).Unit
	local base = puntoInicio.Y - 0.5
	local centro = Vector3.new(puntoInicio.X, base, puntoInicio.Z) + normal * 12
	local cfTienda = CFrame.lookAt(centro, centro - normal) -- la cara frontal mira al sendero

	local tienda = Instance.new("Folder")
	tienda.Name = "TiendaCampamento"
	tienda.Parent = carpeta

	local mostrador = pieza({
		nombre = "MostradorTienda",
		tamano = Vector3.new(6, 1.2, 2.4),
		cf = cfTienda * CFrame.new(0, 0.6, 0),
		color = COLOR_MADERA,
		material = Enum.Material.WoodPlanks,
		padre = tienda,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TiendaInicio"
	prompt.ActionText = "ABRIR TIENDA"
	prompt.ObjectText = "Tienda del campamento"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = mostrador

	for _, x in ipairs({ -3.1, 3.1 }) do
		for _, z in ipairs({ -2.2, 2.2 }) do
			pieza({
				nombre = "PosteTienda",
				tamano = Vector3.new(0.45, 7.2, 0.45),
				cf = cfTienda * CFrame.new(x, 3.6, z),
				color = COLOR_MADERA,
				material = Enum.Material.Wood,
				padre = tienda,
				consulta = false,
			})
		end
	end

	pieza({
		nombre = "CumbreraTienda",
		tamano = Vector3.new(7, 0.35, 0.35),
		cf = cfTienda * CFrame.new(0, 7.8, 0),
		color = COLOR_MADERA,
		material = Enum.Material.Wood,
		padre = tienda,
		consulta = false,
	})

	-- Toldo a dos aguas: dos paneles inclinados desde la cumbrera hasta el alero.
	local inclinacion = math.atan2(1.4, 2.8)
	for _, lado in ipairs({ -1, 1 }) do
		pieza({
			nombre = "ToldoTienda",
			tamano = Vector3.new(7, 0.2, 3.2),
			cf = cfTienda * CFrame.new(0, 7.3, lado * 1.4) * CFrame.Angles(lado * inclinacion, 0, 0),
			color = COLOR_CARTEL,
			material = Enum.Material.Fabric,
			padre = tienda,
			colision = false,
			consulta = false,
		})
	end

	cartelTexto({
		nombre = "CartelTienda",
		tamano = Vector3.new(4.2, 1.5, 0.25),
		cf = cfTienda * CFrame.new(0, 5.9, -1.55),
		texto = string.upper(Localization.L("tienda")),
		fondo = COLOR_VERDE,
		colorTablero = COLOR_MADERA,
		colorTexto = COLOR_CARTEL,
		padre = tienda,
	})

	for i, x in ipairs({ -4.3, 4.3 }) do
		pieza({
			nombre = "CajaTienda",
			tamano = Vector3.new(1.2, 1.2, 1.2),
			cf = cfTienda * CFrame.new(x, 0.6, 1.2 + (i - 1) * 0.35) * CFrame.Angles(0, math.rad(8), 0),
			color = COLOR_MADERA,
			material = Enum.Material.WoodPlanks,
			padre = tienda,
		})
	end

	local farolillo = pieza({
		nombre = "FarolilloTienda",
		tamano = Vector3.new(0.5, 0.6, 0.5),
		cf = cfTienda * CFrame.new(0, 7.15, -0.9),
		color = COLOR_POSTE,
		material = Enum.Material.Neon,
		padre = tienda,
		colision = false,
		consulta = false,
	})
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 214, 120)
	luz.Brightness = 1
	luz.Range = 10
	luz.Shadows = false
	luz.Parent = farolillo

	return true
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
	local okTienda, errTienda = pcall(construirTienda, carpeta, puntoInicio, tangenteInicio)
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
