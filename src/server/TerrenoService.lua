-- TerrenoService (fase 9): cordillera voxel de ~6000 studs generada por teselas.
-- El mundo se construye por delante del grupo y se descarga por detrás, así que
-- la memoria y los parts se mantienen acotados aunque la ruta sea larga.
-- El servidor construye todo; los clientes solo reciben la escena replicada.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TerrenoConfig = require(ReplicatedStorage.Shared.Config.TerrenoConfig)
local Ruta = require(ReplicatedStorage.Shared.Ruta)

local TerrenoService = {}

local MUNDO = TerrenoConfig.Mundo
local CAMINO = TerrenoConfig.Camino
local BOSQUE = TerrenoConfig.Bosque
local ROCAS = TerrenoConfig.Rocas
local RAPIDA = TerrenoConfig.Rapida
local CLAROS = TerrenoConfig.Claros
local HISTORIA = TerrenoConfig.Historia
local AMBIENTE = TerrenoConfig.Ambiente

local TILE = MUNDO.Tile
local CELDA = MUNDO.Celda
local NOMBRE_CARPETA = "Terreno"
local COLOR_SENDERO = CAMINO.Color

local rutaActual = nil
local semillaActual = nil
local alturaNatural = nil -- cache de la función de altura de la semilla activa
local raiz = nil -- carpeta Terreno (todas las teselas)
local tiles = {} -- [clave] = registro de tesela
local tilesOrden = {} -- teselas relevantes ordenadas por progreso de ruta
local plazas = {} -- plazas planas: inicio, meta y madriguera
local streamingIniciado = false

local function claveTile(cx, cz)
	return cx .. ":" .. cz
end

