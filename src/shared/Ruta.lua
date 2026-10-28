-- Ruta: remuestreo Catmull-Rom en XZ con Y suavizada y pendiente limitada.
-- Contrato compartido por StageService, RondaRapidaService y los peligros.
local Ruta = {}

local EPS = 1e-6

local function catmull(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return (p1 * 2
		+ (p2 - p0) * t
		+ (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2
		+ (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

local function suavizarY(puntos, radio)
	if radio <= 0 or #puntos <= 2 then
		return
	end
	local yOriginal = table.create(#puntos)
	for i = 1, #puntos do
		yOriginal[i] = puntos[i].Y
	end
	for i = 2, #puntos - 1 do
		local suma, peso = 0, 0
		for k = -radio, radio do
			local j = math.clamp(i + k, 1, #puntos)
			local w = radio + 1 - math.abs(k)
			suma += yOriginal[j] * w
			peso += w
		end
		local p = puntos[i]
		puntos[i] = Vector3.new(p.X, suma / peso, p.Z)
	end
end

-- Los extremos no se mueven: la pendiente se reparte entre los puntos interiores.
local function limitarPendiente(puntos, pendienteMax)
	local n = #puntos
	if n <= 2 then
		return
	end
	local ds = table.create(n - 1)
	local total = 0
	for i = 1, n - 1 do
		local a, b = puntos[i], puntos[i + 1]
		ds[i] = math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2)
		total += ds[i]
	end
	local ys = table.create(n)
	for i = 1, n do
		ys[i] = puntos[i].Y
	end

	-- Si los extremos ya superan la pendiente máxima, ningún perfil interior puede cumplirla.
	if math.abs(ys[n] - ys[1]) > pendienteMax * total + EPS then
		return
	end

	local function relajar(desde, hasta, paso)
		local cambio = false
		for i = desde, hasta, paso do
			local maxDelta = pendienteMax * math.max(ds[i], 1e-4)
			local dy = ys[i + 1] - ys[i]
			local exceso = math.abs(dy) - maxDelta
			if exceso > EPS then
				local signo = dy > 0 and 1 or -1
				local flexibles = 0
				if i > 1 then
					flexibles += 1
				end
				if i + 1 < n then
					flexibles += 1
				end
				if flexibles > 0 then
					-- Sobrerrelajación: acelera la difusión de los ajustes a lo largo de la ruta.
					local ajuste = exceso / flexibles * 1.75
					if i > 1 then
						ys[i] += signo * ajuste
					end
					if i + 1 < n then
						ys[i + 1] -= signo * ajuste
					end
					cambio = true
				end
			end
		end
		return cambio
	end

	for _ = 1, 1024 do
		local ida = relajar(1, n - 1, 1)
		local vuelta = relajar(n - 1, 1, -1)
		if not ida and not vuelta then
			break
		end
	end

	for i = 1, n do
		local p = puntos[i]
		puntos[i] = Vector3.new(p.X, ys[i], p.Z)
	end
end

local function calcularTangentes(puntos)
	local crudas = table.create(#puntos)
	for i = 1, #puntos do
		local a = puntos[math.max(1, i - 1)]
		local b = puntos[math.min(#puntos, i + 1)]
		local vx, vz = b.X - a.X, b.Z - a.Z
		local mag = math.sqrt(vx * vx + vz * vz)
		crudas[i] = mag > EPS and Vector3.new(vx / mag, 0, vz / mag) or Vector3.new(1, 0, 0)
	end
	local tangentes = table.create(#puntos)
	for i = 1, #puntos do
		local sx, sz = 0, 0
		for k = -2, 2 do
			local j = math.clamp(i + k, 1, #puntos)
			local w = 3 - math.abs(k)
			sx += crudas[j].X * w
			sz += crudas[j].Z * w
		end
		local mag = math.sqrt(sx * sx + sz * sz)
		tangentes[i] = mag > EPS and Vector3.new(sx / mag, 0, sz / mag) or crudas[i]
	end
	return tangentes
end

local function proyectarSegmento(a, b, x, z)
	local abx, abz = b.X - a.X, b.Z - a.Z
	local den = abx * abx + abz * abz
	local t = den > EPS and ((x - a.X) * abx + (z - a.Z) * abz) / den or 0
	t = math.clamp(t, 0, 1)
	local px = a.X + abx * t
	local pz = a.Z + abz * t
	local dx, dz = x - px, z - pz
	return t, dx * dx + dz * dz, px, pz
end

local function tangenteEntre(ta, tb, t)
	local vx = ta.X + (tb.X - ta.X) * t
	local vz = ta.Z + (tb.Z - ta.Z) * t
	local mag = math.sqrt(vx * vx + vz * vz)
	return mag > EPS and Vector3.new(vx / mag, 0, vz / mag) or ta
end

local function obtenerRuta(waypoints, paso, opciones)
	local lista = table.create(#waypoints)
	for i = 1, #waypoints do
		local w = waypoints[i]
		assert(typeof(w) == "Vector3", "Ruta.crear: los waypoints deben ser Vector3")
		lista[i] = Vector3.new(w.X, w.Y, w.Z)
	end
	local n = #lista

	local densos = {}
	local acumDenso = {}
	local acumWay = table.create(n)
	acumWay[1] = 0
	local acumulado = 0
	local ultimoX, ultimoZ

	local function agregarDenso(x, z)
		if ultimoX then
			local dx, dz = x - ultimoX, z - ultimoZ
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= EPS then
				return
			end
			acumulado += d
			table.insert(densos, Vector3.new(x, 0, z))
			table.insert(acumDenso, acumulado)
		else
			table.insert(densos, Vector3.new(x, 0, z))
			table.insert(acumDenso, 0)
		end
		ultimoX, ultimoZ = x, z
	end

	for i = 1, n - 1 do
		local p0 = lista[math.max(1, i - 1)]
		local p1 = lista[i]
		local p2 = lista[i + 1]
		local p3 = lista[math.min(n, i + 2)]
		local largoXZ = math.sqrt((p2.X - p1.X) ^ 2 + (p2.Z - p1.Z) ^ 2)
		local subdiv = math.clamp(math.ceil(largoXZ / (paso * 0.5)), 4, 240)
		local primero = i == 1 and 0 or 1
		for j = primero, subdiv do
			local p = catmull(p0, p1, p2, p3, j / subdiv)
			agregarDenso(p.X, p.Z)
		end
		acumWay[i + 1] = acumulado
	end

	local ys = table.create(#densos)
	local indiceWay = 1
	for k = 1, #densos do
		local d = acumDenso[k]
		while indiceWay < n - 1 and d > acumWay[indiceWay + 1] + EPS do
			indiceWay += 1
		end
		local d0, d1 = acumWay[indiceWay], acumWay[indiceWay + 1]
		local t = d1 > d0 + EPS and (d - d0) / (d1 - d0) or 0
		ys[k] = lista[indiceWay].Y + (lista[indiceWay + 1].Y - lista[indiceWay].Y) * t
	end

	local puntos = { Vector3.new(lista[1].X, lista[1].Y, lista[1].Z) }
	local totalXZ = acumulado
	if totalXZ > EPS then
		local objetivos = {}
		local d = paso
		while d < totalXZ - EPS do
			if totalXZ - d < paso * 0.5 then
				break
			end
			table.insert(objetivos, d)
			d += paso
		end
		table.insert(objetivos, totalXZ)

		local k = 1
		local function muestra(d)
			while k < #densos - 1 and acumDenso[k + 1] < d - EPS do
				k += 1
			end
			local a, b = densos[k], densos[k + 1]
			local da, db = acumDenso[k], acumDenso[k + 1]
			local t = db > da + EPS and math.clamp((d - da) / (db - da), 0, 1) or 0
			return Vector3.new(
				a.X + (b.X - a.X) * t,
				ys[k] + (ys[k + 1] - ys[k]) * t,
				a.Z + (b.Z - a.Z) * t
			)
		end
		for _, d in ipairs(objetivos) do
			table.insert(puntos, muestra(d))
		end
		local ultimo = lista[n]
		puntos[#puntos] = Vector3.new(ultimo.X, ultimo.Y, ultimo.Z)
	else
		local ultimo = lista[n]
		table.insert(puntos, Vector3.new(ultimo.X, ultimo.Y, ultimo.Z))
	end

	local radioSuavizado = 3
	local suavizado = opciones and tonumber(opciones.Suavizado)
	if suavizado then
		radioSuavizado = math.clamp(math.floor(suavizado + 0.5), 0, 16)
	end
	suavizarY(puntos, radioSuavizado)

	local pendienteMax = 0.22
	if opciones and opciones.PendienteMax ~= nil then
		pendienteMax = math.max(0.01, tonumber(opciones.PendienteMax) or 0.22)
	end
	limitarPendiente(puntos, pendienteMax)

	local tangentes = calcularTangentes(puntos)
	local acumuladas = table.create(#puntos)
	acumuladas[1] = 0
	local longitud = 0
	for i = 2, #puntos do
		longitud += (puntos[i] - puntos[i - 1]).Magnitude
		acumuladas[i] = longitud
	end

	local ruta = {
		Puntos = puntos,
		Tangentes = tangentes,
		Acumuladas = acumuladas,
		Longitud = longitud,
	}
	return ruta
end

function Ruta.crear(waypoints, paso, opciones)
	assert(type(waypoints) == "table" and #waypoints >= 2, "Ruta.crear necesita al menos 2 waypoints")
	local pasoFinal = math.max(0.5, tonumber(paso) or 4)
	local ruta = obtenerRuta(waypoints, pasoFinal, opciones)

	function ruta:PuntoEnDistancia(d)
		local n = #self.Puntos
		if n == 0 then
			return Vector3.zero, Vector3.new(1, 0, 0)
		end
		if n == 1 or self.Longitud <= EPS then
			return self.Puntos[1], self.Tangentes[1]
		end
		local distancia = math.clamp(tonumber(d) or 0, 0, self.Longitud)
		local lo, hi = 1, n - 1
		while lo < hi do
			local mid = math.floor((lo + hi) / 2)
			if self.Acumuladas[mid + 1] < distancia then
				lo = mid + 1
			else
				hi = mid
			end
		end
		local i = lo
		local a0, a1 = self.Acumuladas[i], self.Acumuladas[i + 1]
		local t = a1 > a0 + EPS and math.clamp((distancia - a0) / (a1 - a0), 0, 1) or 0
		local a, b = self.Puntos[i], self.Puntos[i + 1]
		local punto = Vector3.new(
			a.X + (b.X - a.X) * t,
			a.Y + (b.Y - a.Y) * t,
			a.Z + (b.Z - a.Z) * t
		)
		return punto, tangenteEntre(self.Tangentes[i], self.Tangentes[i + 1], t)
	end

	local function buscarCercano(self, x, z, pista)
		local n = #self.Puntos
		if n < 2 then
			return 0, 1, self.Puntos[1], self.Tangentes[1]
		end
		local segmentos = n - 1
		local inicio = math.clamp(math.floor(tonumber(pista) or 1), 1, segmentos)
		local mejorI, mejorT, mejorD2 = 1, 0, math.huge
		for k = 0, segmentos - 1 do
			local i = ((inicio - 1 + k) % segmentos) + 1
			local t, d2 = proyectarSegmento(self.Puntos[i], self.Puntos[i + 1], x, z)
			if d2 < mejorD2 then
				mejorI, mejorT, mejorD2 = i, t, d2
			end
		end
		local a, b = self.Puntos[mejorI], self.Puntos[mejorI + 1]
		local punto = Vector3.new(
			a.X + (b.X - a.X) * mejorT,
			a.Y + (b.Y - a.Y) * mejorT,
			a.Z + (b.Z - a.Z) * mejorT
		)
		local tangente = tangenteEntre(self.Tangentes[mejorI], self.Tangentes[mejorI + 1], mejorT)
		return mejorD2, mejorI, punto, tangente
	end

	function ruta:Progreso(pos, pista)
		local _, indice, punto, tangente = buscarCercano(self, pos.X, pos.Z, pista)
		local i = math.min(indice, #self.Puntos - 1)
		local a, b = self.Puntos[i], self.Puntos[i + 1]
		local t = 0
		local abx, abz = b.X - a.X, b.Z - a.Z
		local den = abx * abx + abz * abz
		if den > EPS then
			t = math.clamp(((pos.X - a.X) * abx + (pos.Z - a.Z) * abz) / den, 0, 1)
		end
		local progreso = self.Acumuladas[i] + (self.Acumuladas[i + 1] - self.Acumuladas[i]) * t
		return progreso, indice, punto, tangente
	end

	function ruta:CercanoXZ(x, z, pista)
		local d2, indice, punto, tangente = buscarCercano(self, x, z, pista)
		return math.sqrt(d2), indice, punto, tangente
	end

	return ruta
end

return Ruta
