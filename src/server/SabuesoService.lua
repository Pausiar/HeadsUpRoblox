-- SabuesoService: El Sabueso de la Niebla (fase 11 · L6b, plan §5.4).
-- Hermano menor y más simple de MonsterService: máquina de estados con
-- generaciones (mismo patrón), huye de la linterna por el remote COMPARTIDO
-- LinternaAim y NUNCA mata (§5.4): el embiste causa estado con
-- PlayerStateService.Derribar(objetivo, "sabueso") y la víctima queda caída
-- con su cuenta atrás normal.
--
-- Ciclo: 1 Aullido (Sonido+subtítulo a los EnJuego, a 30+ studs del grupo)
-- -> 2 Acecho (circunda al grupo a 25–35 studs con MoveTo)
-- -> 3 Embestida (carga contra el EnJuego más cercano a 26; contacto a ≤3
--    studs -> Derribar y huye 50 studs)
-- -> 4 Retirada (Enfriamiento 75 s) -> 1 ...
-- Exclusión mutua con El Doble: el Sabueso solo persigue jugadores; los clones
-- del Doble no son objetivos ni obstáculos y ningún servicio toca al otro.
-- Se activa con SabuesoService.Iniciar() desde Main.server.lua (junto a
-- MonsterService.Iniciar(), después de PlayerStateService.Iniciar()).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local SabuesoConfig = require(ReplicatedStorage.Shared.Config.SabuesoConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local TerrenoService = require(script.Parent.TerrenoService)

local SabuesoService = {}
local rng = Random.new()
local sonido = Remotes.Crear(Remotes.Nombres.Sonido) -- mismo remote que usa El Doble (fase 6)

local cfg = SabuesoConfig
local TICK = 0.3
local ALTURA_CUERPO = 1.7 -- altura del centro del cuerpo sobre el suelo (patas 1.0 + media altura 0.6 + margen 0.1)

local playerState -- PlayerStateService (se requiere en Iniciar, patrón de MonsterService)

-- Estado por partida: UN sabueso con su bucle de fases.
local sabueso = nil -- { modelo, fase, huidaPendiente }
local iniciado = false
local generacion = 0 -- token de partida: al cambiar, gestor y bucle viejos mueren

--------------------------------------------------------------- Consultas ----

-- Elegibles: EnJuego, vivos y no caídos (§4.4: los caídos están fuera de
-- combate). Mismas condiciones que enJuego() de MonsterService.
local function enJuego()
	local lista = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		if raiz and hum and hum.Health > 0 and not playerState.EstaCaido(player)
			and player:GetAttribute("EnJuego") then
			table.insert(lista, { player = player, pos = raiz.Position })
		end
	end
	return lista
end

local function estaElegible(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	return raiz ~= nil and hum ~= nil and hum.Health > 0
		and not playerState.EstaCaido(player) and player:GetAttribute("EnJuego") == true
end

local function raizDe(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function centroGrupo()
	local grupo = enJuego()
	if #grupo == 0 then
		return nil
	end
	local suma = Vector3.zero
	for _, o in grupo do
		suma += o.pos
	end
	return suma / #grupo
end

local function vivo()
	local m = sabueso and sabueso.modelo
	if not m or not m.Parent then
		return false
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function humanoDe()
	local m = sabueso and sabueso.modelo
	return m and m:FindFirstChildOfClass("Humanoid")
end

---------------------------------------------------------------- Modelo ------

-- Sabueso con primitivas soldadas: cuerpo negro (raíz del Humanoid), cabeza,
-- 4 patas, cola y DOS OJOS ÁMBAR de Neon (se ven de noche). Todo lo que no es
-- el cuerpo va sin masa y soldado: la física es solo la raíz.
local function pieza(nombre, tam, cframe, color, material, padre)
	local parte = Instance.new("Part")
	parte.Name = nombre
	parte.Size = tam
	parte.CFrame = cframe
	parte.Color = color
	parte.Material = material
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Massless = true
	parte.Parent = padre
	return parte
end

local function construirModelo()
	local modelo = Instance.new("Model")
	modelo.Name = "Sabueso"

	local cuerpo = Instance.new("Part")
	cuerpo.Name = "HumanoidRootPart"
	cuerpo.Size = Vector3.new(1.5, 1.2, 3) -- ancho, alto, largo (el hocico mira a -Z)
	cuerpo.Color = cfg.ColorPelo
	cuerpo.CFrame = CFrame.new(0, ALTURA_CUERPO, 0)
	cuerpo.Parent = modelo

	pieza("Cabeza", Vector3.new(1, 1, 1.2), CFrame.new(0, 2.55, -1.85), cfg.ColorPelo, Enum.Material.Plastic, modelo)
	pieza("Cola", Vector3.new(0.25, 0.25, 0.9),
		CFrame.new(0, 2.2, 1.85) * CFrame.Angles(math.rad(40), 0, 0), cfg.ColorPelo, Enum.Material.Plastic, modelo)
	for _, ladoX in { -0.55, 0.55 } do
		for _, ladoZ in { -0.95, 0.95 } do
			pieza("Pata", Vector3.new(0.35, 1.0, 0.35), CFrame.new(ladoX, 0.5, ladoZ), cfg.ColorPelo, Enum.Material.Plastic, modelo)
		end
	end
	-- Ojos ámbar (patrón OjoDoble de MonsterService): esferas Neon apoyadas
	-- en la cara, sin colisión ni consulta ni tacto.
	for _, ladoX in { -0.22, 0.22 } do
		pieza("OjoSabueso", Vector3.new(0.18, 0.18, 0.18),
			CFrame.new(0, 2.55, -1.85) * CFrame.new(ladoX, 0.15, -0.62), cfg.ColorOjos, Enum.Material.Neon, modelo)
	end

	-- Soldaduras al cuerpo: el conjunto físico es solo el cuerpo.
	for _, parte in modelo:GetChildren() do
		if parte:IsA("BasePart") and parte ~= cuerpo then
			local soldadura = Instance.new("WeldConstraint")
			soldadura.Part0 = cuerpo
			soldadura.Part1 = parte
			soldadura.Parent = parte
		end
	end

	local hum = Instance.new("Humanoid")
	hum.HipHeight = ALTURA_CUERPO - cuerpo.Size.Y / 2 -- del borde inferior del cuerpo al suelo: las patas rozan
	hum.WalkSpeed = cfg.VelocidadAcechando
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- sin barra de vida que lo delate
	hum.Parent = modelo
	modelo.PrimaryPart = cuerpo
	return modelo
end

--------------------------------------------------------------- Apoyo --------

-- Huye en línea recta `distancia` studs desde `desdePos` (posición del que
-- apunta o de la víctima embestida).
local function huida(distancia, desdePos)
	if not vivo() then
		return
	end
	local pivot = sabueso.modelo:GetPivot()
	local dir = pivot.Position - desdePos
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 0.05 and dir.Unit or pivot.LookVector
	local destino = pivot.Position + dir * distancia
	local base = TerrenoService.AlturaSuelo(Vector3.new(destino.X, 0, destino.Z))
	local hum = humanoDe()
	if hum then
		hum.WalkSpeed = cfg.VelocidadHuyendo
		hum:MoveTo(Vector3.new(destino.X, base + 1, destino.Z))
	end
	print("[Sabueso] huye " .. distancia .. " studs")
end

-- Espera cancelable (patrón MonsterService, sin aturdimientos): devuelve
-- (completo, cancelado). Aborta si el modelo muere, nadie está EnJuego o la
-- linterna marcó una huida pendiente.
local function esperar(gen, segundos, cadaTick)
	local t = 0
	while t < segundos do
		local dt = task.wait(TICK)
		if gen ~= generacion then
			return false, true
		end
		if not vivo() or #enJuego() == 0 or sabueso.huidaPendiente then
			return false, false
		end
		t += dt
		if cadaTick then
			cadaTick()
		end
	end
	return true, false
end

-- Si la linterna marcó huida, la fase en curso se cancela y toca retirar:
-- el receptor ya ejecutó la huida física al marcar huidaPendiente.
local function faseTrasEspera(completo, siguiente)
	sabueso.fase = (completo and not sabueso.huidaPendiente) and siguiente or 4
end

----------------------------------------------------------------- Fases ------

-- Fase 1: aparece (o se recoloca) a 30+ studs del grupo, mirándolo, y aúlla
-- a todos los EnJuego con subtítulo. El aullido delata que YA está cerca.
local function faseAullido(gen)
	while #enJuego() == 0 do
		task.wait(1)
		if gen ~= generacion then
			return
		end
	end
	if not sabueso.modelo then
		local modelo = construirModelo()
		sabueso.modelo = modelo
		modelo.Parent = workspace
		pcall(function()
			modelo.HumanoidRootPart:SetNetworkOwner(nil) -- servidor autoritativo: MoveTo sin tirones de red
		end)
	end
	local centro = centroGrupo()
	local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	offset = offset.Magnitude > 0.05 and offset.Unit or Vector3.new(1, 0, 0)
	local destino = centro + offset * (cfg.DistanciaAullido + rng:NextNumber(0, 5))
	local base = TerrenoService.AlturaSuelo(Vector3.new(destino.X, 0, destino.Z))
	local posicion = Vector3.new(destino.X, base + ALTURA_CUERPO, destino.Z)
	sabueso.modelo:PivotTo(CFrame.lookAt(posicion, Vector3.new(centro.X, posicion.Y, centro.Z)))
	local hum = humanoDe()
	if hum then
		hum.WalkSpeed = cfg.VelocidadAcechando
	end
	print("[Sabueso] fase 1: aullido a " .. math.floor((posicion - centro).Magnitude) .. " studs del grupo")
	local payload = { id = "Aullido", subtitulo = AudioConfig.Efectos.Aullido.subtitulo }
	for _, o in enJuego() do
		sonido:FireClient(o.player, payload)
	end
	local completo, cancelado = esperar(gen, cfg.DuracionAullido)
	if cancelado then
		return
	end
	faseTrasEspera(completo, 2)
end

-- Fase 2: circunda al grupo a un radio de 25–35 studs (una vuelta por acecho).
local function faseAcecho(gen)
	print("[Sabueso] fase 2: acechando al grupo")
	local radio = rng:NextNumber(cfg.RadioAcechoMin, cfg.RadioAcechoMax)
	local angulo = rng:NextNumber(0, math.pi * 2)
	local velocidadAngular = (math.pi * 2) / cfg.DuracionAcecho
	local hum = humanoDe()
	if hum then
		hum.WalkSpeed = cfg.VelocidadAcechando
	end
	local completo, cancelado = esperar(gen, cfg.DuracionAcecho, function()
		local centro = centroGrupo()
		local humActual = humanoDe()
		if not centro or not humActual then
			return
		end
		angulo += velocidadAngular * TICK
		local x = centro.X + math.cos(angulo) * radio
		local z = centro.Z + math.sin(angulo) * radio
		local base = TerrenoService.AlturaSuelo(Vector3.new(x, 0, z))
		humActual:MoveTo(Vector3.new(x, base + 1, z))
	end)
	if cancelado then
		return
	end
	faseTrasEspera(completo, 3)
end

-- Fase 3: carga contra el EnJuego más cercano (detección por distancia en el
-- bucle, sin Touched, patrón MonsterService). Contacto a ≤3 studs -> Derribar
-- (§5.4: estado, no muerte) y huida de 50 studs. Golpee o falle, se retira.
local function faseEmbestida(gen)
	local objetivo = nil
	local pivot = sabueso.modelo:GetPivot().Position
	local mejorD = math.huge
	for _, o in enJuego() do
		local d = (o.pos - pivot).Magnitude
		if d < mejorD then
			objetivo, mejorD = o.player, d
		end
	end
	if not objetivo then
		sabueso.fase = 4
		return
	end
	print("[Sabueso] fase 3: embistiendo a " .. objetivo.Name)
	local hum = humanoDe()
	if hum then
		hum.WalkSpeed = cfg.VelocidadEmbistiendo
	end
	local t = 0
	while t < cfg.DuracionEmbestida do
		local dt = task.wait(TICK)
		if gen ~= generacion then
			return
		end
		if not vivo() or #enJuego() == 0 or sabueso.huidaPendiente then
			break
		end
		local raiz = raizDe(objetivo)
		if not raiz or not estaElegible(objetivo) then
			break -- dejó de ser objetivo (salió, cayó por otra causa, no EnJuego)
		end
		local humActual = humanoDe()
		if not humActual then
			return
		end
		humActual:MoveTo(raiz.Position)
		if (raiz.Position - sabueso.modelo:GetPivot().Position).Magnitude <= cfg.DistanciaGolpe then
			if estaElegible(objetivo) then
				playerState.Derribar(objetivo, "sabueso")
			end
			break
		end
		t += dt
	end
	if gen ~= generacion then
		return
	end
	if sabueso.huidaPendiente or not vivo() or #enJuego() == 0 then
		sabueso.fase = 4 -- la linterna ya lo hizo huir (o no hay a quién temer)
		return
	end
	local raiz = raizDe(objetivo)
	huida(cfg.HuidaGolpe, raiz and raiz.Position or (centroGrupo() or sabueso.modelo:GetPivot().Position))
	sabueso.fase = 4
end

-- Fase 4: enfriamiento lejos del grupo. El modelo queda donde huyó (no se
-- destruye: en el bosque nocturno sigue habiendo algo ahí fuera); el aullido
-- del ciclo siguiente lo recoloca.
local function faseRetirada(gen)
	print("[Sabueso] fase 4: retirada (" .. cfg.Enfriamiento .. " s)")
	local hum = humanoDe()
	if hum then
		hum.WalkSpeed = 0
	end
	local t = 0
	while t < cfg.Enfriamiento do
		task.wait(1)
		if gen ~= generacion then
			return
		end
		-- Si un haz lo marcó durante la retirada, ya huyó físicamente: la
		-- retirada ES la huida consumada, así que la marca se consume aquí.
		sabueso.huidaPendiente = nil
		t += 1
	end
	sabueso.fase = 1
end

-- Bucle de fases (uno por partida): muere en silencio al cambiar la
-- generación (reiniciar() ya limpió el modelo).
local function bucleSabueso(gen)
	sabueso = { modelo = nil, fase = 1, huidaPendiente = nil }
	while gen == generacion and sabueso.fase >= 1 and sabueso.fase <= 4 do
		if sabueso.fase == 1 then
			faseAullido(gen)
		elseif sabueso.fase == 2 then
			faseAcecho(gen)
		elseif sabueso.fase == 3 then
			faseEmbestida(gen)
		else
			faseRetirada(gen)
		end
	end
end

--------------------------------------------------------------- Gestor -------

-- Una partida = un gestor (patrón del gestor del Doble): RetardoAparicion
-- cuenta solo con jugadores EnJuego y después lanza el único bucle.
local function gestor(gen)
	local acumulado = 0
	while acumulado < cfg.RetardoAparicion do
		task.wait(1)
		if gen ~= generacion then
			return
		end
		if #enJuego() > 0 then
			acumulado += 1
		end
	end
	if gen ~= generacion then
		return
	end
	print("[Sabueso] aparece tras " .. cfg.RetardoAparicion .. " s de partida")
	bucleSabueso(gen)
end

local function reiniciar()
	if sabueso and sabueso.modelo then
		sabueso.modelo:Destroy()
	end
	sabueso = nil
end

--------------------------------------------------------------------- API ----

function SabuesoService.Iniciar()
	if iniciado then
		return
	end
	iniciado = true

	playerState = require(script.Parent.PlayerStateService)

	-- Una partida = un gestor. Al empezar otra o terminar la actual, el token
	-- de generación invalida gestor y bucle, y el modelo se destruye.
	local matchService = require(script.Parent.MatchService)
	matchService.AlEmpezar.Event:Connect(function()
		generacion += 1
		reiniciar()
		local gen = generacion
		task.spawn(function()
			gestor(gen)
		end)
	end)
	matchService.AlTerminarPartida.Event:Connect(function()
		generacion += 1
		reiniciar()
	end)

	-- LinternaAim es un remote COMPARTIDO con MonsterService: conectar varios
	-- OnServerEvent al mismo RemoteEvent es válido y todos reciben todos los
	-- eventos. Validamos el payload y el empujador igual que El Doble (5 Hz,
	-- RateLimiter): si el haz apunta al Sabueso (a ≤AlcanceLinterna studs y
	-- dentro de un cono de AnguloLinterna grados), HUYE del jugador y marca
	-- huidaPendiente; el bucle de fases cancela la fase en curso (embestida
	-- incluida) y pasa a retirada. El Sabueso nunca muere ni se aturde: solo huye.
	local permitirHaz = RateLimiter.nuevo(0.2)
	local cosCono = math.cos(math.rad(cfg.AnguloLinterna))
	Remotes.Crear(Remotes.Nombres.LinternaAim).OnServerEvent:Connect(function(player, datos)
		local ok, err = pcall(function()
			if not permitirHaz(player) then
				return
			end
			if typeof(datos) ~= "table" or typeof(datos.direccion) ~= "Vector3"
				or datos.direccion.Magnitude < 1e-6 then
				return
			end
			if player:GetAttribute("EnJuego") ~= true or playerState.EstaCaido(player) then
				return
			end
			local char = player.Character
			local cabeza = char and char:FindFirstChild("Head")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (cabeza and hum and hum.Health > 0) then
				return
			end
			if not vivo() or sabueso.huidaPendiente then
				return
			end
			local direccion = datos.direccion.Unit
			local hacia = sabueso.modelo:GetPivot().Position - cabeza.Position
			if hacia.Magnitude > 1e-6 and hacia.Magnitude <= cfg.AlcanceLinterna
				and hacia.Unit:Dot(direccion) >= cosCono then
				sabueso.huidaPendiente = player
				huida(cfg.HuidaLinterna, cabeza.Position) -- reacción física inmediata
				print("[Sabueso] ahuyentado por la linterna de " .. player.Name)
			end
		end)
		if not ok then
			warn("[Sabueso] receptor linterna: " .. tostring(err))
		end
	end)

	print("[Sabueso] servicio iniciado (aparece tras " .. cfg.RetardoAparicion .. " s de partida)")
end

return SabuesoService
