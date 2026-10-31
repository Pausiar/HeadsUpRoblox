-- RenacimientoConfig (fase 11 · L5b): buffs permanentes por renacer. Petición del
-- jugador: «que te permita ganar más puntos de base y que aguante un poco más la
-- velocidad». Renacer NO borra nada: solo consume las metas del requisito.
local RenacimientoConfig = {
	MetasBase = 10, -- metas (victorias) para el primer renacer: MetasBase × (renacimientos + 1)
	BonusPuntosPorRenacer = 0.10, -- +10 % en puntos base (checkpoint y reanimar) por renacer
	BonusAguantePorRenacer = 0.05, -- −5 % de drenaje de estamina por renacer (sprint ~33 % más)
	MaxRenacimientos = 5, -- cap: +50 % puntos y −25 % drenaje como máximo
}

return RenacimientoConfig
