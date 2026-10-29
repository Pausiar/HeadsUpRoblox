-- Limitación de frecuencia para remotes entrantes (plan §3.3: limitación en todos).
-- Uso: local permitir = RateLimiter.nuevo(3); if permitir(jugador) then ... end
local RateLimiter = {}

function RateLimiter.nuevo(enfriamientoSeg)
	assert(type(enfriamientoSeg) == "number" and enfriamientoSeg > 0, "enfriamientoSeg debe ser > 0")
	-- Claves débiles: un jugador que se va no queda retenido por la tabla.
	local ultima = setmetatable({}, { __mode = "k" })
	return function(clave)
		local ahora = os.clock()
		local t = ultima[clave]
		if t and ahora - t < enfriamientoSeg then
			return false
		end
		ultima[clave] = ahora
		return true
	end
end

return RateLimiter
