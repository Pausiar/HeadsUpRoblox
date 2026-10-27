-- Ajustes del jugador (plan §8: el menú de ajustes es un overlay, no pausa el juego).
-- Módulo compartido: MenuAjustes escribe, CameraController y los efectos leen.
local Settings = {}

Settings.Valores = {
	sensibilidad = 50, -- % (10-100)
	reducirEfectos = false, -- accesibilidad §8: menos movimiento/destellos
	volumenMusica = 70, -- % (0-100)
	volumenEfectos = 80, -- % (0-100)
}

local cambiado = Instance.new("BindableEvent")
Settings.AlCambiar = cambiado -- (clave, valor)

local LIMITES = {
	sensibilidad = { 10, 100 },
	volumenMusica = { 0, 100 },
	volumenEfectos = { 0, 100 },
}

function Settings.Cambiar(clave, valor)
	if Settings.Valores[clave] == nil then
		return false
	end
	local limites = LIMITES[clave]
	if limites then
		valor = math.clamp(tonumber(valor) or Settings.Valores[clave], limites[1], limites[2])
	end
	if type(Settings.Valores[clave]) == "boolean" then
		valor = valor == true
	end
	if Settings.Valores[clave] == valor then
		return true
	end
	Settings.Valores[clave] = valor
	cambiado:Fire(clave, valor)
	return true
end

function Settings.Obtener(clave)
	return Settings.Valores[clave]
end

return Settings
