-- ChatMimicService: el chat falso de El Doble (plan §5.5).
-- Repite frases REALES de la memoria del jugador (~60%) y frases de un banco
-- curado (~40%), con erratas solo en el banco. Todo texto pasa por el filtro
-- POR RECEPTOR (plan §2.2) antes de enviarse; si el filtro falla, no se envía.
-- El servidor no pinta nada: envía por el remote ChatFalso y el cliente
-- (ChatMimicView) lo muestra con burbuja.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ChatMimicService = {}
local rng = Random.new()

local cfg = Config.Etapa0.ChatFalso
local NICK_DOBLE = "ElDoble"

-- shortcut: el umbral de señuelo no está en GameConfig.ChatFalso; moverlo allí
-- en cuanto se edite ese archivo.
local UMBRAL_SENUELO = 60 -- studs: nadie a menos de esto del clon -> grupo lejos

-- Cadence de "escritura" (solo cosmético en servidor): 0,05 s por carácter,
-- máximo 3 s. Se aplica como retardo antes de FireClient.
local CADENCE_POR_CARACTER = 0.05
local CADENCE_MAX = 3

-- Banco curado (plan §5.5): cero texto libre generado, cero insultos.
-- ES + EN. "senuelo" = líneas para atraer al grupo cuando está lejos (§5.3).
local BANCO = {
	saludo = { "hola!", "hi!", "hola a todos!", "hello!" },
	queja = { "esta parte es imposible", "this part is impossible", "otra vez no...", "not again..." },
	panico = { "¿VEIS ESO?", "did you see that?!", "qué fue eso?!", "what was that?!" },
	pregunta = { "¿dónde estáis?", "where are you?", "¿alguien ahí?", "anyone there?" },
	broma = { "jajaja", "lol", "jajaja qué fuerte", "lol nice" },
	pedirAyuda = { "ayuda", "help", "ven a ayudarme", "come help me" },
	senuelo = { "estoy aquí, ven", "aquí, ¿dónde estáis?", "por aquí!!", "over here!!" },
}

local remote
local memoria = {} -- [player] = { frase, ... } últimas N; solo sesión, sin DataStore
local mensajesPartida = 0
local huboCaidos = false

local function guardarFrase(player, frase)
	frase = frase and frase:match("^%s*(.-)%s*$")
	if not frase or #frase == 0 then
		return
	end
	local lista = memoria[player]
	if not lista then
		lista = {}
		memoria[player] = lista
	end
	table.insert(lista, frase)
	if #lista > cfg.MemoriaPorJugador then
		table.remove(lista, 1)
	end
end

-- Filtro por receptor (plan §2.2). pcall: si falla, devuelve nil -> no se envía.
local function filtrarPara(texto, receptor)
	local ok, resultado = pcall(function()
		local filtro = TextService:FilterStringAsync(texto, receptor.UserId, Enum.TextFilterContext.PublicChat)
		return filtro:GetChatForUserAsync(receptor.UserId)
	end)
	if ok and resultado then
		return resultado
	end
	return nil
end

local function enviar(receptor, textoFiltrado, nick)
	if remote and receptor.Parent then
		remote:FireClient(receptor, { nick = nick or NICK_DOBLE, texto = textoFiltrado })
	end
end

local function enJuego()
	local lista = {}
	for _, player in Players:GetPlayers() do
		local raiz = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if raiz and player:GetAttribute("EnJuego") then
			table.insert(lista, { player = player, pos = raiz.Position })
		end
	end
	return lista
end

local function posicionDoble()
	local clon = workspace:FindFirstChild(NICK_DOBLE)
	if not clon then
		return nil
	end
	local parte = clon:IsA("BasePart") and clon or clon.PrimaryPart
		or clon:FindFirstChildWhichIsA("BasePart", true)
	return parte and parte.Position or nil
end

