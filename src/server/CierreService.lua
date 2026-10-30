-- Cierre del servidor (plan fase 11 · A7): avisa antes de apagar para que nadie pierda
-- la partida por sorpresa. El volcado de perfiles lo hace DataService en su propio
-- BindToClose; aquí solo se da margen a los clientes para ver el aviso.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CierreService = {}

local SEGUNDOS_AVISO = 5
local avisando = false
local remoto

function CierreService.Avisar()
	if avisando or not remoto then
		return false
	end
	avisando = true
	remoto:FireAllClients({ segundos = SEGUNDOS_AVISO })
	print("[Cierre] servidor cerrándose: aviso de", SEGUNDOS_AVISO, "s")
	return true
end

function CierreService.Iniciar()
	remoto = Remotes.Crear(Remotes.Nombres.ServidorCerrando)
	game:BindToClose(function()
		if CierreService.Avisar() then
			task.wait(SEGUNDOS_AVISO)
		end
	end)
	print("[Cierre] servicio listo (" .. SEGUNDOS_AVISO .. " s de aviso)")
end

return CierreService
