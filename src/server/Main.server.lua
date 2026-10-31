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
local ChatRapidoService = require(Server.ChatRapidoService)
local MonetizacionService = require(Server.MonetizacionService)
local TelemetriaService = require(Server.TelemetriaService)
local CierreService = require(Server.CierreService)
local TutorialService = require(Server.TutorialService)
local CargarService = require(Server.CargarService)
local EmpujonService = require(Server.EmpujonService)
local ClimaService = require(Server.ClimaService)
local BengalaService = require(Server.BengalaService)

DataService.Iniciar() -- primero: los demás servicios enganchan su AlCargar
TutorialService.Iniciar() -- después de DataService: escucha AlCargar
StageService.Construir()
TerrenoService.IniciarStreaming() -- después de Construir: ya existen la ruta y las plazas
PlayerStateService.Iniciar()
EstaminaService.Iniciar() -- después de PlayerStateService: consulta si el jugador está caído
CargarService.Iniciar() -- L5 · B9: después de PlayerStateService y EstaminaService
EmpujonService.Iniciar() -- L5 · B10: después de PlayerStateService (consulta caído) y CargarService (porte)
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
ChatRapidoService.Iniciar() -- frases rápidas: solo depende de remotes, config y Settings del cliente
MonsterService.Iniciar()
BengalaService.Iniciar() -- L6 · B13: después de MonsterService (atura a sus clones) y TiendaService (ventas)
ClimaService.Iniciar() -- L6 · B12: sin dependencias; programa eventos solo con jugadores EnJuego
MonetizacionService.Iniciar() -- después de TiendaService y MatchService: los usa
TelemetriaService.Iniciar() -- al final: engancha eventos de MatchService y PlayerStateService
CierreService.Iniciar() -- BindToClose propio; DataService vuelca perfiles en paralelo

print("[Slice] servidor listo: lobby, match, estamina, puntos, ranking, terreno, peligros, personalización, ropa, sombreros, Piñas, tienda, El Doble y Robux")
