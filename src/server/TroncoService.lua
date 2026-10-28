-- TroncoService: troncos rodantes que barren el sendero (plan §4.3). Patrón Aviso -> Impacto -> Secuela.
-- Aviso 2 s (franja perpendicular a la ruta) y el tronco cruza el ancho del sendero por el punto más cercano al jugador.
-- Servidor autoritativo: el tronco se mueve por código (Anchored) y el daño se resuelve aquí.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TerrenoConfig = require(ReplicatedStorage.Shared.Config.TerrenoConfig)
local TerrenoService = require(script.Parent.TerrenoService)

local TroncoService = {}
local rng = Random.new()
local playerState
local sonido = Remotes.Crear(Remotes.Nombres.Sonido) -- fase 6: aviso e impacto

local function franjaDeAviso(punto, tangente, ancho)
	local franja = Instance.new("Part")
	franja.Name = "AvisoTronco"
	franja.Size = Vector3.new(ancho + 8, 0.2, 2) -- eje largo cruzando el sendero
	local centro = punto + Vector3.new(0, 0.35, 0)
	franja.CFrame = CFrame.lookAt(centro, centro + tangente)
	franja.Color = Color3.fromRGB(180, 40, 30)
	franja.Material = Enum.Material.Neon
	franja.Transparency = 0.5
	franja.Anchored = true
	franja.CanCollide = false
	franja.Parent = workspace
	return franja
end

local function lanzarTronco(posObjetivo)
	local ruta = TerrenoService.RutaActual()
	if not ruta then
		return
	end
	local _, _, punto, tangente = ruta:CercanoXZ(posObjetivo.X, posObjetivo.Z)
	local plano = Vector3.new(tangente.X, 0, tangente.Z)
	tangente = plano.Magnitude > 1e-4 and plano.Unit or Vector3.new(1, 0, 0)
	local normal = tangente:Cross(Vector3.yAxis)
	normal = normal.Magnitude > 1e-4 and normal.Unit or Vector3.new(0, 0, 1)

	local cfg = Config.Etapa0.Troncos
	local ancho = TerrenoConfig.Camino.Ancho
	local lado = rng:NextInteger(0, 1) == 0 and 1 or -1
	local aviso = franjaDeAviso(punto, tangente, ancho)
	-- Una vez por tronco, al pintar la franja de aviso.
	sonido:FireAllClients({ id = "Aviso", subtitulo = AudioConfig.Efectos.Aviso.subtitulo })

	task.delay(cfg.AvisoSeg, function()
		if aviso.Parent then
			aviso:Destroy()
		end

		local tronco = Instance.new("Part")
		tronco.Name = "Tronco"
		tronco.Shape = Enum.PartType.Cylinder
		tronco.Size = Vector3.new(cfg.Largo, cfg.Diametro, cfg.Diametro)
		-- Eje local X sobre la tangente: el cilindro rueda cruzando el sendero
		local inicio = punto
			+ normal * lado * (ancho / 2 + 10)
			+ Vector3.new(0, cfg.Diametro / 2 + 1.2, 0)
		tronco.CFrame = CFrame.lookAt(inicio, inicio + tangente) * CFrame.Angles(0, math.pi / 2, 0)
		tronco.Color = Color3.fromRGB(117, 82, 45)
		tronco.Material = Enum.Material.Wood
		tronco.Anchored = true
		tronco.CanCollide = false
		tronco.Parent = workspace

		local golpeados = {}
		local radioGolpe = cfg.Diametro / 2 + 2.5
		local paso = -normal * lado * cfg.Velocidad * 0.03

		-- Movimiento por código con paso fijo; cubre el ancho más margen y se destruye
		task.spawn(function()
			local recorrido = 0
			while tronco.Parent and recorrido < ancho + 20 do
				tronco.CFrame += paso
				for _, player in Players:GetPlayers() do
					local char = player.Character
					local raiz = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if raiz and hum and hum.Health > 0 and not golpeados[player]
						and not playerState.EstaCaido(player) and player:GetAttribute("EnJuego") then
						local delta = raiz.Position - tronco.Position
						local a = math.abs(delta:Dot(tangente))
						local perpendicular = (delta - tangente * delta:Dot(tangente)).Magnitude
						if a <= cfg.Largo / 2 and perpendicular < radioGolpe then
							golpeados[player] = true
							-- Solo al jugador golpeado: golpeados[] impide repetirlo en el barrido.
							sonido:FireClient(player, { id = "Impacto", subtitulo = AudioConfig.Efectos.Impacto.subtitulo })
							hum:TakeDamage(cfg.Danio)
							playerState.Derribar(player, "tronco")
						end
					end
				end
				task.wait(0.03)
				recorrido += paso.Magnitude
			end
			if tronco.Parent then
				tronco:Destroy()
			end
		end)
	end)
end

function TroncoService.Iniciar()
	playerState = require(script.Parent.PlayerStateService)
	local cfg = Config.Etapa0.Troncos

	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(cfg.IntervaloMin, cfg.IntervaloMax))
			local objetivos = {}
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local raiz = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if raiz and hum and hum.Health > 0 and not playerState.EstaCaido(player)
					and player:GetAttribute("EnJuego") then
					table.insert(objetivos, raiz.Position)
				end
			end
			if #objetivos > 0 then
				local objetivo = objetivos[rng:NextInteger(1, #objetivos)]
				local ruta = TerrenoService.RutaActual()
				if ruta and ruta:Progreso(objetivo) >= Config.Etapa0.ProteccionInicio then
					lanzarTronco(objetivo)
				end
			end
		end
	end)

	print("[Tronco] troncos rodantes activos")
end

return TroncoService