-- Frase real de la memoria de la víctima más cercana al clon (o cualquier
-- memoria si ninguna está cerca). nil si no hay memoria aún.
local function fraseReal(jugadores, posDoble)
	local mejor, mejorDist
	for _, o in jugadores do
		local lista = memoria[o.player]
		if lista and #lista > 0 then
			local d = (o.pos - posDoble).Magnitude
			if not mejorDist or d < mejorDist then
				mejor, mejorDist = lista, d
			end
		end
	end
	if mejor then
		return mejor[rng:NextInteger(1, #mejor)]
	end
	return nil
end

local function fraseBanco(grupoLejos)
	if grupoLejos then
		local v = BANCO.senuelo
		return v[rng:NextInteger(1, #v)]
	end
	local claves = { "saludo", "queja", "panico", "pregunta", "broma", "pedirAyuda" }
	local v = BANCO[claves[rng:NextInteger(1, #claves)]]
	return v[rng:NextInteger(1, #v)]
end

-- Errata (10%): duplicar una letra. SOLO frases del banco, jamás frases reales.
local function conErrata(texto)
	local posiciones = {}
	for i = 1, #texto do
		if texto:sub(i, i):match("%a") then
			table.insert(posiciones, i)
		end
	end
	if #posiciones == 0 then
		return texto
	end
	local pos = posiciones[rng:NextInteger(1, #posiciones)]
	return texto:sub(1, pos) .. texto:sub(pos, pos) .. texto:sub(pos + 1)
end

local function hablar(playerState)
	local jugadores = enJuego()
	if #jugadores == 0 then
		return
	end

	-- Máximo por partida (simplificación): contador global que se reinicia
	-- cuando todos vuelven a estar no caídos tras haber habido caídos
	-- (aprox. el reinicio de MatchService).
	local hayCaido = false
	for _, o in jugadores do
		if playerState.EstaCaido(o.player) then
			hayCaido = true
		end
	end
	if hayCaido then
		huboCaidos = true
	elseif huboCaidos then
		huboCaidos = false
		mensajesPartida = 0
		print("[ChatFalso] contador reiniciado (nadie caído tras haber caídos)")
	end
	if mensajesPartida >= cfg.MaxMensajesPorPartida then
		return
	end

	local posDoble = posicionDoble()
	if not posDoble then
		return -- sin el clon de MonsterService no hay mimo
	end

	-- §5.3: si nadie del grupo está cerca de la víctima del Doble, prioriza señuelo.
	local distMin = math.huge
	for _, o in jugadores do
		local d = (o.pos - posDoble).Magnitude
		if d < distMin then
			distMin = d
		end
	end
	local grupoLejos = distMin > UMBRAL_SENUELO

	-- 60% frase real de la víctima / 40% banco curado (errata solo en el banco).
	local texto
	if rng:NextNumber() < 0.6 then
		texto = fraseReal(jugadores, posDoble)
	end
	if not texto then
		texto = fraseBanco(grupoLejos)
		if rng:NextNumber() < 0.1 then
			texto = conErrata(texto)
		end
	end

	mensajesPartida += 1

	-- Cadence de escritura + filtro por receptor en el momento del envío.
	local retardo = math.min(#texto * CADENCE_POR_CARACTER, CADENCE_MAX)
	task.delay(retardo, function()
		for _, o in jugadores do
			local filtrado = filtrarPara(texto, o.player)
			if filtrado then
				enviar(o.player, filtrado)
				print("[ChatFalso] ElDoble ->", o.player.Name, '("' .. filtrado .. '")')
			else
				warn("[ChatFalso] filtro falló, no se envía a " .. o.player.Name)
			end
		end
	end)
end

-- API para MonsterService: publica una línea de señuelo con el nick dado.
-- Filtrada por receptor igualmente; no cuenta para MaxMensajesPorPartida
-- (el ritmo de estas líneas lo controla MonsterService).
function ChatMimicService.HablarComo(nick, texto, receptor)
	if type(texto) ~= "string" or #texto == 0 or not receptor or not receptor.Parent then
		return false
	end
	local filtrado = filtrarPara(texto, receptor)
	if not filtrado then
		warn("[ChatFalso] filtro falló en HablarComo, no se envía")
		return false
	end
	enviar(receptor, filtrado, nick)
	print("[ChatFalso] señuelo:", nick or NICK_DOBLE, "->", receptor.Name)
	return true
end

function ChatMimicService.Iniciar()
	remote = Remotes.Crear(Remotes.Nombres.ChatFalso)
	local playerState = require(script.Parent.PlayerStateService)

	-- Memoria de chat real (plan §5.5). Chatted también dispara con TextChatService.
	local function escuchar(player)
		player.Chatted:Connect(function(mensaje)
			guardarFrase(player, mensaje)
		end)
	end
	Players.PlayerAdded:Connect(escuchar)
	for _, player in Players:GetPlayers() do
		escuchar(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		memoria[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(cfg.IntervaloMin, cfg.IntervaloMax))
			hablar(playerState)
		end
	end)

	print("[ChatFalso] activo (máx " .. cfg.MaxMensajesPorPartida .. " por partida)")
end

return ChatMimicService
