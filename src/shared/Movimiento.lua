-- D42 (fase 11 · L9): helper común para el ajuste «Reducir movimiento».
-- Cámara, clima y transiciones leen aquí; ningún sistema duplica la condición.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)

local Movimiento = {}

-- true si el jugador pidió menos movimiento (ajuste persistido §3.1).
function Movimiento.Reducido()
	return Settings.Obtener("reducirMovimiento") == true
end

-- Sustituto de TweenService:Create: con Reducido el tween corre en 0,05 s y sin
-- repeticiones (casi instantáneo), pero devuelve el mismo Tween (Play/Completed/
-- Cancel) para que los llamadores no cambien.
function Movimiento.Tween(instancia, info, props)
	if Movimiento.Reducido() then
		info = TweenInfo.new(0.05)
	end
	return TweenService:Create(instancia, info, props)
end

return Movimiento
