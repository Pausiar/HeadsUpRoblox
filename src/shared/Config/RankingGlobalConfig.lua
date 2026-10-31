-- Config del ranking global mensual (plan §L8 · C31): OrderedDataStore con la
-- mejor distancia de cada jugador que cerró una meta en Modo Puro. Solo
-- enteros, como exige OrderedDataStore.
local RankingGlobalConfig = {}

RankingGlobalConfig.NombreTienda = "HUMM_Global_v1" -- base versionada; el servicio abre NombreTienda .. "_" .. Mes()
RankingGlobalConfig.Mes = function()
	return os.date("!%Y%m") -- "yyyymm" en UTC: una tienda por mes, el ranking se reinicia solo
end
RankingGlobalConfig.PrefijoClave = "u_" -- u_<UserId> -> mejor distancia en studs del mes
RankingGlobalConfig.TopN = 50
RankingGlobalConfig.EnfriamientoPeticion = 5 -- s entre peticiones del cliente (rate limit)

return RankingGlobalConfig
