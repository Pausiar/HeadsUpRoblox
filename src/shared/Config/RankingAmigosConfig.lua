-- Config del ranking de amigos (plan §3.3/§4.5): OrderedDataStore con la mejor
-- distancia de cada jugador. Solo se guardan enteros, como exige OrderedDataStore.
local RankingAmigosConfig = {}

RankingAmigosConfig.NombreTienda = "HUMM_Mejores_v1" -- versionado para migraciones
RankingAmigosConfig.PrefijoClave = "u_" -- u_<UserId> -> mejor distancia en studs
RankingAmigosConfig.Top = 10
RankingAmigosConfig.MaxAmigos = 50 -- tope de GetAsync por consulta (presupuesto de DataStore)
RankingAmigosConfig.CacheSegundos = 60 -- caché por jugador
RankingAmigosConfig.EnfriamientoPeticion = 10 -- s entre peticiones del cliente
RankingAmigosConfig.IntervaloRefrescoUI = 60 -- s de refresco automático con el panel abierto
RankingAmigosConfig.FallbackGlobal = true -- si GetFriendsAsync falla o no hay amigos, top global

return RankingAmigosConfig
