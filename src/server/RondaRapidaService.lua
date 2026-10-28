-- RondaRapidaService: caminos modulares con semilla para las rondas rápidas (plan §4.2).
-- Solo construcción y limpieza del mapa: quién lo invoca se decide en la integración.
-- Todo son primitivas; los meshes/terreno reales llegan con los .glb del spike S2 (fase de arte).

local RondaRapidaService = {}

-- Paleta del ADN (docs/design/design-dna.md) y constantes del camino
local ANCHO = 6 -- sendero normal; el puente usa 4 y el estrecho 3
local COLOR_SENDERO = Color3.fromRGB(139, 110, 78) -- tierra #8B6E4E
local COLOR_MADERA = Color3.fromRGB(92, 58, 33) -- marrón #5C3A21
local COLOR_COPA = Color3.fromRGB(76, 140, 74) -- verde bosque #4C8C4A
local COLOR_ROCA = Color3.fromRGB(110, 106, 100)
local LARGO_MIN = 150 -- plan §4.2: camino de ~150-250 studs

-- Helper igual que el de StageService, con dos extras: forma (Ball) y colidable
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
	if props.forma then
		p.Shape = props.forma
	end
	if props.colidable ~= nil then
		p.CanCollide = props.colidable
	end
	p.Parent = props.padre
	return p
end

-- Elige tipo de segmento por peso; recta es el más probable
local function elegirTipo(rng, permitirDificiles)
	local opciones = {
		{ tipo = "recta", peso = 4 },
		{ tipo = "curva", peso = 3 },
		{ tipo = "rocas", peso = 2 },
	}
	if permitirDificiles then
		table.insert(opciones, { tipo = "puente", peso = 2 })
		table.insert(opciones, { tipo = "estrecho", peso = 2 })
	end
	local total = 0
	for _, o in ipairs(opciones) do
		total += o.peso
	end
	local r = rng:NextNumber(0, total)
	for _, o in ipairs(opciones) do
		r -= o.peso
		if r <= 0 then
			return o.tipo
		end
	end
	return "recta"
end

