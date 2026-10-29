-- Animación de uso de objetos: al beber, una lata 3D aparece en la mano derecha y
-- sube hasta la boca. Sin assets subidos: se bloquea el brazo con Weld mientras dura
-- (pose validada en QA sobre el rig R15 con AnimationConstraint) y se suelta al final.
-- Con reducirEfectos (plan §8) no se reproduce.
-- shortcut: la animación es solo local; los demás jugadores no ven la lata. Si la
-- co-op lo pide, subir una animación real o replicar la pose desde el servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)

local player = Players.LocalPlayer
local remoteBebida = Remotes.Esperar(Remotes.Nombres.BebidaResult)

-- Pose medida en QA: hombro (50°, 60°, -70°) y codo 135° dejan la mano a 1,26 studs
-- de la boca; con la lata a 0,57 studs, el borde queda en los labios.
local POSICION_HOMBRO = CFrame.Angles(math.rad(50), math.rad(60), math.rad(-70))
local POSICION_CODO = CFrame.Angles(math.rad(135), 0, 0)
local SUBIDA = 0.45
local AGUANTE = 0.85
local BAJADA = 0.35
local GIRO_LATA = CFrame.Angles(0, 0, math.rad(90)) -- eje X del cilindro -> eje Y de la lata
local COLOR_CUERPO = Color3.fromRGB(76, 140, 74)
local COLOR_TAPA = Color3.fromRGB(205, 205, 210)
local COLOR_BANDA = Color3.fromRGB(255, 201, 60)

local estado = nil -- { objetos = { parts y welds }, hombro, codo }
local token = 0

local function soltar()
	local actual = estado
	estado = nil
	if not actual then
		return
	end
	for _, objeto in ipairs(actual.objetos) do
		objeto:Destroy()
	end
	-- Re-encender después de soltar: el Animator recupera la pose de inmediato.
	actual.hombro.Enabled = true
	actual.codo.Enabled = true
end

local function detener()
	token += 1
	soltar()
end

local function crearPieza(nombre, tamano, color, material)
	local pieza = Instance.new("Part")
	pieza.Name = nombre
	pieza.Size = tamano
	pieza.Color = color
	pieza.Material = material
	pieza.Shape = Enum.PartType.Cylinder
	pieza.Anchored = false
	pieza.CanCollide = false
	pieza.CanTouch = false
	pieza.CanQuery = false
	pieza.Massless = true
	return pieza
end

local function soldar(char, parte0, parte1)
	local weld = Instance.new("Weld")
	weld.Part0 = parte0
	weld.Part1 = parte1
	weld.C0 = parte0.CFrame:Inverse() * parte1.CFrame
	weld.C1 = CFrame.identity
	weld.Parent = char
	return weld
end

