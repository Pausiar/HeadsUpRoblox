-- Config del Sabueso de la Niebla (fase 11 · L6b, plan §5.4): segundo enemigo,
-- hermano menor de El Doble. Aúlla, acecha al grupo y embiste al más cercano;
-- NUNCA mata (§5.4: causa estado con PlayerStateService.Derribar) y huye si lo
-- apunta una linterna. Todo valor jugable vive aquí: nada mágico en SabuesoService.
local SabuesoConfig = {}

SabuesoConfig.RetardoAparicion = 90 -- s de partida con jugadores EnJuego (después de El Doble, que aparece a 45)

-- Ciclo: Aullido -> Acecho -> Embestida -> (huida) -> Retirada -> Aullido ...
SabuesoConfig.DuracionAullido = 4 -- s quieto aullando antes de acechar
SabuesoConfig.DuracionAcecho = 20 -- s circundando al grupo (una vuelta completa aprox.)
SabuesoConfig.DuracionEmbestida = 3 -- s tope de carga; si no alcanza a nadie, se retira
SabuesoConfig.Enfriamiento = 75 -- s de retirada entre ciclos

SabuesoConfig.VelocidadAcechando = 12
SabuesoConfig.VelocidadEmbistiendo = 26
SabuesoConfig.VelocidadHuyendo = 22

SabuesoConfig.RadioAcechoMin = 25 -- studs del centro del grupo al circundar
SabuesoConfig.RadioAcechoMax = 35
SabuesoConfig.DistanciaAullido = 30 -- studs mínimos del grupo al aparecer y aullar
SabuesoConfig.DistanciaGolpe = 3 -- studs de contacto para el derribo
SabuesoConfig.HuidaGolpe = 50 -- studs que corre tras una embestida (golpee o falle)
SabuesoConfig.HuidaLinterna = 40 -- studs que corre del haz de la linterna
SabuesoConfig.AlcanceLinterna = 30 -- studs: el haz a esta distancia o menos lo delata
SabuesoConfig.AnguloLinterna = 35 -- grados alrededor del haz que cuentan como «apuntarle»

-- Aspecto (primitivas soldadas en SabuesoService)
SabuesoConfig.ColorPelo = Color3.fromRGB(30, 28, 30) -- negro espectral
SabuesoConfig.ColorOjos = Color3.fromRGB(255, 180, 60) -- ámbar: se ven de noche

return SabuesoConfig
