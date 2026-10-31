-- ClimaVisual (fase 11 · L6, B12): pinta el clima que anuncia el servidor.
-- Tween de Lighting (+ Atmosphere: con Atmosphere presente la niebla clásica
-- FogEnd/FogStart no se renderiza, doc oficial) y partículas de nieve solo en
-- Ventisca y solo si Settings.reducirEfectos = false. Sin daño: solo presentación.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.ClimaConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Movimiento = require(ReplicatedStorage.Shared.Movimiento)

-- Originales guardados UNA vez, antes del primer tween, para restaurar la
-- noche exacta que dejó TerrenoService. Idempotente: dos eventos seguidos no
-- apilan tweens (cada tween nuevo cancela el anterior por instancia).
local originales = nil
local origAtmosfera = nil
local tweens = {} -- [instancia] = Tween en curso
local climaActivo = nil -- tipo en curso o nil

local nieve = nil -- { parte = Part, emisor = ParticleEmitter }

local function tweenear(objetivo, props, segundos)
	local anterior = tweens[objetivo]
	if anterior then
		anterior:Cancel()
	end
	-- D42: con «reducir movimiento» la niebla cambia casi sin animación.
	if Movimiento.Reducido() then
		segundos = 0.1
	end
	local info = TweenInfo.new(segundos, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(objetivo, info, props)
	tweens[objetivo] = tween
	tween:Play()
end

local function crearNieve()
	local parte = Instance.new("Part")
	parte.Name = "ClimaNieve"
	parte.Size = Vector3.new(28, 1, 28)
	parte.Transparency = 1
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.CastShadow = false

	local emisor = Instance.new("ParticleEmitter")
	emisor.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emisor.Rate = 70
	emisor.Lifetime = NumberRange.new(2, 3)
	emisor.Speed = NumberRange.new(2, 5)
	emisor.SpreadAngle = Vector2.new(25, 25)
	emisor.EmissionDirection = Enum.NormalId.Bottom
	emisor.Size = NumberSequence.new(0.18)
	emisor.Color = ColorSequence.new(Color3.fromRGB(240, 244, 255))
	emisor.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	emisor.LightInfluence = 1 -- nieve mate: responde a la noche
	emisor.Enabled = false
	emisor.Parent = parte

	parte.Parent = workspace
	nieve = { parte = parte, emisor = emisor }
end

local function ponerNieve(activa, viento)
	if activa then
		if not nieve then
			crearNieve()
		end
		nieve.emisor.Acceleration = Vector3.new(-(viento or 0), -18, 0)
		nieve.emisor.Enabled = true
	elseif nieve then
		nieve.emisor.Enabled = false -- deja morir las partículas vivas
	end
end

-- La parte emisora viaja sobre la cámara: nieve siempre cerca del jugador.
RunService.Heartbeat:Connect(function()
	if nieve and nieve.emisor.Enabled then
		local camara = workspace.CurrentCamera
		if camara then
			nieve.parte.CFrame = CFrame.new(camara.CFrame.Position + Vector3.new(0, 12, 0))
		end
	end
end)

local function aplicar(tipo)
	local datos = Config.Tipos[tipo]
	if not datos then
		return
	end
	if not originales then
		originales = {
			FogEnd = Lighting.FogEnd,
			FogStart = Lighting.FogStart,
			Brightness = Lighting.Brightness,
		}
	end
	local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmos and not origAtmosfera then
		origAtmosfera = { Density = atmos.Density, Haze = atmos.Haze }
	end
	climaActivo = tipo
	tweenear(Lighting, {
		FogEnd = datos.FogEnd,
		FogStart = datos.FogStart,
		Brightness = datos.Brightness,
	}, Config.Transicion)
	if atmos and origAtmosfera then
		tweenear(atmos, { Density = datos.Densidad, Haze = datos.Bruma }, Config.Transicion)
	end
	ponerNieve(tipo == "Ventisca" and Settings.Obtener("reducirEfectos") == false, datos.WindSpeed)
end

local function despejar(segundos)
	if not originales then
		return -- nunca hubo clima: no hay nada que restaurar
	end
	climaActivo = nil
	tweenear(Lighting, originales, segundos)
	if origAtmosfera then
		local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmos then
			tweenear(atmos, origAtmosfera, segundos)
		end
	end
	ponerNieve(false)
end

task.spawn(function()
	local ok, remote = pcall(Remotes.Esperar, Remotes.Nombres.Clima)
	if not ok or not remote then
		warn("[Clima] remote Clima ausente: sin efectos de clima")
		return
	end
	remote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.tipo) ~= "string" then
			return
		end
		if payload.tipo == Config.Despejado then
			despejar(math.max(0.5, tonumber(payload.duracion) or Config.Restaurar))
		elseif Config.Tipos[payload.tipo] then
			aplicar(payload.tipo)
		end
	end)
end)

-- En vivo: activar/quitar la nieve si cambia el ajuste con un evento en curso.
Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave == "reducirEfectos" and climaActivo then
		local datos = Config.Tipos[climaActivo]
		ponerNieve(not valor and climaActivo == "Ventisca", datos and datos.WindSpeed)
	end
end)

print("[ClimaVisual] activo")
