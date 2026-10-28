-- RopaService: ropa plan B (plan §6, decisión D7: sin EditableImage). Los diseños
-- prefabricados (patrón de dos colores + pegatina) se pintan con SurfaceGui +
-- Frames sobre el torso; el cliente solo manda ids y el servidor los revalida.
-- Patrón copiado de AccesoriosService: AlCargar + CharacterAdded + persistencia
-- vía DataService, con barrido de carrera por jugadores ya conectados.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RopaConfig = require(ReplicatedStorage.Shared.Config.RopaConfig)
local RopaArte = require(ReplicatedStorage.Shared.RopaArte)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local RopaService = {}
local disenos = {} -- [player] = { [ranura] = { patron, color1, color2, pegatina } } solo ids
local activa = {} -- [player] = ranura activa (o nil)

local DataService -- se requiere en Iniciar: Main llama DataService.Iniciar() antes

local remotoGuardar
local remotoPedir
local remotoEstado
local remotoResultado
local permitirGuardar
local permitirPedir

-- Ranura entera en 1..maximo (el cliente puede mandar string o basura).
local function ranuraValida(valor, maximo)
	local n = math.floor(tonumber(valor) or 0)
	if n < 1 or n > maximo then
		return nil
	end
	return n
end

-- Normaliza un diseño en bruto a SOLO los ids de RopaConfig (o nil si algo no
-- existe): el cliente no se confía y la fuente guardada puede estar corrupta.
local function normalizarDiseno(valor)
	if type(valor) ~= "table" then
		return nil
	end
	local patron = RopaConfig.PatronPorId(valor.patron)
	local color1 = RopaConfig.ColorPorId(valor.color1)
	local color2 = RopaConfig.ColorPorId(valor.color2)
	local pegatina = RopaConfig.PegatinaPorId(valor.pegatina)
	if not (patron and color1 and color2 and pegatina) then
		return nil
	end
	return { patron = patron.id, color1 = color1.id, color2 = color2.id, pegatina = pegatina.id }
end

-- Copia profunda para no compartir referencias con el estado interno.
local function copiarDisenos(player)
	local copia = {}
	for ranura, diseno in pairs(disenos[player] or {}) do
		copia[ranura] = {
			patron = diseno.patron,
			color1 = diseno.color1,
			color2 = diseno.color2,
			pegatina = diseno.pegatina,
		}
	end
	return copia
end

-- Diseño activo del jugador (o nil si no hay).
local function disenoActivo(player)
	local ranura = activa[player]
	return ranura and disenos[player] and disenos[player][ranura]
end

-- Aplica en vivo sobre el torso: primero limpia (idempotente) y, si hay diseño
-- activo, pinta dos SurfaceGui (Front y Back) con RopaArte. Si aún no hay
-- personaje, se aplicará en el próximo CharacterAdded.
local function aplicar(player, personaje)
	local torso = personaje and (personaje:FindFirstChild("UpperTorso") or personaje:FindFirstChild("Torso"))
	if not torso then
		return
	end
	for _, hijo in ipairs(torso:GetChildren()) do
		if hijo.Name == "RopaCamiseta" then
			hijo:Destroy()
		end
	end
	local diseno = disenoActivo(player)
	if not diseno then
		return
	end
	local ok, err = pcall(function()
		for _, cara in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local lienzo = Instance.new("SurfaceGui")
			lienzo.Name = "RopaCamiseta"
			lienzo.Face = cara
			lienzo.Adornee = torso
			lienzo.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			lienzo.PixelsPerStud = 64
			lienzo.LightInfluence = 0
			lienzo.ResetOnSpawn = false
			lienzo.Parent = torso
			RopaArte.Dibujar(lienzo, diseno)
		end
	end)
	if not ok then
		warn("[Ropa] no se pudo aplicar el diseño a " .. player.Name .. ": " .. tostring(err))
	end
end

