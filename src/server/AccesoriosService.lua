-- AccesoriosService: sombreros del catálogo de TiendaConfig (plan §6, fase 4).
-- Plan B sin catálogo de assets: cada sombrero se construye con primitivas
-- (Parts soldadas a la Head); los meshes .glb definitivos llegarán después.
-- Patrón copiado de CustomizationService: AlCargar + CharacterAdded + persistencia
-- vía DataService, con barrido de carrera por jugadores ya conectados.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TiendaConfig = require(ReplicatedStorage.Shared.Config.TiendaConfig)

-- Paleta del ADN visual (docs/design/design-dna.md)
local ROJO = Color3.fromRGB(224, 69, 58) -- #E0453A
local CREMA = Color3.fromRGB(245, 235, 216) -- #F5EBD8
local AMARILLO = Color3.fromRGB(255, 201, 60) -- #FFC93C
local MARRON = Color3.fromRGB(92, 58, 33) -- #5C3A21
local NEGRO = Color3.fromRGB(30, 30, 30)
local BLANCO = Color3.fromRGB(245, 245, 240) -- fuera de paleta: gorro de chef

local AccesoriosService = {}
local equipado = {} -- [player] = id del sombrero equipado (o nil)

local DataService -- se requiere en Iniciar: Main llama DataService.Iniciar() antes

-- Parte base de sombrero: sin colisión/consulta/touch (no interfiere con el
-- juego ni con raycasts) y sin masa (no altera la física del personaje).
local function nuevaParte(nombre, forma, size, color)
	local parte = Instance.new("Part")
	parte.Name = nombre
	parte.Shape = forma
	parte.Size = size
	parte.Color = color
	parte.Material = Enum.Material.SmoothPlastic
	parte.Anchored = false -- soldada: anclada no seguiría a la cabeza
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Massless = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	return parte
end

-- Cilindro vertical: el cilindro de Roblox se tiende sobre el eje X, así que
-- su Size es (altura, diámetro, diámetro) y se gira 90° en Z al colocarlo.
local function cilindroVertical(nombre, diametro, altura, color)
	return nuevaParte(nombre, Enum.PartType.Cylinder, Vector3.new(altura, diametro, diametro), color)
end

-- Coloca una parte en espacio local de la cabeza (x lateral, y sobre el centro)
-- con un giro opcional en Z y la suelda a la Head con WeldConstraint.
local function colocarYSoldar(parte, head, modelo, offset, giroZ)
	parte.CFrame = head.CFrame
		* CFrame.new(offset)
		* CFrame.Angles(0, 0, math.rad(giroZ or 0))
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = head
	soldadura.Part1 = parte
	soldadura.Parent = parte
	parte.Parent = modelo
end

-- Constructor de sombreros con primitivas. Devuelve el Model "Sombrero"
-- colgado de la Head; todas las Parts van soldadas para seguir al personaje.
local function construirSombrero(head, id)
	local modelo = Instance.new("Model")
	modelo.Name = "Sombrero"
	modelo.Parent = head

	local cima = head.Size.Y / 2 -- del centro de la Head a la coronilla

	if id == "sombrero_gorro" then
		-- Gorro de lana: cilindro rojo 1.4x0.7x1.4 + pompón esfera crema.
		local cuerpo = cilindroVertical("Cuerpo", 1.4, 0.7, ROJO)
		colocarYSoldar(cuerpo, head, modelo, Vector3.new(0, cima + 0.25, 0), 90)
		local pompon = nuevaParte("Pompon", Enum.PartType.Ball, Vector3.new(0.45, 0.45, 0.45), CREMA)
		colocarYSoldar(pompon, head, modelo, Vector3.new(0, cima + 0.8, 0), 0)
	elseif id == "sombrero_copa" then
		-- Copa: copa negra 1.5x1x1.5 + ala negra 2.6x0.15x2.6 + banda amarilla.
		local ala = cilindroVertical("Ala", 2.6, 0.15, NEGRO)
		colocarYSoldar(ala, head, modelo, Vector3.new(0, cima + 0.075, 0), 90)
		local copa = cilindroVertical("Copa", 1.5, 1, NEGRO)
		colocarYSoldar(copa, head, modelo, Vector3.new(0, cima + 0.65, 0), 90)
		local banda = cilindroVertical("Banda", 1.56, 0.2, AMARILLO)
		colocarYSoldar(banda, head, modelo, Vector3.new(0, cima + 0.25, 0), 90)
	elseif id == "sombrero_cuernos" then
		-- Vikingos: banda marrón + 2 cuernos cilíndricos inclinados a arriba-lados.
		local banda = cilindroVertical("Banda", 1.6, 0.3, MARRON)
		colocarYSoldar(banda, head, modelo, Vector3.new(0, cima + 0.15, 0), 90)
		local izq = nuevaParte("CuernoIzquierdo", Enum.PartType.Cylinder, Vector3.new(0.9, 0.35, 0.35), CREMA)
		colocarYSoldar(izq, head, modelo, Vector3.new(-0.85, cima + 0.5, 0), -45)
		local der = nuevaParte("CuernoDerecho", Enum.PartType.Cylinder, Vector3.new(0.9, 0.35, 0.35), CREMA)
		colocarYSoldar(der, head, modelo, Vector3.new(0.85, cima + 0.5, 0), 45)
	elseif id == "sombrero_chef" then
		-- Chef: cilindro blanco alto 1.5x1.6x1.5 sobre base más ancha 1.9x0.3x1.9.
		local base = cilindroVertical("Base", 1.9, 0.3, BLANCO)
		colocarYSoldar(base, head, modelo, Vector3.new(0, cima + 0.15, 0), 90)
		local copa = cilindroVertical("Copa", 1.5, 1.6, BLANCO)
		colocarYSoldar(copa, head, modelo, Vector3.new(0, cima + 1.1, 0), 90)
	else
		modelo:Destroy()
		return nil
	end
	return modelo