local function animar()
	if Settings.Obtener("reducirEfectos") == true then
		return
	end
	if estado then
		return -- ya hay una bebida en curso: la segunda no encadena poses
	end
	if player:GetAttribute("EnJuego") ~= true then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	local torso = char:FindFirstChild("UpperTorso")
	local brazo = char:FindFirstChild("RightUpperArm")
	local antebrazo = char:FindFirstChild("RightLowerArm")
	local mano = char:FindFirstChild("RightHand")
	local cabeza = char:FindFirstChild("Head")
	-- shortcut: rig R6 o R15 con Motor6D: sin AnimationConstraint no hay pose fiable;
	-- la animación se omite en esos rigs (los avatares con Avatar Joint Upgrade sí la
	-- tienen). Migrar a un asset de animación subido si aparecen en producción.
	if not (torso and brazo and antebrazo and mano and cabeza) then
		return
	end
	local hombro = brazo:FindFirstChild("RightShoulder")
	local codo = antebrazo:FindFirstChild("RightElbow")
	local a0 = torso:FindFirstChild("RightShoulderRigAttachment")
	local e = brazo:FindFirstChild("RightElbowRigAttachment")
	local w = antebrazo:FindFirstChild("RightWristRigAttachment")
	if not (hombro and hombro:IsA("AnimationConstraint")
		and codo and codo:IsA("AnimationConstraint")
		and a0 and e and w) then
		return
	end

	-- Pose actual del brazo (congelada al desactivar las juntas) y destino.
	local armRel = a0.CFrame:Inverse() * (torso.CFrame:Inverse() * brazo.CFrame)
	local foreRel = (brazo.CFrame * e.CFrame):Inverse() * antebrazo.CFrame
	local handRel = (antebrazo.CFrame * w.CFrame):Inverse() * mano.CFrame
	local armNew = torso.CFrame * a0.CFrame * POSICION_HOMBRO * armRel
	local foreNew = armNew * e.CFrame * POSICION_CODO * foreRel
	local handNew = foreNew * w.CFrame * handRel

	-- Lata orientada de la mano a la boca; el borde superior toca los labios.
	local boca = cabeza.CFrame * CFrame.new(0, -0.15, -0.62)
	local hacia = boca.Position - handNew.Position
	if hacia.Magnitude < 0.2 then
		return
	end
	local arriba = hacia.Unit
	local ejeX = arriba:Cross(Vector3.zAxis)
	if ejeX.Magnitude < 0.1 then
		ejeX = arriba:Cross(Vector3.xAxis)
	end
	ejeX = ejeX.Unit
	local lata = CFrame.fromMatrix(
		boca.Position - arriba * 0.57, ejeX, arriba, ejeX:Cross(arriba)
	)
	local offset = handNew:Inverse() * lata

	local cuerpo = crearPieza("Cuerpo", Vector3.new(1.15, 0.56, 0.56), COLOR_CUERPO, Enum.Material.SmoothPlastic)
	local tapa = crearPieza("Tapa", Vector3.new(0.09, 0.5, 0.5), COLOR_TAPA, Enum.Material.Metal)
	local banda = crearPieza("Banda", Vector3.new(0.38, 0.6, 0.6), COLOR_BANDA, Enum.Material.SmoothPlastic)
	-- En la mano, lista para subir: mismo offset que tendrá en la boca.
	local inicial = mano.CFrame * offset
	cuerpo.CFrame = inicial * GIRO_LATA
	tapa.CFrame = inicial * CFrame.new(0, 0.58, 0) * GIRO_LATA
	banda.CFrame = inicial * GIRO_LATA
	for _, pieza in ipairs({ cuerpo, tapa, banda }) do
		pieza.Parent = char
	end
	local weldTapa = soldar(char, cuerpo, tapa)
	local weldBanda = soldar(char, cuerpo, banda)
	local weldMano = soldar(char, mano, cuerpo)

	local restoHombro = torso.CFrame:Inverse() * brazo.CFrame
	local restoCodo = brazo.CFrame:Inverse() * antebrazo.CFrame
	local weldHombro = soldar(char, torso, brazo)
	local weldCodo = soldar(char, brazo, antebrazo)
	estado = {
		objetos = { cuerpo, tapa, banda, weldTapa, weldBanda, weldMano, weldHombro, weldCodo },
		hombro = hombro,
		codo = codo,
	}
	hombro.Enabled = false
	codo.Enabled = false

	local miToken = token
	local info = TweenInfo.new(SUBIDA, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(weldHombro, info, { C0 = torso.CFrame:Inverse() * armNew }):Play()
	TweenService:Create(weldCodo, info, { C0 = armNew:Inverse() * foreNew }):Play()
	task.wait(SUBIDA)
	if miToken ~= token then
		return
	end
	task.wait(AGUANTE)
	if miToken ~= token then
		return
	end

	local infoBajada = TweenInfo.new(BAJADA, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	TweenService:Create(weldHombro, infoBajada, { C0 = restoHombro }):Play()
	TweenService:Create(weldCodo, infoBajada, { C0 = restoCodo }):Play()
	task.wait(BAJADA)
	if miToken ~= token then
		return
	end
	detener()
end

remoteBebida.OnClientEvent:Connect(function(datos)
	if type(datos) ~= "table" or datos.ok ~= true then
		return
	end
	local ok, err = pcall(animar)
	if not ok then
		warn("[AnimacionBeber] fallo: " .. tostring(err))
		detener()
	end
end)

player.CharacterRemoving:Connect(detener)
player:GetAttributeChangedSignal("EnJuego"):Connect(function()
	if player:GetAttribute("EnJuego") ~= true then
		detener()
	end
end)

print("[AnimacionBeber] activa")