local function mezclaSuave(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function distanciaXZ(x, z, cx, cz)
	local dx, dz = x - cx, z - cz
	return math.sqrt(dx * dx + dz * dz)
end

-- fBM de 4 octavas + cordillera de picos + crestas + borde de cuenca.
local function crearAltura(semilla)
	local offX = (semilla % 997) * 0.37
	local offZ = (math.floor(semilla / 997) % 997) * 0.53
	local eje = semilla * 0.0001
	local picos = MUNDO.Picos

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
		local altura = 2 + (n * 0.5 + 0.5) * 7

		for _, pico in ipairs(picos) do
			local dist = distanciaXZ(x, z, pico.X, pico.Z)
			local f = math.clamp(1 - dist / pico.Radio, 0, 1)
			altura += f * f * pico.Altura
		end

		local cresta = 1 - math.abs(math.noise(x / 61 + offX * 0.7, z / 61 + offZ * 0.7, eje + 31.7) * 2)
		altura += cresta * 4.5

		local borde = math.min(x - MUNDO.MinX, MUNDO.MaxX - x, z - MUNDO.MinZ, MUNDO.MaxZ - z)
		if borde < 60 then
			local t = math.clamp(1 - math.max(borde, 0) / 60, 0, 1)
			altura += t * t * 22
		end
		return math.min(altura, MUNDO.TechoY - 2)
	end
end

local function obtenerAlturaNatural()
	if not alturaNatural then
		alturaNatural = crearAltura(semillaActual)
	end
	return alturaNatural
end

local function aplicarPlazas(x, z, natural)
	for _, plaza in ipairs(plazas) do
		local d = distanciaXZ(x, z, plaza.pos.X, plaza.pos.Z)
		if d <= plaza.radio then
			return plaza.y
		end
		if d < plaza.radio + plaza.transicion then
			local t = mezclaSuave((d - plaza.radio) / plaza.transicion)
			return plaza.y + (natural - plaza.y) * t
		end
	end
	return natural
end

local function alturaConSendero(x, z, natural)
	-- El sendero se recorta después de las plazas: si la plaza mandara sobre el
	-- corredor, un tramo que llega más bajo que el inicio o la meta quedaría
	-- enterrado bajo el terreno plano y el camino desaparecería.
	local base = aplicarPlazas(x, z, natural)
	local dist, _, punto = rutaActual:CercanoXZ(x, z)
	local objetivo = punto.Y - 0.5
	local media = CAMINO.Ancho / 2 + 2

	local altura
	if dist <= media then
		altura = objetivo
	elseif dist < CAMINO.Corredor then
		local t = mezclaSuave((dist - media) / (CAMINO.Corredor - media))
		altura = objetivo + (base - objetivo) * t
	else
		altura = base
	end
	-- Devuelve altura y distancia al sendero: escribirTile necesita las dos.
	return altura, dist
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
	p.CanQuery = props.consulta == true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.transparencia then
		p.Transparency = props.transparencia
	end
	p.Parent = props.padre
	return p
end

-- Ruta guiada: paseo aleatorio por la cordillera, sin cruzar tramos previos.
local function rutaDeHistoria(semilla)
	local rng = Random.new(semilla + 17)
	local altura = obtenerAlturaNatural()
	local margen = HISTORIA.MargenMapa
	local minX = MUNDO.MinX + margen
	local maxX = MUNDO.MaxX - margen
	local minZ = MUNDO.MinZ + margen
	local maxZ = MUNDO.MaxZ - margen
	local separacion2 = HISTORIA.SeparacionMinima * HISTORIA.SeparacionMinima

	local inicioX, inicioZ = HISTORIA.InicioX, HISTORIA.InicioZ
	local puntos = { Vector3.new(inicioX, altura(inicioX, inicioZ), inicioZ) }
	local angulo = 0
	local restante = HISTORIA.LongitudObjetivo

	local function cercaDeAntiguos(x, z)
		local limite = #puntos - 2
		for i = 1, limite do
			local p = puntos[i]
			local dx, dz = x - p.X, z - p.Z
			if dx * dx + dz * dz < separacion2 then
				return true
			end
		end
		return false
	end

	while restante > HISTORIA.PasoMin and #puntos < 200 do
		local paso = math.min(rng:NextNumber(HISTORIA.PasoMin, HISTORIA.PasoMax), restante)
		local giroBase = math.rad(rng:NextNumber(-HISTORIA.GiroMax, HISTORIA.GiroMax))
		if rng:NextNumber() < HISTORIA.ProbabilidadRecodo then
			local recodo = math.rad(rng:NextNumber(HISTORIA.RecodoMin, HISTORIA.RecodoMax))
			giroBase += rng:NextNumber() < 0.5 and recodo or -recodo
		end

		local ultimo = puntos[#puntos]
		local candidato
		local anguloElegido
		for _ = 1, HISTORIA.IntentosWaypoint do
			local prueba = angulo + giroBase + math.rad(rng:NextNumber(-12, 12))
			local x = ultimo.X + math.cos(prueba) * paso
			local z = ultimo.Z + math.sin(prueba) * paso
			if x >= minX and x <= maxX and z >= minZ and z <= maxZ and not cercaDeAntiguos(x, z) then
				candidato = Vector3.new(x, altura(x, z), z)
				anguloElegido = prueba
				break
			end
		end
		if not candidato then
			break
		end
		table.insert(puntos, candidato)
		angulo = anguloElegido
		restante -= paso
	end

	return Ruta.crear(puntos, CAMINO.Paso, { PendienteMax = 0.22, Suavizado = 3 })
end

-- Ronda rápida: mismo terreno, ruta corta alrededor del primer pico.
local function rutaRapida(semilla)
	local rng = Random.new(semilla)
	local altura = crearAltura(semilla)
	local pico = MUNDO.Picos[1]
	local centroX, centroZ = pico.X, pico.Z

	local function dentroMapa(x, z)
		return x >= MUNDO.MinX + RAPIDA.MargenMapa and x <= MUNDO.MaxX - RAPIDA.MargenMapa
			and z >= MUNDO.MinZ + RAPIDA.MargenMapa and z <= MUNDO.MaxZ - RAPIDA.MargenMapa
	end

	local function lejosDeMadriguera(x, z)
		return distanciaXZ(x, z, CLAROS.Madriguera.X, CLAROS.Madriguera.Z) >= RAPIDA.SeparacionRuta
	end

	local function libreDePuntos(x, z, lista)
		local limite = #lista - 2
		for i = 1, limite do
			local p = lista[i]
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
			local anguloInicio = rng:NextNumber(0, math.pi * 2)
			local radio = rng:NextNumber(RAPIDA.RadioInicioMin, RAPIDA.RadioInicioMax)
			local x = centroX + math.cos(anguloInicio) * radio
			local z = centroZ + math.sin(anguloInicio) * radio
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
		local angulo = math.atan2(centroZ - inicio.Z, centroX - inicio.X) + math.rad(rng:NextNumber(-35, 35))
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
		local inicio = Vector3.new(centroX - 120, 0, centroZ)
		local angulo = math.atan2(centroZ - inicio.Z, centroX - inicio.X)
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
		waypoints[i] = Vector3.new(p.X, altura(p.X, p.Z), p.Z)
	end
	return Ruta.crear(waypoints, CAMINO.Paso, { PendienteMax = 0.22, Suavizado = 3 })
end

-- Teselas cuyo centro cae a menos de RadioVision de algún punto de la ruta.
local function construirTilesRelevantes(ruta)
	tiles = {}
	tilesOrden = {}
	local radio = MUNDO.RadioVision
	local radio2 = radio * radio

	for i = 1, #ruta.Puntos do
		local p = ruta.Puntos[i]
		local prog = ruta.Acumuladas[i]
		local minCX = math.floor((p.X - radio) / TILE)
		local maxCX = math.floor((p.X + radio) / TILE)
		local minCZ = math.floor((p.Z - radio) / TILE)
		local maxCZ = math.floor((p.Z + radio) / TILE)
		for cx = minCX, maxCX do
			for cz = minCZ, maxCZ do
				local dx = cx * TILE + TILE * 0.5 - p.X
				local dz = cz * TILE + TILE * 0.5 - p.Z
				if dx * dx + dz * dz <= radio2 then
					local clave = claveTile(cx, cz)
					local tile = tiles[clave]
					if tile then
						if prog < tile.minProg then
							tile.minProg = prog
						end
						if prog > tile.maxProg then
							tile.maxProg = prog
						end
					else
						tile = {
							cx = cx,
							cz = cz,
							minProg = prog,
							maxProg = prog,
							cargado = false,
						}
						tiles[clave] = tile
						table.insert(tilesOrden, tile)
					end
				end
			end
		end
	end

	table.sort(tilesOrden, function(a, b)
		return a.minProg < b.minProg
	end)
end

local function prepararRuta(ruta)
	rutaActual = ruta
	local inicio = ruta:PuntoEnDistancia(0)
	local fin = ruta:PuntoEnDistancia(ruta.Longitud)
	plazas = {
		{
			pos = Vector3.new(inicio.X, inicio.Y - 0.5, inicio.Z),
			y = inicio.Y - 0.5,
			radio = CLAROS.Inicio.Radio,
			transicion = CLAROS.Inicio.Transicion,
			bosque = CLAROS.Inicio.RadioBosque,
		},
		{
			pos = Vector3.new(fin.X, fin.Y - 0.5, fin.Z),
			y = fin.Y - 0.5,
			radio = CLAROS.Meta.Radio,
			transicion = CLAROS.Meta.Transicion,
			bosque = CLAROS.Meta.RadioBosque,
		},
		{
			pos = Vector3.new(CLAROS.Madriguera.X, inicio.Y - 0.5, CLAROS.Madriguera.Z),
			y = inicio.Y - 0.5,
			radio = CLAROS.Madriguera.Radio,
			transicion = CLAROS.Madriguera.Transicion,
			bosque = CLAROS.Madriguera.RadioBosque,
		},
	}
	construirTilesRelevantes(ruta)
end

local function escribirTile(cx, cz)
	local region = Region3.new(
		Vector3.new(cx * TILE, MUNDO.BaseY, cz * TILE),
		Vector3.new((cx + 1) * TILE, MUNDO.TechoY, (cz + 1) * TILE)
	):ExpandToGrid(CELDA)

	local nx = math.floor(region.Size.X / CELDA + 0.5)
	local ny = math.floor(region.Size.Y / CELDA + 0.5)
	local nz = math.floor(region.Size.Z / CELDA + 0.5)
	local minimo = region.CFrame.Position - region.Size * 0.5
	local altura = obtenerAlturaNatural()

	local materiales, ocupaciones = {}, {}
	for ix = 1, nx do
		materiales[ix] = {}
		ocupaciones[ix] = {}
		for iy = 1, ny do
			materiales[ix][iy] = table.create(nz, Enum.Material.Air)
			ocupaciones[ix][iy] = table.create(nz, 0)
		end
	end

	local alturas = table.create(nx)
	local distancias = table.create(nx)
	for ix = 1, nx do
		local x = minimo.X + (ix - 0.5) * CELDA
		alturas[ix] = table.create(nz)
		distancias[ix] = table.create(nz)
		for iz = 1, nz do
			local z = minimo.Z + (iz - 0.5) * CELDA
			local h, dist = alturaConSendero(x, z, altura(x, z))
			alturas[ix][iz] = h
			distancias[ix][iz] = dist
		end
	end

	for ix = 1, nx do
		for iz = 1, nz do
			local h = alturas[ix][iz]
			local hx = alturas[math.min(ix + 1, nx)][iz] - alturas[math.max(ix - 1, 1)][iz]
			local hz = alturas[ix][math.min(iz + 1, nz)] - alturas[ix][math.max(iz - 1, 1)]
			local pendiente = math.sqrt((hx / (2 * CELDA)) ^ 2 + (hz / (2 * CELDA)) ^ 2)

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

			local llenas = math.clamp(math.floor((h - minimo.Y) / CELDA), 0, ny)
			for iy = 1, llenas do
				materiales[ix][iy][iz] = material
				ocupaciones[ix][iy][iz] = 1
			end
			if llenas < ny then
				local fondo = minimo.Y + llenas * CELDA
				local fraccion = math.clamp((h - fondo) / CELDA, 0, 1)
				if fraccion > 0 then
					materiales[ix][llenas + 1][iz] = material
					ocupaciones[ix][llenas + 1][iz] = fraccion
				end
			end
		end
	end

	workspace.Terrain:WriteVoxels(region, CELDA, materiales, ocupaciones)
end

-- La cinta se reparte por teselas según el punto medio de cada tramo, así ninguna
-- pieza queda duplicada entre dos teselas vecinas.
local function construirCintaTile(tile, padre)
	local separacion = CAMINO.SeparacionCinta
	local ancho = CAMINO.Ancho
	local grosor = CAMINO.Grosor
	local d = 0
	while d < rutaActual.Longitud - 0.01 do
		local d2 = math.min(d + separacion, rutaActual.Longitud)
		local p1, t1 = rutaActual:PuntoEnDistancia(d)
		local p2 = rutaActual:PuntoEnDistancia(d2)
		local medio = (p1 + p2) * 0.5
		if math.floor(medio.X / TILE) == tile.cx and math.floor(medio.Z / TILE) == tile.cz then
			local dx, dy, dz = p2.X - p1.X, p2.Y - p1.Y, p2.Z - p1.Z
			local largo = math.sqrt(dx * dx + dy * dy + dz * dz)
			local direccion = largo > 1e-4 and Vector3.new(dx / largo, dy / largo, dz / largo) or t1
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
		end
		if d2 >= rutaActual.Longitud - 1e-4 then
			break
		end
		d = d2
	end
end

local function plantarArbol(x, z, base, altura, semilla, padre)
	local rng = Random.new(semilla)
	local conifera = rng:NextNumber() < BOSQUE.ProporcionConifera
	local alturaTronco = altura * (conifera and rng:NextNumber(0.55, 0.66) or rng:NextNumber(0.42, 0.5))
	local diametro = math.max(0.8, altura * rng:NextNumber(0.05, 0.07))

	local modelo = Instance.new("Model")
	modelo.Name = conifera and "Pino" or "Arbol"

	local tronco = nuevaParte({
		nombre = "Tronco",
		tamano = Vector3.new(alturaTronco, diametro, diametro),
		cf = CFrame.new(x, base + alturaTronco / 2 - 0.35, z) * CFrame.Angles(0, 0, math.pi / 2),
		color = BOSQUE.Colores.Tronco,
		material = Enum.Material.Wood,
		forma = Enum.PartType.Cylinder,
		colision = true,
		consulta = false,
		padre = modelo,
	})
	modelo.PrimaryPart = tronco

	local niveles
	local color
	if conifera then
		color = BOSQUE.Colores.Conifera
		niveles = {
			{ h = 0.46, r = 0.28 },
			{ h = 0.62, r = 0.22 },
			{ h = 0.77, r = 0.16 },
			{ h = 0.90, r = 0.09 },
		}
	else
		color = BOSQUE.Colores.Hoja
		niveles = {
			{ h = 0.60, r = 0.21 },
			{ h = 0.74, r = 0.18 },
			{ h = 0.86, r = 0.14 },
		}
	end

	for _, nivel in ipairs(niveles) do
		local radio = altura * nivel.r * rng:NextNumber(0.9, 1.1)
		local ox = rng:NextNumber(-0.05, 0.05) * altura
		local oz = rng:NextNumber(-0.05, 0.05) * altura
		local factor = rng:NextNumber(0.9, 1.08)
		nuevaParte({
			nombre = "Copa",
			tamano = Vector3.new(radio * 2, radio * 2 * rng:NextNumber(0.85, 1.1), radio * 2),
			cf = CFrame.new(x + ox, base + altura * nivel.h, z + oz),
			color = Color3.new(
				math.clamp(color.R * factor, 0, 1),
				math.clamp(color.G * factor, 0, 1),
				math.clamp(color.B * factor, 0, 1)
			),
			material = Enum.Material.Grass,
			forma = Enum.PartType.Ball,
			colision = false,
			consulta = false,
			padre = modelo,
		})
	end

	modelo.Parent = padre
	return modelo
end

local function construirBosqueTile(tile, carpetaBosque, carpetaRocas)
	local rng = Random.new(semillaActual + tile.cx * 7919 + tile.cz * 104729)
	local altura = obtenerAlturaNatural()
	local margen = BOSQUE.MargenTile
	local baseX = tile.cx * TILE
	local baseZ = tile.cz * TILE
	local separacion2 = BOSQUE.SeparacionMinima * BOSQUE.SeparacionMinima
	local arboles = {}

	local function suelo(x, z)
		return alturaConSendero(x, z, altura(x, z))
	end

	local function pendiente(x, z)
		local dx = suelo(x + 2, z) - suelo(x - 2, z)
		local dz = suelo(x, z + 2) - suelo(x, z - 2)
		return math.sqrt((dx / 4) ^ 2 + (dz / 4) ^ 2)
	end

	local function enPlaza(x, z)
		for _, plaza in ipairs(plazas) do
			if distanciaXZ(x, z, plaza.pos.X, plaza.pos.Z) < plaza.bosque then
				return true
			end
		end
		return false
	end

	local function libreDeArboles(x, z)
		for _, arbol in ipairs(arboles) do
			local dx = x - arbol.base.X
			local dz = z - arbol.base.Z
			if dx * dx + dz * dz < separacion2 then
				return false
			end
		end
		return true
	end

	local intentos = BOSQUE.ArbolesPorTile * BOSQUE.IntentosPorArbol
	for _ = 1, intentos do
		if #arboles >= BOSQUE.ArbolesPorTile then
			break
		end
		local x = rng:NextNumber(baseX + margen, baseX + TILE - margen)
		local z = rng:NextNumber(baseZ + margen, baseZ + TILE - margen)
		if not enPlaza(x, z) and libreDeArboles(x, z) then
			local dist = rutaActual:CercanoXZ(x, z)
			if dist >= BOSQUE.DistanciaMinimaCamino then
				local base = suelo(x, z)
				if base <= BOSQUE.AlturaMaximaArbol and pendiente(x, z) <= BOSQUE.PendienteMaxima then
					local alto = rng:NextNumber(BOSQUE.AlturaMinima, BOSQUE.AlturaMaxima)
					if rng:NextNumber() < 0.08 then
						alto *= 1.3 -- algún ejemplar viejo rompe la silueta uniforme
					end
					local modelo = plantarArbol(x, z, base, alto, rng:NextInteger(1, 2 ^ 30), carpetaBosque)
					arboles[#arboles + 1] = {
						modelo = modelo,
						base = Vector3.new(x, base, z),
						altura = alto,
					}
				end
			end
		end
	end

	local arbustos = 0
	for _ = 1, BOSQUE.ArbustosPorTile * 6 do
		if arbustos >= BOSQUE.ArbustosPorTile then
			break
		end
		local x = rng:NextNumber(baseX + margen, baseX + TILE - margen)
		local z = rng:NextNumber(baseZ + margen, baseZ + TILE - margen)
		if not enPlaza(x, z) and rutaActual:CercanoXZ(x, z) >= BOSQUE.DistanciaMinimaCamino then
			local base = suelo(x, z)
			for _ = 1, 2 do
				local alto = rng:NextNumber(BOSQUE.AlturaMinimaArbusto, BOSQUE.AlturaMaximaArbusto)
				nuevaParte({
					nombre = "Arbusto",
					tamano = Vector3.new(alto, alto * rng:NextNumber(0.8, 1.1), alto),
					cf = CFrame.new(x + rng:NextNumber(-0.9, 0.9), base + alto * 0.4, z + rng:NextNumber(-0.9, 0.9)),
					color = BOSQUE.Colores.Arbusto,
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

	local rocas = 0
	for _ = 1, BOSQUE.RocasPorTile * 8 do
		if rocas >= BOSQUE.RocasPorTile then
			break
		end
		local x = rng:NextNumber(baseX + ROCAS.MargenTile, baseX + TILE - ROCAS.MargenTile)
		local z = rng:NextNumber(baseZ + ROCAS.MargenTile, baseZ + TILE - ROCAS.MargenTile)
		if not enPlaza(x, z) and rutaActual:CercanoXZ(x, z) >= BOSQUE.DistanciaMinimaCamino then
			local tamano = rng:NextNumber(ROCAS.TamanoMin, ROCAS.TamanoMax)
			local alto = tamano * rng:NextNumber(0.7, 1)
			nuevaParte({
				nombre = "Roca",
				tamano = Vector3.new(tamano, alto, tamano * rng:NextNumber(0.8, 1.2)),
				cf = CFrame.new(x, suelo(x, z) + alto * 0.35, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				color = BOSQUE.Colores.Roca,
				material = Enum.Material.Slate,
				forma = rng:NextInteger(0, 1) == 0 and Enum.PartType.Ball or Enum.PartType.Block,
				colision = true,
				consulta = false,
				padre = carpetaRocas,
			})
			rocas += 1
		end
	end

	tile.arboles = arboles
end

local function generarTile(tile)
	if tile.cargado then
		return
	end
	tile.cargado = true

	local carpeta = Instance.new("Folder")
	carpeta.Name = "Tile_" .. tile.cx .. "_" .. tile.cz
	carpeta.Parent = raiz
	tile.carpeta = carpeta

	local camino = Instance.new("Folder")
	camino.Name = "Camino"
	camino.Parent = carpeta
	local bosque = Instance.new("Folder")
	bosque.Name = "Bosque"
	bosque.Parent = carpeta
	local rocas = Instance.new("Folder")
	rocas.Name = "Rocas"
	rocas.Parent = carpeta

	escribirTile(tile.cx, tile.cz)
	construirCintaTile(tile, camino)
	construirBosqueTile(tile, bosque, rocas)
end

local function hayJugadorEn(tile)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local raizChar = char and char:FindFirstChild("HumanoidRootPart")
		if raizChar then
			local p = raizChar.Position
			if p.X >= tile.cx * TILE - 12 and p.X <= (tile.cx + 1) * TILE + 12
				and p.Z >= tile.cz * TILE - 12 and p.Z <= (tile.cz + 1) * TILE + 12 then
				return true
			end
		end
	end
	return false
end

local function descargarTile(tile)
	if not tile.cargado or hayJugadorEn(tile) then
		return
	end
	local region = Region3.new(
		Vector3.new(tile.cx * TILE, MUNDO.BaseY, tile.cz * TILE),
		Vector3.new((tile.cx + 1) * TILE, MUNDO.TechoY, (tile.cz + 1) * TILE)
	):ExpandToGrid(CELDA)
	if tile.carpeta then
		tile.carpeta:Destroy()
	end
	tile.carpeta = nil
	tile.arboles = nil
	tile.cargado = false
	workspace.Terrain:FillRegion(region, CELDA, Enum.Material.Air)
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

local function construir(modo, semilla, ruta, tilesIniciales)
	local inicio = os.clock()
	semillaActual = semilla
	alturaNatural = crearAltura(semilla)

	prepararRuta(ruta)

	raiz = Instance.new("Folder")
	raiz.Name = NOMBRE_CARPETA
	raiz.Parent = workspace

	local cargados = 0
	for _, tile in ipairs(tilesOrden) do
		if tile.minProg > tilesIniciales then
			break
		end
		generarTile(tile)
		cargados += 1
	end

	aplicarAmbiente()
	print(("[Terreno] %s · semilla %d · ruta %d studs · %d teselas relevantes · %d tiles iniciales · %.2fs"):format(
		modo,
		semilla,
		math.floor(ruta.Longitud),
		#tilesOrden,
		cargados,
		os.clock() - inicio
	))
end

function TerrenoService.ConstruirHistoria(semilla)
	semilla = math.floor(tonumber(semilla) or MUNDO.Semilla)
	TerrenoService.Limpiar()
	-- La ruta necesita la altura antes de que `construir` fije la semilla.
	semillaActual = semilla
	alturaNatural = crearAltura(semillaActual)
	local ruta = rutaDeHistoria(semilla)
	construir("historia", semilla, ruta, MUNDO.TilesIniciales)
	return ruta
end

-- Seam de Studio (B4): valida una semilla de Historia sin construir el mundo entero.
-- Devuelve { semilla, longitud, inicio, meta, madriguera } o nil + error.
if RunService:IsStudio() then
	function TerrenoService._ProbarHistoria(semilla)
		semilla = math.floor(tonumber(semilla) or MUNDO.Semilla)
		local previaSemilla, previaAltura = semillaActual, alturaNatural
		semillaActual = semilla
		alturaNatural = crearAltura(semilla)
		local ok, ruta = pcall(rutaDeHistoria, semilla)
		semillaActual, alturaNatural = previaSemilla, previaAltura
		if not ok or not ruta then
			return nil, tostring(ruta)
		end
		local inicio = ruta:PuntoEnDistancia(0)
		local meta = ruta:PuntoEnDistancia(ruta.Longitud)
		return {
			semilla = semilla,
			longitud = math.floor(ruta.Longitud),
			inicio = inicio,
			meta = meta,
			madriguera = ruta:CercanoXZ(CLAROS.Madriguera.X, CLAROS.Madriguera.Z),
		}
	end
end

function TerrenoService.ConstruirRapida(semilla)
	local semillaFinal = math.floor(tonumber(semilla) or os.time())
	TerrenoService.Limpiar()
	local ruta = rutaRapida(semillaFinal)
	construir("rapida", semillaFinal, ruta, ruta.Longitud)
	return ruta
end

function TerrenoService.RutaActual()
	return rutaActual
end

-- Árboles de teselas cargadas cerca de `pos` (contrato de HazardService, fase 9).
-- Devuelve { { modelo = Model, base = Vector3, altura = number }, ... } ordenados.
function TerrenoService.ArbolesCerca(pos, radio)
	if typeof(pos) ~= "Vector3" or type(radio) ~= "number" or radio <= 0 then
		return {}
	end
	local encontrados = {}
	local radio2 = radio * radio
	for _, tile in ipairs(tilesOrden) do
		if tile.cargado and tile.arboles then
			local minX = tile.cx * TILE - radio
			local maxX = (tile.cx + 1) * TILE + radio
			local minZ = tile.cz * TILE - radio
			local maxZ = (tile.cz + 1) * TILE + radio
			if pos.X >= minX and pos.X <= maxX and pos.Z >= minZ and pos.Z <= maxZ then
				for _, arbol in ipairs(tile.arboles) do
					local dx, dz = arbol.base.X - pos.X, arbol.base.Z - pos.Z
					local d2 = dx * dx + dz * dz
					if d2 <= radio2 then
						table.insert(encontrados, { arbol = arbol, d2 = d2 })
					end
				end
			end
		end
	end
	table.sort(encontrados, function(a, b)
		return a.d2 < b.d2
	end)
	local salida = table.create(math.min(#encontrados, 40))
	for i = 1, math.min(#encontrados, 24) do
		salida[i] = encontrados[i].arbol
	end
	return salida
end

function TerrenoService.AlturaSuelo(pos)
	if typeof(pos) ~= "Vector3" then
		return 0
	end
	local excluir = {}
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

-- Carga por delante del líder y descarga por detrás del rezagado. Un tile por
-- tick: la generación voxel de una tesela ronda las decenas de milisegundos.
function TerrenoService.IniciarStreaming()
	if streamingIniciado then
		return
	end
	streamingIniciado = true

	task.spawn(function()
		while true do
			task.wait(MUNDO.TickStreaming)
			if rutaActual then
				local pMin, pMax = math.huge, -math.huge
				for _, player in ipairs(Players:GetPlayers()) do
					if player:GetAttribute("EnJuego") then
						local d = tonumber(player:GetAttribute("Distancia")) or 0
						if d > pMax then
							pMax = d
						end
						if d < pMin then
							pMin = d
						end
					end
				end
				if pMin > pMax then
					pMin, pMax = 0, 0 -- sin jugadores en partida se mantiene solo el inicio
				end

				local cargar, descargar
				for _, tile in ipairs(tilesOrden) do
					local relevante = tile.maxProg >= pMin - MUNDO.DescargarAtras
						and tile.minProg <= pMax + MUNDO.CargarAdelante
					if relevante then
						if not tile.cargado and not cargar then
							cargar = tile
						end
					elseif tile.cargado and not descargar then
						descargar = tile
					end
				end
				if cargar then
					generarTile(cargar)
				end
				if descargar then
					descargarTile(descargar)
				end
			end
		end
	end)
end

function TerrenoService.Limpiar()
	if raiz then
		raiz:Destroy()
		raiz = nil
	end
	workspace.Terrain:Clear()
	rutaActual = nil
	semillaActual = nil
	alturaNatural = nil
	tiles = {}
	tilesOrden = {}
	plazas = {}
end

return TerrenoService
