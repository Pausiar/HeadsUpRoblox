-- CustomizationService: escalas corporales R15 por jugador (plan §6, spike S5).
-- Servidor autoritativo: la API de HumanoidDescription NO satura valores
-- (spike S5: set 10 -> lee 10), así que cada campo del cliente se valida y
-- clampéa SIEMPRE aquí contra los rangos de Config antes de aplicarse.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local Personalizacion = Config.Etapa0.Personalizacion

local CustomizationService = {}
local escalas = {} -- [player] = { altura, ancho, cabeza } ya validadas

local remotoPersonalizacion
local permitir

-- tonumber + clamp al rango de Config (el cliente no se confía; la API no clampa).
local function clampCampo(valor, min, max)
	local n = tonumber(valor)
	if not n then
		return nil
	end
	if n < min then
		return min
	end
	if n > max then
		return max
	end
	return n
end

-- Aplica las escalas al personaje EN VIVO vía HumanoidDescription.
-- GetAppliedDescription devuelve la descripción actual del avatar (ropa,
-- accesorios, colores), así que al tocar solo las tres escalas se conserva
-- la apariencia; pcall porque ApplyDescription puede fallar (rig no R15,
-- humanoid muerto, personaje a medio cargar).
local function aplicar(player, personaje, esc)
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if not hum then
		warn("[Personalizacion] sin Humanoid en " .. player.Name .. ", no se aplican escalas")
		return
	end
	local ok, err = pcall(function()
		local desc = hum:GetAppliedDescription()
		desc.HeightScale = esc.altura
		desc.WidthScale = esc.ancho
		desc.HeadScale = esc.cabeza
		hum:ApplyDescription(desc)
	end)
	if not ok then
		warn("[Personalizacion] ApplyDescription falló en " .. player.Name .. ": " .. tostring(err))
		return
	end
	print("[Personalizacion] aplicado a " .. player.Name
		.. ": altura=" .. esc.altura .. " ancho=" .. esc.ancho .. " cabeza=" .. esc.cabeza)
end

-- Restaura escalas persistidas por DataService (plan §3.3). Revalida con
-- clampCampo porque la fuente puede estar corrupta aunque el servidor
-- clampéara al guardar. Si el personaje ya existe, aplica en vivo.
local function cargarEscalas(player, datos)
	local esc = type(datos) == "table" and datos.escalas
	if type(esc) ~= "table" then
		return
	end
	local altura = clampCampo(esc.altura, Personalizacion.AlturaMin, Personalizacion.AlturaMax)
	local ancho = clampCampo(esc.ancho, Personalizacion.AnchoMin, Personalizacion.AnchoMax)
	local cabeza = clampCampo(esc.cabeza, Personalizacion.CabezaMin, Personalizacion.CabezaMax)
	if not (altura and ancho and cabeza) then
		return
	end
	escalas[player] = { altura = altura, ancho = ancho, cabeza = cabeza }
	local char = player.Character
	if char then
		aplicar(player, char, escalas[player])
	end
end

local function conectarJugador(player)
	player.CharacterAdded:Connect(function(char)
		-- Espera a que el Humanoid y el rig terminen de cargarse tras el spawn.
		task.wait(0.5)
		local esc = escalas[player]
		if esc then
			aplicar(player, char, esc)
		end
	end)
end

function CustomizationService.Iniciar()
	-- Se requiere aquí: Main llama DataService.Iniciar() antes que este.
	local DataService = require(script.Parent.DataService)
	remotoPersonalizacion = Remotes.Crear(Remotes.Nombres.Personalizacion) -- el servidor crea, el cliente espera
	permitir = RateLimiter.nuevo(Personalizacion.Enfriamiento)

	remotoPersonalizacion.OnServerEvent:Connect(function(player, datos)
		if not permitir(player) then
			return
		end
		if type(datos) ~= "table" then
			return
		end
		local altura = clampCampo(datos.altura, Personalizacion.AlturaMin, Personalizacion.AlturaMax)
		local ancho = clampCampo(datos.ancho, Personalizacion.AnchoMin, Personalizacion.AnchoMax)
		local cabeza = clampCampo(datos.cabeza, Personalizacion.CabezaMin, Personalizacion.CabezaMax)
		if not (altura and ancho and cabeza) then
			return
		end
		escalas[player] = { altura = altura, ancho = ancho, cabeza = cabeza }
		DataService.Guardar(player, "escalas", escalas[player]) -- persistencia (plan §3.3)
		local char = player.Character
		if char then
			aplicar(player, char, escalas[player])
		end
		-- Si aún no hay personaje, se aplicará en el próximo CharacterAdded.
	end)

	Players.PlayerAdded:Connect(conectarJugador)

	Players.PlayerRemoving:Connect(function(player)
		escalas[player] = nil
	end)

	DataService.AlCargar.Event:Connect(cargarEscalas)
	-- AlCargar pudo dispararse antes de conectar el listener (jugadores ya cargados).
	for _, player in ipairs(Players:GetPlayers()) do
		cargarEscalas(player, DataService.Obtener(player))
	end
end

-- Escalas guardadas del jugador (o nil si nunca personalizó). Copia para
-- que nadie externo mute el estado interno.
function CustomizationService.GetEscalas(player)
	local esc = escalas[player]
	if not esc then
		return nil
	end
	return { altura = esc.altura, ancho = esc.ancho, cabeza = esc.cabeza }
end

return CustomizationService
