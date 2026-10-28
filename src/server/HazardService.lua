-- HazardService: peligros diegéticos de la fase 9 (plan §4.3).
-- Sin aviso sonoro ni marca en el suelo: el árbol que cae es el aviso y las
-- piedras salen de su copa. Servidor autoritativo: daño y derribo se resuelven aquí.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local TerrenoService = require(script.Parent.TerrenoService)

local HazardService = {}
local rng = Random.new()
local playerState
-- Caché defensiva: un build intermedio de TerrenoService puede no tener ArbolesCerca.
local buscarArboles = TerrenoService.ArbolesCerca
local MAX_PIEDRAS = 30
local piedrasVivas = 0

-- Raíz y Humanoid de un jugador que sigue jugando; nil si no cuenta.
-- "Terminado" lo pondrá la meta: los que ya llegaron no reciben más peligros.
local function participanteVivo(player)
	local char = player.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (raiz and hum and hum.Health > 0) then
		return nil
	end
	if player:GetAttribute("EnJuego") ~= true or player:GetAttribute("Terminado") == true then
		return nil
	end
	if playerState.EstaCaido(player) then
		return nil
	end
	return raiz, hum
end

local function arbolesCerca(pos, radio)
	if not buscarArboles then
		return {}
	end
	-- pcall: un TerrenoService a medias no debe matar el bucle de peligros.
	local ok, lista = pcall(buscarArboles, pos, radio)
	if ok and type(lista) == "table" then
		return lista
	end
	return {}
end

-- ArbolesCerca llega ordenado por cercanía; se conserva ese orden.
local function arbolesLibres(pos, radio)
	local libres = {}
	for _, arbol in arbolesCerca(pos, radio) do
		local modelo = arbol.modelo
		if modelo and modelo.Parent and arbol.base and arbol.altura
			and not modelo:GetAttribute("ArbolCayendo")
			and not modelo:GetAttribute("ArbolTumbado") then
			table.insert(libres, arbol)
		end
	end
	return libres
end

local function distanciaSegmentoXZ(p, a, b)
	local abx, abz = b.X - a.X, b.Z - a.Z
	local apx, apz = p.X - a.X, p.Z - a.Z
	local den = abx * abx + abz * abz
	local t = 0
	if den > 1e-6 then
		t = math.clamp((apx * abx + apz * abz) / den, 0, 1)
	end
	local dx = p.X - (a.X + abx * t)
	local dz = p.Z - (a.Z + abz * t)
	return math.sqrt(dx * dx + dz * dz)
end

local function golpearConArbol(base, direccion, altura, cfg)
	local final = base + direccion * (altura * 0.9)
	for _, player in Players:GetPlayers() do
		local raiz, hum = participanteVivo(player)
		if raiz
			and math.abs(raiz.Position.Y - base.Y) <= 8
			and distanciaSegmentoXZ(raiz.Position, base, final) <= cfg.RadioDanio then
			hum:TakeDamage(cfg.Danio)
			playerState.Derribar(player, "arbol")
		end
	end
end

-- Tween sobre un CFrameValue: PivotTo en cada cambio y cancelación limpia si
-- la tesela descarga el modelo a mitad de la animación.
local function animarPivote(modelo, destino, duracion, estilo, direccion, alCompletar)
	local valor = Instance.new("CFrameValue")
	valor.Value = modelo:GetPivot()
	local conexionValor = valor:GetPropertyChangedSignal("Value"):Connect(function()
		if modelo.Parent then
			modelo:PivotTo(valor.Value)
		end
	end)
	local conexionMuerte
	local tween
	local terminado = false

	local function cerrar(completado)
		if terminado then
			return
		end
		terminado = true
		if conexionMuerte then
			conexionMuerte:Disconnect()
		end
		conexionValor:Disconnect()
		valor:Destroy()
		if completado and modelo.Parent then
			modelo:PivotTo(destino)
			if alCompletar then
				alCompletar()
			end
		end
	end

	tween = TweenService:Create(
		valor,
		TweenInfo.new(duracion, estilo, direccion),
		{ Value = destino }
	)
	tween.Completed:Connect(function(estado)
		cerrar(estado == Enum.PlaybackState.Completed)
	end)
	conexionMuerte = modelo.Destroying:Connect(function()
		tween:Cancel()
		cerrar(false)
	end)
	tween:Play()
end

local function tumbarArbol(arbol, posObjetivo, cfg)
	local modelo = arbol.modelo
	if not modelo or not modelo.Parent then
		return
	end
	if modelo:GetAttribute("ArbolCayendo") or modelo:GetAttribute("ArbolTumbado") then
		return
	end

	local base = arbol.base
	local direccion = Vector3.new(posObjetivo.X - base.X, 0, posObjetivo.Z - base.Z)
	if direccion.Magnitude < 1e-3 then
		direccion = Vector3.new(1, 0, 0)
	else
		direccion = direccion.Unit
	end

	-- 90° alrededor de la base: el pivote del modelo suele estar en el centro,
	-- así que se lleva el eje al punto de apoyo antes de girar.
	local eje = Vector3.yAxis:Cross(direccion)
	eje = eje.Magnitude > 1e-3 and eje.Unit or Vector3.xAxis
	local original = modelo:GetPivot()
	local caida = CFrame.new(base) * CFrame.fromAxisAngle(eje, math.rad(90)) * CFrame.new(-base) * original

	modelo:SetAttribute("ArbolCayendo", true)
	animarPivote(modelo, caida, cfg.DuracionCaida, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
		modelo:SetAttribute("ArbolCayendo", false)
		modelo:SetAttribute("ArbolTumbado", true)
		golpearConArbol(base, direccion, arbol.altura, cfg)

		-- Mientras siga tumbado no se puede volver a elegir.
		task.delay(cfg.Reaparicion, function()
			if not modelo.Parent or not modelo:GetAttribute("ArbolTumbado") then
				return
			end
			animarPivote(modelo, original, cfg.DuracionCaida, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
				modelo:SetAttribute("ArbolTumbado", false)
			end)
		end)
	end)
