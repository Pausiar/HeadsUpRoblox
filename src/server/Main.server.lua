-- Bootstrap del servidor (slice vertical, plan §9 fase 1)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local carpetaRemotes = Instance.new("Folder")
carpetaRemotes.Name = "Remotes"
carpetaRemotes.Parent = ReplicatedStorage

local Server = script.Parent
local StageService = require(Server.StageService)
local PlayerStateService = require(Server.PlayerStateService)
local HazardService = require(Server.HazardService)

StageService.Construir()
PlayerStateService.Iniciar()
HazardService.Iniciar()

print("[Slice] servidor listo: etapa construida, estados y peligros activos")
