-- BengalaService (fase 11 · B13, plan L6): item de tienda con stock. El servidor
-- es autoritativo: valida el estado del jugador, descuenta DataService ("bengalas",
-- patrón "bebidas" de TiendaService), planta la bengala en el mundo (Part + luz +
-- chispas, autodestrucción con Debris) y aturde a los clones de El Doble dentro
-- del radio. El aturdimiento va por pcall a MonsterService.Aturdir: la API llega
-- con la refactor B14 (lista de clones); mientras falte se avisa y la bengala es
-- solo luz. La COMPRA no se resuelve aquí: TiendaService vende y debe llamar
-- AnadirStock — GANCHO_COORDINADOR al pie de este archivo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local BengalaConfig = require(ReplicatedStorage.Shared.Config.BengalaConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local NOMBRE_CLON = "ElDoble" -- mismo nombre que MonsterService (B14 puede mantener 2)

local BengalaService = {}

local remotoResultado
local permitirUso -- RateLimiter.nuevo(2) por jugador
local dataService -- se requieren en Iniciar: Main llama DataService antes (patrón TiendaService)
local playerState
local monster -- MonsterService (pcall: B14 en curso); Aturdir puede no existir aún
local cargados = {} -- [player] = true tras DataService.AlCargar (mismo motivo que TiendaService)

-- Lectura saneada del stock (patrón estadoConsumo de TiendaService): un dato
-- manipulado no puede superar el tope de config.
local function stockDe(player)
	local datos = dataService.Obtener(player)
	return math.clamp(math.floor(tonumber(datos.bengalas) or 0), 0, BengalaConfig.StockMax)
end

-- Atributo que leerá TiendaUI (como "Bebidas") y QA; sobrevive a respawns.
local function publicar(player, stock)
	player:SetAttribute("Bengalas", stock)
end

-- Lectura pura para terceros (UI, QA): sin inicializar nada.
function BengalaService.StockDe(player)
	return tonumber(player:GetAttribute("Bengalas")) or 0
end

-- Suma 1 al stock (tope StockMax), persiste y publica. Lo llamará TiendaService
-- al vender una bengala (GANCHO_COORDINADOR); hoy queda a la espera.
-- Devuelve el stock resultante, o nil si los datos aún no cargaron.
function BengalaService.AnadirStock(player)
	if not cargados[player] then
		warn("[Bengala] AnadirStock sin datos cargados: compra no registrada")
		return nil
	end
	local stock = stockDe(player)
	if stock >= BengalaConfig.StockMax then
		return stock -- al máximo: TiendaService debe rechazar la venta antes de cobrar
	end
	stock += 1
	dataService.Guardar(player, "bengalas", stock)
	publicar(player, stock)
	return stock
end

-- La bengala en el mundo: cilindro rojo plantado donde estaba el jugador, luz
-- roja (el alcance visual delata el radio de aturdimiento) y chispas. Sin assets
-- externos (plan L1): textura por defecto de partículas. reduceEfectos no la
-- apaga: es un objeto del mundo que advierte al equipo, no un destello de UI.
local function crearBengala(pos)
	local parte = Instance.new("Part")
	parte.Name = "Bengala"
	parte.Shape = Enum.PartType.Cylinder
	parte.Size = Vector3.new(1.1, 0.35, 0.35) -- eje X = longitud: queda plantada en pie
	parte.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	parte.Color = Color3.fromRGB(224, 69, 58) -- rojo #E04545 (paleta del ADN)
	parte.Material = Enum.Material.Neon
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false

	local luz = Instance.new("PointLight")
	luz.Name = "LuzBengala"
	luz.Color = Color3.fromRGB(255, 70, 50)
	luz.Brightness = 6
	luz.Range = BengalaConfig.RadioAturdimiento
	luz.Shadows = true
	luz.Parent = parte

	local chispas = Instance.new("ParticleEmitter")
	chispas.Name = "Chispas"
	chispas.Color = ColorSequence.new(Color3.fromRGB(255, 140, 70), Color3.fromRGB(224, 69, 58))
	chispas.Size = NumberSequence.new(0.18)
	chispas.LightEmission = 1
	chispas.Lifetime = NumberRange.new(0.4, 0.9)
	chispas.Rate = 50
	chispas.Speed = NumberRange.new(4, 9)
	chispas.SpreadAngle = Vector2.new(180, 180) -- ráfaga radial alrededor del cuerpo
	chispas.Parent = parte

	parte.Parent = workspace
	Debris:AddItem(parte, BengalaConfig.DuracionLuz) -- autodestrucción a los 20 s
	return parte
end

-- Aturde los clones de El Doble dentro del radio (B14: puede haber 2). pcall
-- tolera que Aturdir aún no exista (refactor B14 en curso); el warn deja rastro.
local function aturdirClones(pos)
	if not (monster and type(monster.Aturdir) == "function") then
		warn("[Bengala] MonsterService.Aturdir no disponible (pendiente B14): sin aturdimiento")
		return 0
	end
	local aturdidos = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj.Name == NOMBRE_CLON then
			local distancia = (obj:GetPivot().Position - pos).Magnitude
			if distancia <= BengalaConfig.RadioAturdimiento then
				local ok, err = pcall(monster.Aturdir, obj, BengalaConfig.DuracionAturdimiento)
				if ok then
					aturdidos += 1
				else
					warn("[Bengala] aturdimiento falló: " .. tostring(err))
				end
			end
		end
	end
	return aturdidos
end

-- Uso (remote Bengala, rate limit 2 s): mismo contrato de estado que
-- BeberBebida (EnJuego, sin terminar, de pie, vivo) + stock > 0. Los resultados
-- viajan como clave + params (fase 11 · E44); el cliente resuelve con L().
local function usarBengala(player)
	if not permitirUso(player) then
		return
	end
	if not cargados[player] then
		return -- aún cargando: no tocar el stock persistido (patrón TiendaService)
	end
	if player:GetAttribute("EnJuego") ~= true
		or player:GetAttribute("Terminado") == true
		or playerState.EstaCaido(player) then
		return
	end
	local char = player.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (raiz and hum and hum.Health > 0) then
		return
	end

	local stock = stockDe(player)
	if stock <= 0 then
		remotoResultado:FireClient(player, { ok = false, clave = "bengala_sin_stock", params = { restantes = 0 } })
		return
	end
	stock -= 1
	dataService.Guardar(player, "bengalas", stock)
	publicar(player, stock)

	-- raiz queda ~3 studs sobre el suelo: bajar a media pierna para plantarla.
	local pos = raiz.Position - Vector3.new(0, 2.6, 0)
	crearBengala(pos)
	aturdirClones(pos)

	remotoResultado:FireClient(player, { ok = true, clave = "bengala_usada", params = { restantes = stock } })
	print("[Bengala] " .. player.Name .. " usó una bengala (quedan " .. stock .. ")")
end

function BengalaService.Iniciar()
	dataService = require(script.Parent.DataService)
	playerState = require(script.Parent.PlayerStateService)
	-- B14 está refactorizando MonsterService: pcall por si el require pilla el
	-- archivo a medias (patrón de ChatMimicService en MonsterService).
	local okM, modM = pcall(require, script.Parent.MonsterService)
	if okM then
		monster = modM
	else
		warn("[Bengala] MonsterService no cargó: bengalas sin aturdimiento hasta reiniciar")
	end

	permitirUso = RateLimiter.nuevo(2)
	remotoResultado = Remotes.Crear(Remotes.Nombres.BengalaResult)
	Remotes.Crear(Remotes.Nombres.Bengala).OnServerEvent:Connect(usarBengala)

	-- Al cargar el perfil se publica el stock real (la carga puede llegar tras
	-- el primer uso; mismo patrón de TiendaService con sus atributos).
	dataService.AlCargar.Event:Connect(function(player)
		cargados[player] = true
		publicar(player, stockDe(player))
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		publicar(player, stockDe(player))
	end
	Players.PlayerRemoving:Connect(function(player)
		cargados[player] = nil
	end)

	print("[Bengala] listo: radio " .. BengalaConfig.RadioAturdimiento
		.. ", aturde " .. BengalaConfig.DuracionAturdimiento .. " s, luz " .. BengalaConfig.DuracionLuz .. " s")
end

--[[
GANCHO_COORDINADOR (B13):
1) Main.server.lua: require + BengalaService.Iniciar() tras TiendaService y
   MonsterService.Iniciar() (necesita DataService cargando antes).
2) TiendaService.procesarCompra: rama item.tipo == "bengala" ANTES del bloque
   cosmético (hoy un tipo desconocido entra en "ya comprado → re-equipar gratis"):
   if stockDe >= StockMax → clave "maximo"; cobrar pinasService.Gastar;
   BengalaService.AnadirStock(player); responder con params.bengalas.
   SIN la rama: la 1.ª compra cobra y mete "bengala" en "comprados"; las
   siguientes son gratis y no dan stock (tolerado, no rompe, pero está mal).
3) Strings.lua (ES/EN): bengala_usada, bengala_sin_stock, item_bengala,
   descripcion_bengala, g_bengala ("G: bengala (%d)").
4) TiendaUI.client.lua: caso "bengala" en refrescarTarjeta/crearTarjetaPinas
   (stock del atributo "Bengalas", tope maximo) y añadirlo a esConsumo.
]]
return BengalaService