end

local function destruirPiedra(piedra)
	if piedra.Parent then
		piedra:Destroy()
	end
end

local function crearPiedra(base, altura, cfg)
	if piedrasVivas >= MAX_PIEDRAS then
		return
	end

	local diametro = rng:NextNumber(0.9, 1.4)
	local piedra = Instance.new("Part")
	piedra.Name = "Piedra"
	piedra.Shape = Enum.PartType.Ball
	piedra.Size = Vector3.new(diametro, diametro, diametro)
	piedra.Material = Enum.Material.Slate
	piedra.Color = Color3.fromRGB(105, 105, 105)
	piedra.Anchored = false
	piedra.CanCollide = false
	piedra.Massless = true
	piedra.CFrame = CFrame.new(
		base
			+ Vector3.new(
				rng:NextNumber(-2, 2),
				altura * rng:NextNumber(0.6, 0.9),
				rng:NextNumber(-2, 2)
			)
	)

	piedrasVivas += 1
	piedra.Destroying:Connect(function()
		piedrasVivas = math.max(0, piedrasVivas - 1)
	end)

	piedra.Touched:Connect(function(otra)
		if not piedra.Parent or piedra:GetAttribute("Impactado") then
			return
		end
		local char = otra and otra.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		local raiz, hum = participanteVivo(player)
		if not raiz then
			return
		end
		-- Touched ya es contacto: RadioDanio solo descarta accesorios descolgados.
		local delta = raiz.Position - piedra.Position
		if Vector3.new(delta.X, 0, delta.Z).Magnitude > cfg.RadioDanio then
			return
		end
		piedra:SetAttribute("Impactado", true)
		hum:TakeDamage(cfg.Danio)
		playerState.Derribar(player, "piedra")
		destruirPiedra(piedra)
	end)

	piedra.Parent = workspace
	piedra.AssemblyLinearVelocity = Vector3.new(0, -18, 0)

	task.delay(4, function()
		destruirPiedra(piedra)
	end)
end

local function lloverPiedras(posObjetivo, cfg)
	if piedrasVivas >= MAX_PIEDRAS then
		return
	end
	local libres = arbolesLibres(posObjetivo, cfg.RadioBusqueda)
	if #libres == 0 then
		return
	end

	local arbol = libres[rng:NextInteger(1, #libres)]
	local cantidad = rng:NextInteger(cfg.CantidadMin, cfg.CantidadMax)
	local paso = cantidad > 1 and (cfg.RetardoMax - cfg.RetardoMin) / (cantidad - 1) or 0

	-- Retardos escalonados: 3-5 piedras caen en ráfaga, no todas de golpe.
	for i = 1, cantidad do
		task.delay(cfg.RetardoMin + paso * (i - 1), function()
			if piedrasVivas >= MAX_PIEDRAS or not arbol.modelo.Parent then
				return
			end
			crearPiedra(arbol.base, arbol.altura, cfg)
		end)
	end
end

local function elegirObjetivo(ruta)
	local objetivos = {}
	for _, player in Players:GetPlayers() do
		local raiz = participanteVivo(player)
		if raiz and ruta:Progreso(raiz.Position) >= Config.Etapa0.ProteccionInicio then
			table.insert(objetivos, raiz.Position)
		end
	end
	if #objetivos == 0 then
		return nil
	end
	return objetivos[rng:NextInteger(1, #objetivos)]
end

function HazardService.Iniciar()
	playerState = require(script.Parent.PlayerStateService)
	local cfg = Config.Etapa0.ArbolesQueCaen

	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(cfg.IntervaloMin, cfg.IntervaloMax))

			local ruta = TerrenoService.RutaActual()
			if ruta then
				local objetivo = elegirObjetivo(ruta)
				if objetivo then
					if rng:NextNumber() < cfg.Probabilidad then
						local arboles = arbolesLibres(objetivo, cfg.RadioBusqueda)
						if #arboles > 0 then
							tumbarArbol(arboles[1], objetivo, cfg)
						end
					else
						lloverPiedras(objetivo, Config.Etapa0.Piedras)
					end
				end
			end
		end
	end)

	print(string.format(
		"[Peligros] modo árboles que caen / lluvia de piedras (%.0f%% / %.0f%%), sin aviso sonoro",
		cfg.Probabilidad * 100,
		(1 - cfg.Probabilidad) * 100
	))
end

return HazardService
