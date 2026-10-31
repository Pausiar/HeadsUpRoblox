-- Config de la bengala (fase 11 · B13, plan L6): consumible de tienda con stock.
-- Al usarla, el servidor planta una bengala en el mundo (luz + chispas, 20 s)
-- y aturde a los clones de El Doble dentro del radio (4 s: se detienen y no
-- raptan). El precio vive TAMBIÉN en TiendaConfig.Catalogo como literal (patrón
-- del catálogo); si se cambia aquí, cambiar el de la tienda para no desincronizar.
local BengalaConfig = {}

BengalaConfig.Precio = 40 -- Piñas (literal coherente en TiendaConfig)
BengalaConfig.RadioAturdimiento = 40 -- studs alrededor de la bengala
BengalaConfig.DuracionAturdimiento = 4 -- s que el clon se detiene y no rapta
BengalaConfig.DuracionLuz = 20 -- s de vida de la bengala en el mundo
BengalaConfig.StockInicial = 0 -- stock nuevo (DataService "bengalas")
BengalaConfig.StockMax = 3 -- tope persistido; también en TiendaConfig (maximo)

return BengalaConfig
