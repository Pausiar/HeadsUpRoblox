-- MisionesConfig: catálogo de misiones diarias (fase 11 · L8, C26, plan §3.1).
-- Cada día UTC MisionesService elige PorDia misiones de este pool con
-- Random.new(diaNum) (diaNum = yday UTC): la selección es la misma en todos los
-- servidores y jugadores de ese día. `pinas` es la recompensa al reclamar
-- (ajustable aquí; el texto de las descripciones vive en Localization.Strings
-- con las claves mision_*_desc, que añade el coordinador).
local MisionesConfig = {}

MisionesConfig.PorDia = 3

-- beber_1 está en el catálogo pero SU SEÑAL DE SERVIDOR NO EXISTE todavía
-- (TiendaService llama EstaminaService.Reponer sin evento): MisionesService la
-- omite del pool hasta que haya señal. El resto engancha señales reales.
MisionesConfig.Misiones = {
	{ id = "caminar_2000", descripcionClave = "mision_caminar_desc", meta = 2000, pinas = 25 },
	{ id = "reanimar_2", descripcionClave = "mision_reanimar_desc", meta = 2, pinas = 40 },
	{ id = "checkpoints_10", descripcionClave = "mision_checkpoints_desc", meta = 10, pinas = 30 },
	{ id = "meta_1", descripcionClave = "mision_meta_desc", meta = 1, pinas = 20 },
	{ id = "beber_1", descripcionClave = "mision_beber_desc", meta = 1, pinas = 15 },
}

-- Misión por id (nil si no existe).
function MisionesConfig.PorId(id)
	if type(id) ~= "string" then
		return nil
	end
	for _, mision in ipairs(MisionesConfig.Misiones) do
		if mision.id == id then
			return mision
		end
	end
	return nil
end

return MisionesConfig
