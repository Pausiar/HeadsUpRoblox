-- ChatRapidoService: frases rápidas de cooperación (fase 11 · L4/B8).
-- El cliente solo envía el id de FrasesConfig; el texto se traduce al idioma
-- de cada receptor (handshake IdiomaCliente) y se filtra POR RECEPTOR antes de
-- enviarse. Límite de frecuencia en servidor: no se puede spamear.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local FrasesConfig = require(ReplicatedStorage.Shared.Config.FrasesConfig)
local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ChatRapidoService = {}

local IDS = {} -- ids válidos; cualquier otra cosa del cliente se descarta
for _, id in ipairs(FrasesConfig.Frases) do
	IDS[id] = true
end

local remoteFrase, remoteChat, remoteIdioma
local idiomas = {} -- [player] = "es" | "en"

local permitirFrase = RateLimiter.nuevo(FrasesConfig.Enfriamiento)
local permitirIdioma = RateLimiter.nuevo(FrasesConfig.EnfriamientoIdioma)

-- Filtro por receptor (plan §2.2): FilterStringAsync se hace una vez por idioma
-- y se reutiliza para cada receptor con GetChatForUserAsync (patrón documentado
-- por Roblox); pcall: si falla, devuelve nil -> no se envía.
local function crearFiltro(texto, emisor)
	local ok, filtro = pcall(function()
		return TextService:FilterStringAsync(texto, emisor.UserId, Enum.TextFilterContext.PublicChat)
	end)
	return ok and filtro or nil
end

local function filtrarPara(filtro, receptor)
	local ok, resultado = pcall(function()
		return filtro:GetChatForUserAsync(receptor.UserId)
	end)
	if ok and resultado then
		return resultado
	end
	return nil
end

-- Traduce al idioma de cada receptor y filtra el resultado; el emisor también
-- recibe su frase (confirmación de que salió).
local function difundir(emisor, id)
	local clave = "frase_" .. id
	local filtros = {} -- [idioma] = TextFilterResult | false (falló: no se reintenta)
	for _, receptor in ipairs(Players:GetPlayers()) do
		if receptor:GetAttribute("EnJuego") == true then
			local idioma = idiomas[receptor] or "es"
			local filtro = filtros[idioma]
			if filtro == nil then
				filtro = crearFiltro(Localization.LPara(idioma, clave), emisor) or false
				filtros[idioma] = filtro
			end
			local filtrado = filtro and filtrarPara(filtro, receptor) or nil
			if filtrado then
				remoteChat:FireClient(receptor, {
					nombre = emisor.DisplayName,
					usuario = emisor.UserId,
					id = id,
					texto = filtrado,
				})
			else
				warn("[Frases] filtro falló, no se envía a " .. receptor.Name)
			end
		end
	end
	print("[Frases] " .. emisor.Name .. " -> " .. id)
end

function ChatRapidoService.Iniciar()
	remoteFrase = Remotes.Crear(Remotes.Nombres.FraseRapida)
	remoteChat = Remotes.Crear(Remotes.Nombres.ChatRapido)
	remoteIdioma = Remotes.Crear(Remotes.Nombres.IdiomaCliente)

	remoteFrase.OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" or not IDS[id] then
			return
		end
		if player:GetAttribute("EnJuego") ~= true then
			return
		end
		if not permitirFrase(player) then
			return
		end
		difundir(player, id)
	end)

	-- Handshake de idioma: Settings del cliente lo envía al arrancar y al cambiar.
	remoteIdioma.OnServerEvent:Connect(function(player, idioma)
		if idioma ~= "es" and idioma ~= "en" then
			return
		end
		if not permitirIdioma(player) then
			return
		end
		idiomas[player] = idioma
	end)

	local function registrar(player)
		idiomas[player] = "es" -- idioma por defecto del proyecto hasta el handshake
	end
	Players.PlayerAdded:Connect(registrar)
	for _, player in ipairs(Players:GetPlayers()) do
		registrar(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		idiomas[player] = nil
	end)

	print("[Frases] activo (" .. #FrasesConfig.Frases .. " frases, enfriamiento " .. FrasesConfig.Enfriamiento .. " s)")
end

return ChatRapidoService
