-- CosmeticosService (C30 · plan §L8): equipado persistido de las piezas de
-- CosmeticosConfig en datos.cosmeticos = { poseidos = {}, equipados = {} }
-- (esquema v2 de DataService). La COMPRA no va por aquí: TiendaService (rama
-- "cosmetico") cobra con PinasService, añade el id a "poseidos" y llama a
-- CosmeticosService.Equipar; este servicio equipa/desequipa y aplica en vivo.
--
-- Decisión estela solo cliente (plan §L8: "estelas solo cliente"): el servidor
-- NO crea el Trail; publica el atributo "Estela" del personaje y cada cliente
-- construye el suyo en local (TiendaUI). El estado replicado es un string
-- barato en vez de una instancia por jugador, y la muerte/respawn no deja
-- basura de Trail en el servidor.
--
-- Modo Puro NO bloquea los cosméticos (plan §L8 C30: "Modo Puro no las
-- bloquea"): se compran con Piñas ganadas jugando y no dan ventaja de juego,
-- así que aquí no se consulta MonetizacionService.EsModoPuro.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CosmeticosConfig = require(ReplicatedStorage.Shared.Config.CosmeticosConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local CosmeticosService = {}

local DataService -- se requiere en Iniciar: DataService.Iniciar corre antes
local remotoEstado
local permitirEquipar -- RateLimiter.nuevo(0.5) por jugador
local cargados = {} -- [player] = true cuando DataService.AlCargar ya corrió

-- Normaliza la caché viva (patrón datosJugador de TiendaService): a partir de
-- aquí cosmeticos.poseidos/equipados existen siempre. SOLO con datos cargados:
-- crear la tabla antes del merge de DataService descartaría lo persistido.
local function datosCosmeticos(player)
	local datos = DataService.Obtener(player)
	if type(datos.cosmeticos) ~= "table" then
		datos.cosmeticos = { poseidos = {}, equipados = {} }
	end
	if type(datos.cosmeticos.poseidos) ~= "table" then
		datos.cosmeticos.poseidos = {}
	end
	if type(datos.cosmeticos.equipados) ~= "table" then
		datos.cosmeticos.equipados = {}
	end
	return datos.cosmeticos
end

-- Publica el estado para la UI (TiendaUI pinta COMPRAR/EQUIPAR/QUITAR).
local function publicar(player)
	local cos = datosCosmeticos(player)
	remotoEstado:FireClient(player, { poseidos = cos.poseidos, equipados = cos.equipados })
end

local function colorDe(item)
	return Color3.fromRGB(item.color[1] or 255, item.color[2] or 255, item.color[3] or 255)
end

-- Parte base de la mochila: sin colisión/consulta/touch y sin masa (mismo
-- criterio que las Parts de sombrero en AccesoriosService).
local function nuevaParte(nombre, size, color)
	local parte = Instance.new("Part")
	parte.Name = nombre
	parte.Size = size
	parte.Color = color
	parte.Material = Enum.Material.Fabric -- tela: mochila de montaña (ADN visual)
	parte.Anchored = false -- soldada: anclada no seguiría al torso
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Massless = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	return parte
end

local function torsoDe(char)
	return char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
end

-- Mochila: caja 1,6 x 2 x 0,8 soldada a la ESPALDA del torso (+Z: el personaje
-- mira hacia -Z). Idempotente: destruye la anterior antes de construir.
local function aplicarMochila(char, id)
	local torso = torsoDe(char)
	if not torso then
		return
	end
	local anterior = torso:FindFirstChild("Mochila")
	if anterior then
		anterior:Destroy()
	end
	if not id then
		return
	end
	local item = CosmeticosConfig.PorId(id)
	if not item or item.tipo ~= "mochila" then
		warn("[Cosmeticos] id de mochila inválido: " .. tostring(id))
		return
	end
	local modelo = Instance.new("Model")
	modelo.Name = "Mochila"
	local caja = nuevaParte("Caja", Vector3.new(1.6, 2, 0.8), colorDe(item))
	caja.CFrame = torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2 + 0.4)
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = torso
	soldadura.Part1 = caja
	soldadura.Parent = caja
	caja.Parent = modelo
	modelo.Parent = torso
end

-- Estela: el servidor SOLO publica el atributo (el Trail lo crea cada cliente
-- en TiendaUI; ver cabecera). nil desequipa.
local function aplicarEstela(char, id)
	if not char then
		return
	end
	char:SetAttribute("Estela", id)
end

-- Aplica en vivo el tipo equipado; sin personaje lo hará CharacterAdded.
local function aplicar(player, tipo, id)
	local char = player.Character
	if not char then
		return
	end
	if tipo == "mochila" then
		aplicarMochila(char, id)
	elseif tipo == "estela" then
		aplicarEstela(char, id)
	end
end

-- Equipa un cosmético poseído y desequipa el anterior del mismo tipo (al pisar
-- la clave). Revalida la posesión porque EquiparCosmetico también llega directo.
function CosmeticosService.Equipar(player, id)
	local item = CosmeticosConfig.PorId(id)
	if not item then
		warn("[Cosmeticos] id desconocido: " .. tostring(id))
		return false
	end
	local cos = datosCosmeticos(player)
	if not table.find(cos.poseidos, id) then
		warn("[Cosmeticos] " .. player.Name .. " intentó equipar sin poseer: " .. id)
		return false
	end
	cos.equipados[item.tipo] = id
	DataService.Guardar(player, "cosmeticos", cos)
	aplicar(player, item.tipo, id)
	publicar(player)
	print("[Cosmeticos] " .. player.Name .. " equipó " .. id)
	return true
end

-- EquiparCosmetico (limitado): { id } del catálogo o "quitar_mochila"/"quitar_estela".
local function procesarEquipar(player, payload)
	if not permitirEquipar(player) or not cargados[player] then
		return -- sin datos cargados, escribir la caché pisaría el merge
	end
	if type(payload) ~= "table" or type(payload.id) ~= "string" then
		return
	end
	local id = payload.id
	local cos = datosCosmeticos(player)
	for tipo, nombreQuitar in pairs(CosmeticosConfig.Quitar) do
		if id == nombreQuitar then
			if cos.equipados[tipo] then
				cos.equipados[tipo] = nil
				DataService.Guardar(player, "cosmeticos", cos)
				aplicar(player, tipo, nil)
				publicar(player)
				print("[Cosmeticos] " .. player.Name .. " se quitó la " .. tipo)
			end
			return
		end
	end
	CosmeticosService.Equipar(player, id)
end

-- Restaura el equipado persistido (revalidado contra el catálogo Y la posesión:
-- un DataStore manipulado no puede equipar lo que no compró).
local function cargarCosmeticos(player)
	cargados[player] = true
	local cos = datosCosmeticos(player)
	local cambiado = false
	for tipo, id in pairs(cos.equipados) do
		local item = CosmeticosConfig.PorId(id)
		if not item or item.tipo ~= tipo or not table.find(cos.poseidos, id) then
			cos.equipados[tipo] = nil
			cambiado = true
		end
	end
	if cambiado then
		DataService.Guardar(player, "cosmeticos", cos)
	end
	aplicar(player, "mochila", cos.equipados.mochila)
	aplicar(player, "estela", cos.equipados.estela)
	publicar(player)
end

local function conectarJugador(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5) -- patrón AccesoriosService: esperar a que el rig cargue
		if not cargados[player] then
			return -- AlCargar aplicará al terminar la carga
		end
		local cos = datosCosmeticos(player)
		aplicarMochila(char, cos.equipados.mochila) -- reaplica la mochila
		aplicarEstela(char, cos.equipados.estela) -- el Trail lo recrea el cliente
	end)
