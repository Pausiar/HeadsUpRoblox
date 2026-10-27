-- Bootstrap del servidor (slice vertical, plan §9 fase 1)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local carpetaRemotes = Instance.new("Folder")
carpetaRemotes.Name = "Remotes"
carpetaRemotes.Parent = ReplicatedStorage

local Server = script.Parent
local StageService = require(Server.StageService)
local PlayerStateService = require(Server.PlayerStateService)
local MatchService = require(Server.MatchService)
local TroncoService = require(Server.TroncoService)
local HazardService = require(Server.HazardService)

StageService.Construir()
PlayerStateService.Iniciar()
MatchService.Iniciar()
TroncoService.Iniciar()
HazardService.Iniciar()

print("[Slice] servidor listo: etapa, estados, match, troncos y rocas activos")
