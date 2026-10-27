-- Bootstrap del servidor (slice vertical, plan §9 fase 1)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local carpetaRemotes = Instance.new("Folder")
carpetaRemotes.Name = "Remotes"
carpetaRemotes.Parent = ReplicatedStorage

local Server = script.Parent
local StageService = require(Server.StageService)
local PlayerStateService = require(Server.PlayerStateService)
local MatchService = require(Server.MatchService)
local PuntosService = require(Server.PuntosService)
local RankingService = require(Server.RankingService)
local TroncoService = require(Server.TroncoService)
local HazardService = require(Server.HazardService)

StageService.Construir()
PlayerStateService.Iniciar()
MatchService.Iniciar()
PuntosService.Iniciar()
RankingService.Iniciar()
TroncoService.Iniciar()
HazardService.Iniciar()

print("[Slice] servidor listo: etapa, estados, match, puntos, ranking, troncos y rocas")