-- GuardarRopa (client -> server): valida, guarda, persiste y aplica en vivo.
local function guardarRopa(player, payload)
	if not permitirGuardar(player) then
		return
	end
	local ranura = type(payload) == "table" and ranuraValida(payload.ranura, RopaConfig.RanurasGratis)
	local diseno = ranura and normalizarDiseno(payload)
	if not (ranura and diseno) then
		remotoResultado:FireClient(player, { ok = false, mensaje = "Diseño inválido" })
		return
	end
	if not disenos[player] then
		disenos[player] = {}
	end
	disenos[player][ranura] = diseno
	activa[player] = ranura
	DataService.Guardar(player, "ropa", { activa = ranura, disenos = disenos[player] }) -- persistencia (plan §3.3)
	aplicar(player, player.Character)
	remotoResultado:FireClient(player, { ok = true, mensaje = "Diseño guardado" })
	print("[Ropa] diseño guardado por " .. player.Name .. ": ranura " .. ranura)
end

-- PedirRopa (client -> server): estado completo con copia profunda.
local function pedirRopa(player)
	if not permitirPedir(player) then
		return
	end
	remotoEstado:FireClient(player, {
		activa = activa[player],
		ranurasDesbloqueadas = RopaConfig.RanurasGratis,
		disenos = copiarDisenos(player),
	})
end

-- Restaura lo persistido por DataService. Revalida cada diseño (ids y ranura
-- 1..RanurasMax) porque la fuente puede estar corrupta. Si el personaje ya
-- existe, aplica en vivo.
local function cargarRopa(player, datos)
	local ropa = type(datos) == "table" and datos.ropa
	if type(ropa) ~= "table" then
		return
	end
	local validos = {}
	local guardados = type(ropa.disenos) == "table" and ropa.disenos or {}
	for clave, bruto in pairs(guardados) do
		local ranura = ranuraValida(clave, RopaConfig.RanurasMax)
		local diseno = normalizarDiseno(bruto)
		if ranura and diseno then
			validos[ranura] = diseno
		end
	end
	local activaGuardada = ranuraValida(ropa.activa, RopaConfig.RanurasMax)
	disenos[player] = validos
	activa[player] = nil
	if activaGuardada and validos[activaGuardada] then
		activa[player] = activaGuardada
	end
	local char = player.Character
	if char then
		aplicar(player, char)
	end
end

local function conectarJugador(player)
	player.CharacterAdded:Connect(function(char)
		-- Espera a que el rig termine de cargarse tras el spawn.
		task.wait(0.5)
		aplicar(player, char)
	end)
end

function RopaService.Iniciar()
	-- Se requiere aquí: Main llama DataService.Iniciar() antes que este.
	-- Sin `local`: asigna el upvalue del nivel de módulo (DataService, línea 18).
	DataService = require(script.Parent.DataService)

	remotoGuardar = Remotes.Crear(Remotes.Nombres.GuardarRopa) -- el servidor crea, el cliente espera
	remotoPedir = Remotes.Crear(Remotes.Nombres.PedirRopa)
	remotoEstado = Remotes.Crear(Remotes.Nombres.RopaEstado)
	remotoResultado = Remotes.Crear(Remotes.Nombres.RopaResult)
	permitirGuardar = RateLimiter.nuevo(RopaConfig.Enfriamiento)
	permitirPedir = RateLimiter.nuevo(RopaConfig.Enfriamiento)

	remotoGuardar.OnServerEvent:Connect(guardarRopa)
	remotoPedir.OnServerEvent:Connect(pedirRopa)

	Players.PlayerAdded:Connect(conectarJugador)

	Players.PlayerRemoving:Connect(function(player)
		disenos[player] = nil
		activa[player] = nil
	end)

	DataService.AlCargar.Event:Connect(cargarRopa)
	-- AlCargar pudo dispararse antes de conectar el listener (jugadores ya cargados).
	for _, player in ipairs(Players:GetPlayers()) do
		conectarJugador(player)
		cargarRopa(player, DataService.Obtener(player))
	end

	print("[Ropa] activo")
end

return RopaService