function RondaRapidaService.ConstruirConSemilla(semilla)
	semilla = math.floor(tonumber(semilla) or os.time())
	RondaRapidaService.Limpiar() -- rejugable: fuera el camino anterior

	local rng = Random.new(semilla) -- TODO lo aleatorio sale de aquí: determinista por semilla
	local carpeta = Instance.new("Folder")
	carpeta.Name = "RondaRapida"
	carpeta.Parent = workspace

	local longitud = 0 -- cada segmento suma aquí su largo

	-- Convención: el cf de entrada va sobre el eje del camino (Y = media altura del sendero)
	-- y su LookVector apunta en la dirección de avance. Cada segmento devuelve el de salida.

	-- 1) Sendero recto de tierra, con 2-3 árboles de adorno a los lados
	local function segmentoRecta(cf, largo)
		pieza({ nombre = "Sendero", tamano = Vector3.new(ANCHO, 1, largo), cf = cf * CFrame.new(0, 0, -largo / 2), color = COLOR_SENDERO, material = Enum.Material.Ground, padre = carpeta })
		for _ = 1, rng:NextInteger(2, 3) do
			local z = -rng:NextNumber(4, largo - 2)
			local lado = rng:NextInteger(0, 1) == 0 and -1 or 1
			local x = lado * (ANCHO / 2 + rng:NextNumber(3, 9))
			local altura = rng:NextNumber(9, 15)
			pieza({ nombre = "Tronco", tamano = Vector3.new(1.2, altura, 1.2), cf = cf * CFrame.new(x, altura / 2 - 0.5, z), color = COLOR_MADERA, material = Enum.Material.Wood, padre = carpeta })
			pieza({ nombre = "Copa", tamano = Vector3.new(6, 5, 6), cf = cf * CFrame.new(x, altura + 1.5, z), color = COLOR_COPA, material = Enum.Material.Grass, padre = carpeta })
		end
		longitud += largo
		return cf * CFrame.new(0, 0, -largo)
	end

	-- 2) Dos tramos con giro de ±20-40° (parche en la bisagra para tapar la cuña del giro)
	local function segmentoCurva(cf, angulo)
		local l1 = rng:NextInteger(10, 14)
		local l2 = rng:NextInteger(10, 14)
		pieza({ nombre = "Curva", tamano = Vector3.new(ANCHO, 1, l1), cf = cf * CFrame.new(0, 0, -l1 / 2), color = COLOR_SENDERO, material = Enum.Material.Ground, padre = carpeta })
		local pivote = cf * CFrame.new(0, 0, -l1)
		pieza({ nombre = "CurvaBisagra", tamano = Vector3.new(ANCHO, 1, ANCHO), cf = pivote, color = COLOR_SENDERO, material = Enum.Material.Ground, padre = carpeta })
		local cf2 = pivote * CFrame.Angles(0, math.rad(angulo), 0)
		pieza({ nombre = "Curva", tamano = Vector3.new(ANCHO, 1, l2), cf = cf2 * CFrame.new(0, 0, -l2 / 2), color = COLOR_SENDERO, material = Enum.Material.Ground, padre = carpeta })
		longitud += l1 + l2
		return cf2 * CFrame.new(0, 0, -l2)
	end

	-- 3) Pasarela de tablones (4 studs) 2 studs por encima de un hueco (no hay suelo debajo);
	-- dos escalones intermedios para subir y bajar sin necesidad de saltar
	local function segmentoPuente(cf)
		local largo = rng:NextInteger(12, 18)
		pieza({ nombre = "Paso", tamano = Vector3.new(4, 1, 2), cf = cf * CFrame.new(0, 1, -1), color = COLOR_MADERA, material = Enum.Material.WoodPlanks, padre = carpeta })
		pieza({ nombre = "Tablon", tamano = Vector3.new(4, 0.6, largo), cf = cf * CFrame.new(0, 2.2, -(2 + largo / 2)), color = COLOR_MADERA, material = Enum.Material.WoodPlanks, padre = carpeta })
		pieza({ nombre = "Paso", tamano = Vector3.new(4, 1, 2), cf = cf * CFrame.new(0, 1, -(2 + largo + 1)), color = COLOR_MADERA, material = Enum.Material.WoodPlanks, padre = carpeta })
		longitud += 4 + largo
		return cf * CFrame.new(0, 0, -(4 + largo))
	end

	-- 4) Tramo que se estrecha a 3 studs flanqueado por rocas (Blocks de Slate)
	local function segmentoEstrecho(cf)
		local largo = rng:NextInteger(8, 12)
		pieza({ nombre = "Entrada", tamano = Vector3.new(ANCHO, 1, 3), cf = cf * CFrame.new(0, 0, -1.5), color = COLOR_SENDERO, material = Enum.Material.Ground, padre = carpeta })
		pieza({ nombre = "PasoEstrecho", tamano = Vector3.new(3, 1, largo), cf = cf * CFrame.new(0, 0, -(3 + largo / 2)), color = COLOR_SENDERO, material = Enum.Material.Ground, padre = carpeta })
		pieza({ nombre = "Salida", tamano = Vector3.new(ANCHO, 1, 3), cf = cf * CFrame.new(0, 0, -(3 + largo + 1.5)), color = COLOR_SENDERO, material = Enum.Material.Ground, padre = carpeta })
		for _ = 1, rng:NextInteger(3, 5) do
			local lado = rng:NextInteger(0, 1) == 0 and -1 or 1
			local s = rng:NextNumber(1.5, 3)
			local z = -rng:NextNumber(3, 3 + largo)
			local x = lado * (1.5 + s / 2 + rng:NextNumber(0, 0.8))
			pieza({ nombre = "Roca", tamano = Vector3.new(s, s * 0.9, s), cf = cf * CFrame.new(x, 0.5 + s * 0.4, z), color = COLOR_ROCA, material = Enum.Material.Slate, padre = carpeta })
		end
		longitud += 6 + largo
		return cf * CFrame.new(0, 0, -(6 + largo))
	end

	-- 5) Sendero normal con 3-6 rocas sueltas (Bolas de Slate, con colisión) encima
	local function segmentoRocasSueltas(cf)
		local largo = rng:NextInteger(10, 14)
		pieza({ nombre = "Sendero", tamano = Vector3.new(ANCHO, 1, largo), cf = cf * CFrame.new(0, 0, -largo / 2), color = COLOR_SENDERO, material = Enum.Material.Ground, padre = carpeta })
		for _ = 1, rng:NextInteger(3, 6) do
			local d = rng:NextNumber(1.5, 3)
			pieza({ nombre = "Roca", tamano = Vector3.new(d, d, d), forma = Enum.PartType.Ball, colidable = true, cf = cf * CFrame.new(rng:NextNumber(-2, 2), 0.5 + d * 0.35, -rng:NextNumber(2, largo - 2)), color = COLOR_ROCA, material = Enum.Material.Slate, padre = carpeta })
		end
		longitud += largo
		return cf * CFrame.new(0, 0, -largo)
	end

	-- Camino: 8-12 segmentos al azar; puente y estrecho solo en la segunda mitad (dificultad creciente)
	local nSegmentos = rng:NextInteger(8, 12)
	local inicio = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0) -- origen mirando a +X
	local cf = inicio
	for i = 1, nSegmentos do
		local tipo = elegirTipo(rng, i > nSegmentos / 2)
		if tipo == "recta" then
			cf = segmentoRecta(cf, rng:NextInteger(14, 22))
		elseif tipo == "curva" then
			local giro = rng:NextInteger(20, 40) * (rng:NextInteger(0, 1) == 0 and -1 or 1)
			cf = segmentoCurva(cf, giro)
		elseif tipo == "puente" then
			cf = segmentoPuente(cf)
		elseif tipo == "estrecho" then
			cf = segmentoEstrecho(cf)
		else
			cf = segmentoRocasSueltas(cf)
		end
	end

	-- Presupuesto del plan (~150-250 studs): si salió corto, rematamos con rectas
	local extra = 0
	while longitud < LARGO_MIN and extra < 3 do
		cf = segmentoRecta(cf, rng:NextInteger(14, 22))
		extra += 1
	end

	-- Spawn pegado al comienzo del camino
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(ANCHO, 1, 8)
	spawn.CFrame = inicio * CFrame.new(0, 0, 4)
	spawn.Color = COLOR_MADERA
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = carpeta

	print(("[RondaRapida] camino con semilla %d: %d segmentos, %d studs"):format(semilla, nSegmentos + extra, longitud))
	return carpeta
end

function RondaRapidaService.Limpiar()
	local anterior = workspace:FindFirstChild("RondaRapida")
	if anterior then
		anterior:Destroy()
	end
end

return RondaRapidaService
