-- CustomizationService: escalas corporales R15 y color de camiseta por jugador (plan §6, spike S5).
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
local colores = {} -- [player] = Color3 de la camiseta (torso + brazos) ya validado

local DataService -- require aplazado a Iniciar: Main llama DataService.Iniciar() antes que este

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

-- Aplica el color de camiseta al personaje EN VIVO vía BodyColors (torso y
-- ambos brazos: las tres partes que cubre la camiseta). pcall porque el rig
-- puede estar a medio cargar o muerto; warn si falta BodyColors o falla.
local function aplicarColor(player, personaje, color)
	local body = personaje and personaje:FindFirstChildOfClass("BodyColors")
	if not body then
		warn("[Personalizacion] sin BodyColors en " .. player.Name .. ", no se aplica el color")
		return
	end
	local ok, err = pcall(function()
		body.TorsoColor3 = color
		body.LeftArmColor3 = color
		body.RightArmColor3 = color
	end)
	if not ok then
		warn("[Personalizacion] aplicar color falló en " .. player.Name .. ": " .. tostring(err))
		return
	end
	print("[Personalizacion] color de camiseta aplicado a " .. player.Name)
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

-- Restaura el color de camiseta persistido por DataService. Revalida con
-- clampCampo porque la fuente puede estar corrupta aunque el servidor
-- clampéara al guardar. Si el personaje ya existe, aplica en vivo.
local function cargarColor(player, datos)
	local c = type(datos) == "table" and datos.colorCamiseta
	if type(c) ~= "table" then
		return
	end
	local r = clampCampo(c[1], 0, 255)
	local g = clampCampo(c[2], 0, 255)
	local b = clampCampo(c[3], 0, 255)
	if not (r and g and b) then
		return
	end
	colores[player] = Color3.new(r / 255, g / 255, b / 255)
	local char = player.Character
	if char then
		aplicarColor(player, char, colores[player])
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
		local color = colores[player]
		if color then
			aplicarColor(player, char, color)
		end
	end)
end

function CustomizationService.Iniciar()
	-- Se requiere aquí: Main llama DataService.Iniciar() antes que este.
	-- Sin `local`: asigna el upvalue del nivel de módulo ( DataService, línea 18)
	-- que usan las funciones públicas; con `local` quedaría nil fuera de Iniciar.
	DataService = require(script.Parent.DataService)
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
		colores[player] = nil
	end)

	DataService.AlCargar.Event:Connect(cargarEscalas)
	DataService.AlCargar.Event:Connect(cargarColor)
	-- AlCargar pudo dispararse antes de conectar el listener (jugadores ya cargados).
	for _, player in ipairs(Players:GetPlayers()) do
		local datos = DataService.Obtener(player)
		cargarEscalas(player, datos)
		cargarColor(player, datos)
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

-- Color de camiseta elegido: lo llama TiendaService tras una compra de item
-- tipo "camiseta" (la compra y su validación quedan allá; aquí solo aplicar
-- y persistir). rgb es {r,g,b} en 0-255, igual que TiendaConfig.Catalogo.
function CustomizationService.ElegirColorCamiseta(player, rgb)
	if type(rgb) ~= "table" then
		return false
	end
	local r = clampCampo(rgb[1], 0, 255)
	local g = clampCampo(rgb[2], 0, 255)
	local b = clampCampo(rgb[3], 0, 255)
	if not (r and g and b) then
		return false
	end
	colores[player] = Color3.new(r / 255, g / 255, b / 255)
	DataService.Guardar(player, "colorCamiseta", { r, g, b }) -- persistencia (plan §3.3)
	local char = player.Character
	if char then
		aplicarColor(player, char, colores[player])
	end
	return true
end

return CustomizationService
