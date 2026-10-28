-- Bootstrap del servidor (slice vertical, plan §9 fase 1)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local carpetaRemotes = Instance.new("Folder")
carpetaRemotes.Name = "Remotes"
carpetaRemotes.Parent = ReplicatedStorage

local Server = script.Parent
local DataService = require(Server.DataService)
local StageService = require(Server.StageService)
local PlayerStateService = require(Server.PlayerStateService)
local MatchService = require(Server.MatchService)
local LobbyService = require(Server.LobbyService)
local AmigosRankingService = require(Server.AmigosRankingService)
local PuntosService = require(Server.PuntosService)
local RankingService = require(Server.RankingService)
local TroncoService = require(Server.TroncoService)
local HazardService = require(Server.HazardService)
local CustomizationService = require(Server.CustomizationService)
local PinasService = require(Server.PinasService)
local MonsterService = require(Server.MonsterService)
local ChatMimicService = require(Server.ChatMimicService)

DataService.Iniciar() -- primero: los demás servicios enganchan su AlCargar
StageService.Construir()
PlayerStateService.Iniciar()
MatchService.Iniciar()
LobbyService.Iniciar() -- después de MatchService: engancha AlEmpezar/AlTerminarPartida
AmigosRankingService.Iniciar() -- después de MatchService: escucha AlTerminar
PuntosService.Iniciar()
RankingService.Iniciar()
TroncoService.Iniciar()
HazardService.Iniciar()
CustomizationService.Iniciar()
PinasService.Iniciar()
ChatMimicService.Iniciar()
MonsterService.Iniciar()

print("[Slice] servidor listo: lobby, match, puntos, ranking, troncos, rocas, personalización, Piñas y El Doble")
