-- TerrenoService: montaña voxel, cinta del sendero y bosque determinista (fase 8).
-- El servidor construye todo; los clientes solo reciben la escena replicada.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerrenoConfig = require(ReplicatedStorage.Shared.Config.TerrenoConfig)
local Ruta = require(ReplicatedStorage.Shared.Ruta)

local TerrenoService = {}

local MUNDO = TerrenoConfig.Mundo
local CAMINO = TerrenoConfig.Camino
local BOSQUE = TerrenoConfig.Bosque
local ROCAS = TerrenoConfig.Rocas
local RAPIDA = TerrenoConfig.Rapida
local CLAROS = TerrenoConfig.Claros
local AMBIENTE = TerrenoConfig.Ambiente

local COLOR_SENDERO = CAMINO.Color
local NOMBRE_CARPETA = "Terreno"

local rutaActual = nil

local function mezclaSuave(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function distanciaXZ(x, z, cx, cz)
	local dx, dz = x - cx, z - cz
	return math.sqrt(dx * dx + dz * dz)
end

local function aplicarClaros(x, z, altura)
	local d = distanciaXZ(x, z, CLAROS.Inicio.X, CLAROS.Inicio.Z)
	if d <= CLAROS.Inicio.Radio then
		return CLAROS.Inicio.Y
	end
	if d < CLAROS.Inicio.Radio + CLAROS.Inicio.Transicion then
		local t = mezclaSuave((d - CLAROS.Inicio.Radio) / CLAROS.Inicio.Transicion)
		return CLAROS.Inicio.Y + (altura - CLAROS.Inicio.Y) * t
	end

	d = distanciaXZ(x, z, CLAROS.Madriguera.X, CLAROS.Madriguera.Z)
	if d <= CLAROS.Madriguera.Radio then
		return CLAROS.Madriguera.Y
	end
	if d < CLAROS.Madriguera.Radio + CLAROS.Madriguera.Transicion then
		local t = mezclaSuave((d - CLAROS.Madriguera.Radio) / CLAROS.Madriguera.Transicion)
		return CLAROS.Madriguera.Y + (altura - CLAROS.Madriguera.Y) * t
	end
	return altura
end

-- fBM de 4 octavas + montaña radial + crestas + borde de cuenca.
local function crearAltura(semilla)
	local offX = (semilla % 997) * 0.37
	local offZ = (math.floor(semilla / 997) % 997) * 0.53
	local eje = semilla * 0.0001

	local function fbm(x, z)
		local total, amplitud, frecuencia, norma = 0, 1, 1, 0
		for i = 1, 4 do
			total += math.noise(x * frecuencia / 110 + offX + i * 17.3, z * frecuencia / 110 + offZ + i * 9.7, eje + i * 4.1) * 2 * amplitud
			norma += amplitud
			amplitud *= 0.5
			frecuencia *= 2.03
		end
		return total / norma
	end

	return function(x, z)
		local n = fbm(x, z)
		local altura = 2 + (n * 0.5 + 0.5) * 5

		local dist = distanciaXZ(x, z, MUNDO.Centro.X, MUNDO.Centro.Y)
		local f = math.clamp(1 - dist / MUNDO.RadioMontana, 0, 1)
		altura += f * f * MUNDO.AlturaMontana
		local dist2 = distanciaXZ(x, z, MUNDO.CentroSecundario.X, MUNDO.CentroSecundario.Y)
		local f2 = math.clamp(1 - dist2 / MUNDO.RadioSecundario, 0, 1)
		altura += f2 * f2 * MUNDO.AlturaSecundaria
		local cresta = 1 - math.abs(math.noise(x / 61 + offX * 0.7, z / 61 + offZ * 0.7, eje + 31.7) * 2)
		altura += f * cresta * 4.5

		local borde = math.min(x - MUNDO.MinX, MUNDO.MaxX - x, z - MUNDO.MinZ, MUNDO.MaxZ - z)
		if borde < 45 then
			local t = math.clamp(1 - math.max(borde, 0) / 45, 0, 1)
			altura += t * t * 18
		end
		return aplicarClaros(x, z, math.min(altura, MUNDO.TechoY - 2))
	end
end

local function alturaConSendero(x, z, ruta, natural)
	local dist, _, punto = ruta:CercanoXZ(x, z)
	local objetivo = punto.Y - 0.5
	local media = CAMINO.Ancho / 2 + 2
	if dist <= media then
		return objetivo, dist
	end
	if dist < CAMINO.Corredor then
		local t = mezclaSuave((dist - media) / (CAMINO.Corredor - media))
		return objetivo + (natural - objetivo) * t, dist
	end
	return natural, dist
end

local function nuevaParte(props)
	local p = Instance.new("Part")
	p.Name = props.nombre
	p.Anchored = true
	p.Size = props.tamano
	p.CFrame = props.cf
	p.Color = props.color
	p.Material = props.material or Enum.Material.Grass
	p.Shape = props.forma or Enum.PartType.Block
	p.CanCollide = props.colision ~= false
	p.CanQuery = props.consulta ~= false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.transparencia then
		p.Transparency = props.transparencia
	end
	p.Parent = props.padre
	return p
end

local function escribirTerreno(ruta, semilla)
	local region = Region3.new(
		Vector3.new(MUNDO.MinX, MUNDO.BaseY, MUNDO.MinZ),
		Vector3.new(MUNDO.MaxX, MUNDO.TechoY, MUNDO.MaxZ)
	):ExpandToGrid(MUNDO.Celda)
	local celda = MUNDO.Celda
	local nx = math.floor(region.Size.X / celda + 0.5)
	local ny = math.floor(region.Size.Y / celda + 0.5)
	local nz = math.floor(region.Size.Z / celda + 0.5)

	local materiales, ocupaciones = {}, {}
	for ix = 1, nx do
		materiales[ix] = {}
		ocupaciones[ix] = {}
		for iy = 1, ny do
			materiales[ix][iy] = table.create(nz, Enum.Material.Air)
			ocupaciones[ix][iy] = table.create(nz, 0)
		end
	end

	local alturaNatural = crearAltura(semilla)
	local alturas = table.create(nx)
	local distancias = table.create(nx)
	local minimo = region.CFrame.Position - region.Size * 0.5
	for ix = 1, nx do
		local x = minimo.X + (ix - 0.5) * celda
		alturas[ix] = table.create(nz)
		distancias[ix] = table.create(nz)
		for iz = 1, nz do
			local z = minimo.Z + (iz - 0.5) * celda
			local h, dist = alturaConSendero(x, z, ruta, alturaNatural(x, z))
			alturas[ix][iz] = h
			distancias[ix][iz] = dist
		end
	end

	for ix = 1, nx do
		for iz = 1, nz do
			local h = alturas[ix][iz]
			local hx = alturas[math.min(ix + 1, nx)][iz] - alturas[math.max(ix - 1, 1)][iz]
			local hz = alturas[ix][math.min(iz + 1, nz)] - alturas[ix][math.max(iz - 1, 1)]
			local pendiente = math.sqrt((hx / (2 * celda)) ^ 2 + (hz / (2 * celda)) ^ 2)

			local material
			if distancias[ix][iz] <= CAMINO.Ancho / 2 + 1 then
				material = Enum.Material.Ground
			elseif h > MUNDO.NieveDesde then
				material = Enum.Material.Snow
			elseif pendiente > 0.65 or h > MUNDO.RocaDesde then
				material = Enum.Material.Rock
			else
				material = Enum.Material.Grass
			end

			local llenas = math.clamp(math.floor((h - minimo.Y) / celda), 0, ny)
			for iy = 1, llenas do
				materiales[ix][iy][iz] = material
				ocupaciones[ix][iy][iz] = 1
			end
			if llenas < ny then
				local fondo = minimo.Y + llenas * celda
				local fraccion = math.clamp((h - fondo) / celda, 0, 1)
				if fraccion > 0 then
					materiales[ix][llenas + 1][iz] = material
					ocupaciones[ix][llenas + 1][iz] = fraccion
				end
			end
		end
	end

	workspace.Terrain:WriteVoxels(region, celda, materiales, ocupaciones)
	return nx * ny * nz
end

local function construirCinta(ruta, padre)
	local separacion = CAMINO.SeparacionCinta
	local ancho = CAMINO.Ancho
	local grosor = CAMINO.Grosor
	local piezas = 0
	local d = 0
	while d < ruta.Longitud - 0.01 do
		local d2 = math.min(d + separacion, ruta.Longitud)
		local p1, t1 = ruta:PuntoEnDistancia(d)
		local p2 = ruta:PuntoEnDistancia(d2)
		local dx, dy, dz = p2.X - p1.X, p2.Y - p1.Y, p2.Z - p1.Z
		local largo = math.sqrt(dx * dx + dy * dy + dz * dz)
		local direccion = largo > 1e-4 and Vector3.new(dx / largo, dy / largo, dz / largo) or t1
		local medio = (p1 + p2) * 0.5
		local centro = Vector3.new(medio.X, medio.Y - grosor / 2, medio.Z)

		nuevaParte({
			nombre = "Sendero",
			tamano = Vector3.new(ancho, grosor, largo + 1.5),
			cf = CFrame.lookAt(centro, centro + direccion),
			color = COLOR_SENDERO,
			material = Enum.Material.Ground,
			colision = true,
			consulta = true,
			padre = padre,
		})
		piezas += 1
		if d2 >= ruta.Longitud - 1e-4 then
			break
		end
		d = d2
	end
	return piezas
end

local function construirBosque(ruta, semilla, carpetaBosque, carpetaRocas)
	local rng = Random.new(semilla)
	local alturaNatural = crearAltura(semilla)

	local function suelo(x, z)
		return alturaConSendero(x, z, ruta, alturaNatural(x, z))
	end

	local function pendiente(x, z)
		local dx = suelo(x + 2, z) - suelo(x - 2, z)
		local dz = suelo(x, z + 2) - suelo(x, z - 2)
		return math.sqrt((dx / 4) ^ 2 + (dz / 4) ^ 2)
	end

	local function dentroMapa(x, z, margen)
		return x >= MUNDO.MinX + margen and x <= MUNDO.MaxX - margen
			and z >= MUNDO.MinZ + margen and z <= MUNDO.MaxZ - margen
	end

	local function enClaro(x, z)
		if distanciaXZ(x, z, CLAROS.Inicio.X, CLAROS.Inicio.Z) < CLAROS.Inicio.RadioBosque then
			return true
		end
		return distanciaXZ(x, z, CLAROS.Madriguera.X, CLAROS.Madriguera.Z) < CLAROS.Madriguera.RadioBosque
	end

	local rejilla = {}
	local separacion = BOSQUE.SeparacionMinima

	local function libreDeArboles(x, z)
		local cx = math.floor(x / separacion)
		local cz = math.floor(z / separacion)
		for dx = -1, 1 do
			local columna = rejilla[cx + dx]
			if columna then
				for dz = -1, 1 do
					local lista = columna[cz + dz]
					if lista then
						for _, p in ipairs(lista) do
							if (x - p.X) ^ 2 + (z - p.Z) ^ 2 < separacion * separacion then
								return false
							end
						end
					end
				end
			end
		end
		return true
	end

	local function anotarArbol(x, z)
		local cx = math.floor(x / separacion)
		local cz = math.floor(z / separacion)
		rejilla[cx] = rejilla[cx] or {}
		rejilla[cx][cz] = rejilla[cx][cz] or {}
		table.insert(rejilla[cx][cz], Vector3.new(x, 0, z))
	end

	local function colorVariado(color)
		local factor = rng:NextNumber(0.9, 1.08)
		return Color3.new(
			math.clamp(color.R * factor, 0, 1),
			math.clamp(color.G * factor, 0, 1),
			math.clamp(color.B * factor, 0, 1)
		)
	end

	local function plantarArbol(x, z, base, altura)
		local conifera = rng:NextNumber() < BOSQUE.ProporcionConifera
		local alturaTronco = altura * (conifera and rng:NextNumber(0.5, 0.62) or rng:NextNumber(0.42, 0.5))
		local diametro = math.max(0.8, altura * rng:NextNumber(0.05, 0.07))
		nuevaParte({
			nombre = "Tronco",
			tamano = Vector3.new(alturaTronco, diametro, diametro),
			cf = CFrame.new(x, base + alturaTronco / 2 - 0.35, z) * CFrame.Angles(0, 0, math.pi / 2),
			color = BOSQUE.Colores.Tronco,
			material = Enum.Material.Wood,
			forma = Enum.PartType.Cylinder,
			colision = true,
			consulta = true,
			padre = carpetaBosque,
		})

		local niveles
		local color
		if conifera then
			color = BOSQUE.Colores.Conifera
			niveles = {
				{ h = 0.48, r = 0.27, ox = 0, oz = 0 },
				{ h = 0.68, r = 0.20, ox = 0, oz = 0 },
				{ h = 0.86, r = 0.14, ox = 0, oz = 0 },
			}
		else
			color = BOSQUE.Colores.Hoja
			niveles = {
				{ h = 0.60, r = 0.21, ox = 0, oz = 0 },
				{ h = 0.74, r = 0.18, ox = -0.10, oz = 0.06 },
				{ h = 0.86, r = 0.14, ox = 0.09, oz = -0.07 },
			}
		end

		for _, nivel in ipairs(niveles) do
			local radio = altura * nivel.r * rng:NextNumber(0.9, 1.1)
			local ox = (nivel.ox + rng:NextNumber(-0.04, 0.04)) * altura
			local oz = (nivel.oz + rng:NextNumber(-0.04, 0.04)) * altura
			nuevaParte({
				nombre = "Copa",
				tamano = Vector3.new(radio * 2, radio * 2 * rng:NextNumber(0.9, 1.15), radio * 2),
				cf = CFrame.new(x + ox, base + altura * nivel.h, z + oz),
				color = colorVariado(color),
				material = Enum.Material.Grass,
				forma = Enum.PartType.Ball,
				colision = false,
				consulta = false,
				padre = carpetaBosque,
			})
		end
	end

	local arboles = 0
	local intentos = BOSQUE.Arboles * BOSQUE.IntentosPorArbol
	for _ = 1, intentos do
		if arboles >= BOSQUE.Arboles then
			break
		end
		local x = rng:NextNumber(MUNDO.MinX + BOSQUE.MargenMapa, MUNDO.MaxX - BOSQUE.MargenMapa)
		local z = rng:NextNumber(MUNDO.MinZ + BOSQUE.MargenMapa, MUNDO.MaxZ - BOSQUE.MargenMapa)
		if dentroMapa(x, z, BOSQUE.MargenMapa) and not enClaro(x, z) then
			local dist = ruta:CercanoXZ(x, z)
			if dist >= BOSQUE.DistanciaMinimaCamino and libreDeArboles(x, z) then
				local base = suelo(x, z)
				if base <= BOSQUE.AlturaMaximaArbol and pendiente(x, z) <= BOSQUE.PendienteMaxima then
					local altura = rng:NextNumber(BOSQUE.AlturaMinima, BOSQUE.AlturaMaxima)
					if rng:NextNumber() < 0.08 then
						altura *= 1.3 -- algún ejemplar viejo rompe la silueta uniforme
					end
					plantarArbol(x, z, base, altura)
					anotarArbol(x, z)
					arboles += 1
				end
			end
		end
	end

	local arbustos = 0
	for _ = 1, BOSQUE.Arbustos * 8 do
		if arbustos >= BOSQUE.Arbustos then
			break
		end
		local x = rng:NextNumber(MUNDO.MinX + BOSQUE.MargenMapa, MUNDO.MaxX - BOSQUE.MargenMapa)
		local z = rng:NextNumber(MUNDO.MinZ + BOSQUE.MargenMapa, MUNDO.MaxZ - BOSQUE.MargenMapa)
		if dentroMapa(x, z, BOSQUE.MargenMapa) and not enClaro(x, z) then
			local dist = ruta:CercanoXZ(x, z)
			if dist >= BOSQUE.DistanciaMinimaCamino then
				local base = suelo(x, z)
				for _ = 1, 2 do
					local alto = rng:NextNumber(BOSQUE.AlturaMinimaArbusto, BOSQUE.AlturaMaximaArbusto)
					nuevaParte({
						nombre = "Arbusto",
						tamano = Vector3.new(alto, alto * rng:NextNumber(0.8, 1.1), alto),
						cf = CFrame.new(x + rng:NextNumber(-0.9, 0.9), base + alto * 0.4, z + rng:NextNumber(-0.9, 0.9)),
						color = colorVariado(BOSQUE.Colores.Arbusto),
						material = Enum.Material.Grass,
						forma = Enum.PartType.Ball,
						colision = false,
						consulta = false,
						padre = carpetaBosque,
					})
				end
				arbustos += 1
			end
		end
	end

	local rocas = 0
	for _ = 1, BOSQUE.Rocas * 10 do
		if rocas >= BOSQUE.Rocas then
			break
		end
		local x = rng:NextNumber(MUNDO.MinX + ROCAS.MargenMapa, MUNDO.MaxX - ROCAS.MargenMapa)
		local z = rng:NextNumber(MUNDO.MinZ + ROCAS.MargenMapa, MUNDO.MaxZ - ROCAS.MargenMapa)
		if dentroMapa(x, z, ROCAS.MargenMapa) and not enClaro(x, z) then
			local dist = ruta:CercanoXZ(x, z)
			if dist >= BOSQUE.DistanciaMinimaCamino then
				local tamano = rng:NextNumber(ROCAS.TamanoMin, ROCAS.TamanoMax)
				local altura = tamano * rng:NextNumber(0.7, 1)
				nuevaParte({
					nombre = "Roca",
					tamano = Vector3.new(tamano, altura, tamano * rng:NextNumber(0.8, 1.2)),
					cf = CFrame.new(x, suelo(x, z) + altura * 0.35, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
					color = BOSQUE.Colores.Roca,
					material = Enum.Material.Slate,
					forma = rng:NextInteger(0, 1) == 0 and Enum.PartType.Ball or Enum.PartType.Block,
					colision = true,
					consulta = true,
					padre = carpetaRocas,
				})
				rocas += 1
			end
		end
	end

	return arboles, arbustos, rocas
end

local function construirLimites(padre)
	local ancho = MUNDO.MaxX - MUNDO.MinX
	local fondo = MUNDO.MaxZ - MUNDO.MinZ
	local alto = 200
	local centroY = 80
	local centroX = (MUNDO.MinX + MUNDO.MaxX) / 2
	local centroZ = (MUNDO.MinZ + MUNDO.MaxZ) / 2
	local limites = {
		{ nombre = "LimiteOeste", tamano = Vector3.new(8, alto, fondo + 16), pos = Vector3.new(MUNDO.MinX, centroY, centroZ) },
		{ nombre = "LimiteEste", tamano = Vector3.new(8, alto, fondo + 16), pos = Vector3.new(MUNDO.MaxX, centroY, centroZ) },
		{ nombre = "LimiteNorte", tamano = Vector3.new(ancho + 16, alto, 8), pos = Vector3.new(centroX, centroY, MUNDO.MinZ) },
		{ nombre = "LimiteSur", tamano = Vector3.new(ancho + 16, alto, 8), pos = Vector3.new(centroX, centroY, MUNDO.MaxZ) },
	}
	for _, limite in ipairs(limites) do
		nuevaParte({
			nombre = limite.nombre,
			tamano = limite.tamano,
			cf = CFrame.new(limite.pos),
			color = Color3.new(0, 0, 0),
			material = Enum.Material.SmoothPlastic,
			colision = true,
			consulta = false,
			transparencia = 1,
			padre = padre,
		})
	end
end

local function asegurarEfecto(clase, nombre)
	local existente = Lighting:FindFirstChild(nombre)
	if existente and not existente:IsA(clase) then
		existente:Destroy()
		existente = nil
	end
	if not existente then
		existente = Instance.new(clase)
		existente.Name = nombre
		existente.Parent = Lighting
	end
	return existente
end

local function aplicarAmbiente()
	Lighting.ClockTime = AMBIENTE.ClockTime
	Lighting.Brightness = AMBIENTE.Brillo
	Lighting.Ambient = AMBIENTE.Ambiente
	Lighting.OutdoorAmbient = AMBIENTE.AmbienteExterior
	Lighting.ExposureCompensation = AMBIENTE.Exposicion

	local atmosfera = asegurarEfecto("Atmosphere", "AtmosferaBosque")
	atmosfera.Density = AMBIENTE.Atmosfera.Densidad
	atmosfera.Haze = AMBIENTE.Atmosfera.Bruma
	atmosfera.Color = AMBIENTE.Atmosfera.Color
	atmosfera.Decay = AMBIENTE.Atmosfera.Decaimiento
	atmosfera.Glare = AMBIENTE.Atmosfera.Deslumbramiento

	local color = asegurarEfecto("ColorCorrectionEffect", "ColorBosque")
	color.Saturation = AMBIENTE.ColorCorreccion.Saturacion
	color.Contrast = AMBIENTE.ColorCorreccion.Contraste
	color.TintColor = AMBIENTE.ColorCorreccion.Tinte
	color.Enabled = true

	local bloom = asegurarEfecto("BloomEffect", "BloomBosque")
	bloom.Intensity = AMBIENTE.Bloom.Intensidad
	bloom.Size = AMBIENTE.Bloom.Tamano
	bloom.Threshold = AMBIENTE.Bloom.Umbral
	bloom.Enabled = true
end

local function contarParts(carpeta)
	local total = 0
	for _, obj in ipairs(carpeta:GetDescendants()) do
		if obj:IsA("BasePart") then
			total += 1
		end
	end
	return total
end

local function construir(modo, semilla, ruta)
	local inicio = os.clock()
	TerrenoService.Limpiar()

	local carpeta = Instance.new("Folder")
	carpeta.Name = NOMBRE_CARPETA
	local camino = Instance.new("Folder")
	camino.Name = "Camino"
	camino.Parent = carpeta
	local bosque = Instance.new("Folder")
	bosque.Name = "Bosque"
	bosque.Parent = carpeta
	local rocas = Instance.new("Folder")
	rocas.Name = "Rocas"
	rocas.Parent = carpeta
	local limites = Instance.new("Folder")
	limites.Name = "Limites"
	limites.Parent = carpeta
	carpeta.Parent = workspace

	local celdas = escribirTerreno(ruta, semilla)
	local cintas = construirCinta(ruta, camino)
	construirLimites(limites)
	local arboles, arbustos, numRocas = construirBosque(ruta, semilla, bosque, rocas)
	aplicarAmbiente()
	rutaActual = ruta

	local parts = contarParts(carpeta)
	print(("[Terreno] %s · semilla %d · ruta %d studs (%d muestras) · %d árboles, %d arbustos, %d rocas · %d cintas · %d celdas · %d parts · %.3fs"):format(
		modo,
		semilla,
		math.floor(ruta.Longitud),
		#ruta.Puntos,
		arboles,
		arbustos,
		numRocas,
		cintas,
		celdas,
		parts,
		os.clock() - inicio
	))
end

local function rutaDeHistoria()
	local semilla = MUNDO.Semilla
	local alturaNatural = crearAltura(semilla)
	local waypoints = {}
	for i, w in ipairs(TerrenoConfig.Historia.Waypoints) do
		local y = i == 1 and CLAROS.Inicio.Y or alturaNatural(w.X, w.Z)
		waypoints[i] = Vector3.new(w.X, y, w.Z)
	end
	return Ruta.crear(waypoints, CAMINO.Paso, { PendienteMax = 0.22, Suavizado = 3 })
end

local function rutaRapida(semilla)
	local rng = Random.new(semilla)
	local alturaNatural = crearAltura(semilla)
	local centro = MUNDO.Centro

	local function dentroMapa(x, z)
		return x >= MUNDO.MinX + RAPIDA.MargenMapa and x <= MUNDO.MaxX - RAPIDA.MargenMapa
			and z >= MUNDO.MinZ + RAPIDA.MargenMapa and z <= MUNDO.MaxZ - RAPIDA.MargenMapa
	end

	local function lejosDeMadriguera(x, z)
		return distanciaXZ(x, z, CLAROS.Madriguera.X, CLAROS.Madriguera.Z) >= RAPIDA.SeparacionRuta
	end

	local function libreDePuntos(x, z, puntos)
		local limite = #puntos - 2
		for i = 1, limite do
			local p = puntos[i]
			if (x - p.X) ^ 2 + (z - p.Z) ^ 2 < RAPIDA.SeparacionRuta * RAPIDA.SeparacionRuta then
				return false
			end
		end
		return true
	end

	local maxWaypoints = math.min(RAPIDA.WaypointsMax, math.floor(RAPIDA.LongitudMax / RAPIDA.PasoMin) + 1)

	local function intento()
		local inicio
		for _ = 1, RAPIDA.IntentosInicio do
			local angulo = rng:NextNumber(0, math.pi * 2)
			local radio = rng:NextNumber(RAPIDA.RadioInicioMin, RAPIDA.RadioInicioMax)
			local x = centro.X + math.cos(angulo) * radio
			local z = centro.Y + math.sin(angulo) * radio
			if dentroMapa(x, z) and lejosDeMadriguera(x, z) then
				inicio = Vector3.new(x, 0, z)
				break
			end
		end
		if not inicio then
			return nil
		end

		local n = rng:NextInteger(RAPIDA.WaypointsMin, math.max(RAPIDA.WaypointsMin, maxWaypoints))
		local minimo = math.max(RAPIDA.LongitudMin, (n - 1) * RAPIDA.PasoMin)
		local objetivo = rng:NextNumber(math.min(minimo, RAPIDA.LongitudMax), RAPIDA.LongitudMax)

		local pasos = table.create(n - 1)
		local restante = objetivo
		for i = 1, n - 1 do
			local restantes = n - 1 - i
			local minResto = restantes * RAPIDA.PasoMin
			local maxResto = restantes * RAPIDA.PasoMax
			local minPaso = math.max(RAPIDA.PasoMin, restante - maxResto)
			local maxPaso = math.min(RAPIDA.PasoMax, restante - minResto)
			if maxPaso < minPaso then
				maxPaso = minPaso
			end
			local medio = restante / (restantes + 1)
			local p = math.clamp(rng:NextNumber(medio * 0.9, medio * 1.1), minPaso, maxPaso)
			pasos[i] = p
			restante -= p
		end

		local puntos = { inicio }
		local angulo = math.atan2(centro.Y - inicio.Z, centro.X - inicio.X) + math.rad(rng:NextNumber(-35, 35))
		for i = 1, n - 1 do
			local elegido
			for _ = 1, RAPIDA.IntentosWaypoint do
				local giro = math.rad(rng:NextNumber(-RAPIDA.GiroMax, RAPIDA.GiroMax))
				local nuevoAngulo = angulo + giro
				local x = puntos[#puntos].X + math.cos(nuevoAngulo) * pasos[i]
				local z = puntos[#puntos].Z + math.sin(nuevoAngulo) * pasos[i]
				if dentroMapa(x, z) and lejosDeMadriguera(x, z) and libreDePuntos(x, z, puntos) then
					elegido = Vector3.new(x, 0, z)
					angulo = nuevoAngulo
					break
				end
			end
			if not elegido then
				return nil
			end
			table.insert(puntos, elegido)
		end
		return puntos
	end

	local puntos
	for _ = 1, 12 do
		puntos = intento()
		if puntos then
			break
		end
	end

	if not puntos then
		local inicio = Vector3.new(centro.X - 180, 0, centro.Y)
		local angulo = math.atan2(centro.Y - inicio.Z, centro.X - inicio.X)
		puntos = { inicio }
		for _ = 1, 6 do
			local paso = RAPIDA.PasoMin
			local x = puntos[#puntos].X + math.cos(angulo) * paso
			local z = puntos[#puntos].Z + math.sin(angulo) * paso
			table.insert(puntos, Vector3.new(
				math.clamp(x, MUNDO.MinX + RAPIDA.MargenMapa, MUNDO.MaxX - RAPIDA.MargenMapa),
				0,
				math.clamp(z, MUNDO.MinZ + RAPIDA.MargenMapa, MUNDO.MaxZ - RAPIDA.MargenMapa)
			))
		end
	end

	local waypoints = {}
	for i, p in ipairs(puntos) do
		waypoints[i] = Vector3.new(p.X, alturaNatural(p.X, p.Z), p.Z)
	end
	return Ruta.crear(waypoints, CAMINO.Paso, { PendienteMax = 0.22, Suavizado = 3 })
end

function TerrenoService.ConstruirHistoria()
	local ruta = rutaDeHistoria()
	construir("historia", MUNDO.Semilla, ruta)
	return ruta
end

function TerrenoService.ConstruirRapida(semilla)
	local semillaFinal = math.floor(tonumber(semilla) or os.time())
	local ruta = rutaRapida(semillaFinal)
	construir("rapida", semillaFinal, ruta)
	return ruta
end

function TerrenoService.RutaActual()
	return rutaActual
end

function TerrenoService.AlturaSuelo(pos)
	if typeof(pos) ~= "Vector3" then
		return 0
	end
	local excluir = {}
	local terreno = workspace:FindFirstChild(NOMBRE_CARPETA)
	if terreno then
		for _, nombre in ipairs({ "Bosque", "Rocas", "Limites" }) do
			local hijo = terreno:FindFirstChild(nombre)
			if hijo then
				table.insert(excluir, hijo)
			end
		end
	end
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:FindFirstChildOfClass("Humanoid") then
			table.insert(excluir, obj)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluir
	params.IgnoreWater = true
	local resultado = workspace:Raycast(Vector3.new(pos.X, 400, pos.Z), Vector3.new(0, -600, 0), params)
	return resultado and resultado.Position.Y or 0
end

function TerrenoService.Limpiar()
	local anterior = workspace:FindFirstChild(NOMBRE_CARPETA)
	if anterior then
		anterior:Destroy()
	end
	workspace.Terrain:Clear()
	rutaActual = nil
end

return TerrenoService