end

-- Quita el sombrero actual (idempotente: sin sombrero no hace nada).
local function destruirSombrero(head)
	local actual = head:FindFirstChild("Sombrero")
	if actual then
		actual:Destroy()
	end
end

-- Aplica en vivo: destruye el anterior primero (idempotente) y construye el nuevo.
local function aplicarSombrero(player, head, id)
	destruirSombrero(head)
	if not id then
		return
	end
	local ok, modelo = pcall(construirSombrero, head, id)
	if not ok or not modelo then
		warn("[Accesorios] no se pudo construir el sombrero " .. tostring(id)
			.. " para " .. player.Name .. ": " .. tostring(modelo))
		return
	end
	print("[Accesorios] sombrero " .. id .. " equipado por " .. player.Name)
end

-- Valida contra el catálogo (tipo "sombrero"), persiste y aplica en vivo.
function AccesoriosService.EquiparSombrero(player, id)
	local item = TiendaConfig.PorId(id)
	if not item or item.tipo ~= "sombrero" then
		warn("[Accesorios] id de sombrero desconocido: " .. tostring(id))
		return false
	end
	equipado[player] = id
	DataService.Guardar(player, "sombrero", id) -- persistencia (plan §3.3)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if head then
		aplicarSombrero(player, head, id)
	end
	-- Si aún no hay personaje, se aplicará en el próximo CharacterAdded.
	return true
end

-- Quita el sombrero (estado, persistencia y en vivo).
function AccesoriosService.QuitarSombrero(player)
	equipado[player] = nil
	DataService.Guardar(player, "sombrero", nil)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if head then
		destruirSombrero(head)
	end
end

-- Restaura el sombrero persistido por DataService (plan §3.3). Revalida el id
-- contra el catálogo porque la fuente puede estar corrupta. Si el personaje ya
-- existe, aplica en vivo.
local function cargarSombrero(player, datos)
	local id = type(datos) == "table" and datos.sombrero
	if type(id) ~= "string" then
		return
	end
	local item = TiendaConfig.PorId(id)
	if not item or item.tipo ~= "sombrero" then
		warn("[Accesorios] sombrero guardado inválido para " .. player.Name .. ": " .. tostring(id))
		return
	end
	equipado[player] = id
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if head then
		aplicarSombrero(player, head, id)
	end
end

local function conectarJugador(player)
	player.CharacterAdded:Connect(function(char)
		-- Espera a que el Humanoid y el rig terminen de cargarse tras el spawn.
		task.wait(0.5)
		local id = equipado[player]
		local head = char and char:FindFirstChild("Head")
		if id and head then
			aplicarSombrero(player, head, id)
		end
	end)
end

function AccesoriosService.Iniciar()
	-- Se requiere aquí: Main llama DataService.Iniciar() antes que este.
	DataService = require(script.Parent.DataService)

	Players.PlayerAdded:Connect(conectarJugador)

	Players.PlayerRemoving:Connect(function(player)
		equipado[player] = nil
	end)

	DataService.AlCargar.Event:Connect(cargarSombrero)
	-- AlCargar pudo dispararse antes de conectar el listener (jugadores ya cargados).
	for _, player in ipairs(Players:GetPlayers()) do
		cargarSombrero(player, DataService.Obtener(player))
	end
end

return AccesoriosService