end

function CosmeticosService.Iniciar()
	-- Se requiere aquí: DataService.Iniciar corre antes (Main llama primero).
	DataService = require(script.Parent.DataService)

	permitirEquipar = RateLimiter.nuevo(0.5)
	remotoEstado = Remotes.Crear(Remotes.Nombres.Cosmeticos)
	local remotoEquipar = Remotes.Crear(Remotes.Nombres.EquiparCosmetico)
	remotoEquipar.OnServerEvent:Connect(procesarEquipar)

	Players.PlayerAdded:Connect(conectarJugador)
	for _, player in ipairs(Players:GetPlayers()) do -- carrera con Iniciar
		conectarJugador(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		cargados[player] = nil
	end)

	DataService.AlCargar.Event:Connect(function(player)
		cargarCosmeticos(player)
	end)
	-- Carrera: perfiles ya cargados antes de conectar el listener. Solo toca
	-- jugadores con datos.cosmeticos presente (señal de carga completada):
	-- normalizar antes del merge descartaría lo persistido.
	for _, player in ipairs(Players:GetPlayers()) do
		if type(DataService.Obtener(player).cosmeticos) == "table" then
			cargarCosmeticos(player)
		end
	end

	print("[Cosmeticos] servicio listo: " .. #CosmeticosConfig.Catalogo
		.. " piezas (mochilas en servidor, estelas solo cliente)")
end

-- Acceso normalizado para TiendaService (rama "cosmetico"): devuelve la tabla
-- viva { poseidos, equipados } de la caché. Solo llamar con datos cargados
-- (procesarCompra lo garantiza: sin carga responde "cargando" antes).
function CosmeticosService.DatosDe(player)
	return datosCosmeticos(player)
end

return CosmeticosService
