-- Ajustes del jugador (plan §8: el menú de ajustes es un overlay, no pausa el juego).
-- Módulo compartido: MenuAjustes escribe, CameraController y los efectos leen.
local Settings = {}

Settings.Valores = {
	sensibilidad = 50, -- % (10-100)
	reducirEfectos = false, -- accesibilidad §8: menos movimiento/destellos
	modoAmistoso = false, -- B10: desactiva el empujón; el servidor recibe una copia vía Empujar { accion = "amistoso" } (solo sesión, §3.1 la hará persistente)
	volumenMusica = 70, -- % (0-100)
	volumenEfectos = 80, -- % (0-100)
	subtitulos = true, -- accesibilidad §8: subtítulos de avisos sonoros
	escalaTexto = 100, -- % (80-140), escala global de GUI para texto legible
	escalaUI = 100, -- % (80-120): D37, escala de interfaz por ScreenGui (§3.1 la persiste)
	daltónico = false, -- D40: paleta alternativa para peligros y HUD
	reducirMovimiento = false, -- D42: sin balanceo, transiciones ni clima animado
	idioma = "es", -- "es" | "en" (plan §8: localización desde el primer texto)
}

local cambiado = Instance.new("BindableEvent")
Settings.AlCambiar = cambiado -- (clave, valor)

local LIMITES = {
	sensibilidad = { 10, 100 },
	volumenMusica = { 0, 100 },
	volumenEfectos = { 0, 100 },
	escalaTexto = { 80, 140 },
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
	elseif clave == "idioma" then
		valor = valor == "en" and "en" or "es"
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
