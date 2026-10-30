-- Pantalla de carga (plan fase 11 · A2): consejos mientras llega el personaje.
local CargaConfig = {}

CargaConfig.SegundosPorConsejo = 2.2
CargaConfig.MaximoVisible = 8 -- tope duro: nunca tapa el lobby más de esto
CargaConfig.EsperaTrasPersonaje = 2 -- margen tras CharacterAdded para no cortar el tips

CargaConfig.Consejos = {
	"carga_tip_sprint",
	"carga_tip_reanimar",
	"carga_tip_checkpoint",
	"carga_tip_doble",
	"carga_tip_pinas",
}

return CargaConfig
