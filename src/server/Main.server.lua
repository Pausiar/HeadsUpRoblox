-- Bootstrap del servidor (slice vertical, plan §9 fase 1)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local carpetaRemotes = Instance.new("Folder")
carpetaRemotes.Name = "Remotes"
carpetaRemotes.Parent = ReplicatedStorage

local Server = script.Parent
local DataService = require(Server.DataService)
local StageService = require(Server.StageService)
local PlayerStateService = require(Server.PlayerStateService)
local EstaminaService = require(Server.EstaminaService)
local MatchService = require(Server.MatchService)
local LobbyService = require(Server.LobbyService)
local AmigosRankingService = require(Server.AmigosRankingService)
local PuntosService = require(Server.PuntosService)
local RankingService = require(Server.RankingService)
local TerrenoService = require(Server.TerrenoService)
local HazardService = require(Server.HazardService)
local CustomizationService = require(Server.CustomizationService)
local AccesoriosService = require(Server.AccesoriosService)
local RopaService = require(Server.RopaService)
local PinasService = require(Server.PinasService)
local TiendaService = require(Server.TiendaService)
local MonsterService = require(Server.MonsterService)
local ChatMimicService = require(Server.ChatMimicService)
local MonetizacionService = require(Server.MonetizacionService)
local TelemetriaService = require(Server.TelemetriaService)
local CierreService = require(Server.CierreService)

DataService.Iniciar() -- primero: los demás servicios enganchan su AlCargar
StageService.Construir()
TerrenoService.IniciarStreaming() -- después de Construir: ya existen la ruta y las plazas
PlayerStateService.Iniciar()
EstaminaService.Iniciar() -- después de PlayerStateService: consulta si el jugador está caído
MatchService.Iniciar()
LobbyService.Iniciar() -- después de MatchService: engancha AlEmpezar/AlTerminarPartida
AmigosRankingService.Iniciar() -- después de MatchService: escucha AlTerminar
PuntosService.Iniciar()
RankingService.Iniciar()
HazardService.Iniciar()
CustomizationService.Iniciar()
AccesoriosService.Iniciar()
RopaService.Iniciar()
PinasService.Iniciar()
TiendaService.Iniciar() -- después de PinasService, AccesoriosService y CustomizationService: los usa
ChatMimicService.Iniciar()
MonsterService.Iniciar()
MonetizacionService.Iniciar() -- después de TiendaService y MatchService: los usa
TelemetriaService.Iniciar() -- al final: engancha eventos de MatchService y PlayerStateService
CierreService.Iniciar() -- BindToClose propio; DataService vuelca perfiles en paralelo

print("[Slice] servidor listo: lobby, match, estamina, puntos, ranking, terreno, peligros, personalización, ropa, sombreros, Piñas, tienda, El Doble y Robux")
