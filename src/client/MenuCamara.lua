-- Paneles interactivos y primera persona: con CameraMode LockFirstPerson el ratón queda
-- centrado y ningún botón se puede pulsar. Cada panel avisa aquí mientras está abierto;
-- CameraController lee el atributo MenusAbiertos y suspende la primera persona.
local Players = game:GetService("Players")

local MenuCamara = {}

function MenuCamara.Vincular(gui)
	local player = Players.LocalPlayer
	local abierto = false

	local function aplicar()
		if gui.Enabled == abierto then
			return
		end
		abierto = gui.Enabled
		local total = tonumber(player:GetAttribute("MenusAbiertos")) or 0
		player:SetAttribute("MenusAbiertos", math.max(0, total + (abierto and 1 or -1)))
	end

	gui:GetPropertyChangedSignal("Enabled"):Connect(aplicar)
	aplicar()
end

return MenuCamara
