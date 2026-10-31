-- ProgresionConfig: XP por evento y tabla de niveles (fase 11 · L8, C32, plan §3).
-- Los valores viven aquí y solo aquí (plan §3.3: todo por datos); el servicio
-- (ProgresionService) escucha las señales del servidor y aplica esta tabla.
-- El nivel NO se persiste: se deriva de `xp` con UmbralDe/NivelDeXp.
local ProgresionConfig = {}

-- XP que otorga cada evento. Los checkpoints y las reanimaciones se pagan en el
-- momento; la distancia y la meta se liquidan UNA vez al cerrar la partida
-- (AlTerminar) para no duplicar con los checkpoints ya cobrados.
ProgresionConfig.XPPor = {
	Checkpoint = 15,
	Meta = 100,
	Reanimar = 30,
	Cada100Studs = 5, -- floor(distancia / 100) × 5 al cerrar la partida
}

-- Umbrales acumulados de XP por nivel (el nivel 1 empieza en 0). El nivel n se
-- alcanza al llegar la XP total al umbral de n. Explícitos hasta 11; más allá
-- se aplica PasoExtra por nivel.
ProgresionConfig.Niveles = {
	[2] = 100,
	[3] = 250,
	[4] = 450,
	[5] = 700,
	[6] = 1000,
	[7] = 1300,
	[8] = 1600,
	[9] = 1900,
	[10] = 2200,
	[11] = 2500,
}
ProgresionConfig.UltimoNivelTabla = 11
ProgresionConfig.PasoExtra = 300 -- XP entre niveles pasados el último de Niveles

-- Recompensa por cruzar a un nivel n: PinasPorNivel × n Piñas, abonadas UNA vez
-- (el perfil guarda `nivelOtorgado` para no repetirla jamás). Los desbloqueos
-- cosméticos de C32 se colgarán de esta tabla cuando el catálogo exponga nivel.
ProgresionConfig.RecompensaPorNivel = {
	PinasPorNivel = 25,
}

-- Umbral acumulado de XP de un nivel (0 para el nivel 1).
function ProgresionConfig.UmbralDe(nivel)
	if nivel <= 1 then
		return 0
	end
	local umbral = ProgresionConfig.Niveles[nivel]
	if umbral then
		return umbral
	end
	local ultimo = ProgresionConfig.UltimoNivelTabla
	return ProgresionConfig.Niveles[ultimo] + ProgresionConfig.PasoExtra * (nivel - ultimo)
end

-- Nivel alcanzado con una XP total acumulada.
function ProgresionConfig.NivelDeXp(xpTotal)
	local nivel = 1
	while ProgresionConfig.UmbralDe(nivel + 1) <= xpTotal do
		nivel += 1
	end
	return nivel
end

return ProgresionConfig
