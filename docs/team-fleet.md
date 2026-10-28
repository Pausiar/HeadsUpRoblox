# Flota de agentes · fases 2–7

Organización de la tanda que cierra el juego. Regla base: **archivos disjuntos**,
contratos fijados por el coordinador y verificación en Studio entre oleadas.
Ningún agente edita `src/shared/Remotes.lua`, `src/server/Main.server.lua`,
`docs/skill-log.md`, `docs/PLAN.md` ni `AGENTS.md`.

## Contratos compartidos (commit base)

- Remotes nuevos en `src/shared/Remotes.lua`: `LobbyEstado`, `Listo`,
  `CambiarModo`, `Comenzar`, `RankingAmigos`, `PedirRankingAmigos`,
  `GuardarRopa`, `PedirRopa`, `RopaEstado`, `RopaResult`, `ComprarRobux`,
  `RobuxResult`, `PaseEstado`, `ReanimarPersonal`, `ModoPuro`, `Sonido`.
- Configs: `LobbyConfig`, `RankingAmigosConfig`, `RopaConfig`,
  `MonetizacionConfig`, `AudioConfig`, `TelemetriaConfig`.
- Settings: `subtitulos` y `escalaTexto` (accesibilidad).
- Claves de DataService que usan las fases:
  `ropa = { activa, ranuras }`, `ranurasRopa`, `ropaAccesorio`,
  `modoPuro`, `reanimacionesPersonales`, `pinasX2Hasta`, `recibos`.
- Ranking de amigos: OrderedDataStore `HUMM_Mejores_v1`, clave `u_<UserId>`
  con la mejor distancia entera.

## Oleadas

| Oleada | Fase | Agentes | Archivos (propiedad exclusiva) |
| --- | --- | --- | --- |
| 1 | 2 | A · Lobby servidor | `server/LobbyService.lua`, `server/MatchService.lua`, `server/StageService.lua`, `server/RondaRapidaService.lua`, `Config/LobbyConfig.lua` |
| 1 | 2 | B · Lobby UI | `client/LobbyUI.client.lua`, `client/MenuInicio.client.lua`, `client/Hud.client.lua` |
| 1 | 2 | C · Ranking servidor | `server/AmigosRankingService.lua`, `Config/RankingAmigosConfig.lua` |
| 1 | 2 | D · Ranking UI | `client/RankingAmigosUI.client.lua` |
| 2 | 4 | E · Ropa servidor | `server/RopaService.lua`, `server/AccesoriosService.lua`, `server/TiendaService.lua`, `Config/RopaConfig.lua`, `Config/TiendaConfig.lua` |
| 2 | 4 | F · Ropa UI | `client/CustomizationUI.client.lua`, `client/TiendaUI.client.lua` |
| 2 | 6 | G · Móvil/accesibilidad | `client/Movil.client.lua`, `client/Acciones.lua`, `client/Estamina.client.lua`, `client/Linterna.client.lua`, `client/CameraController.client.lua`, `client/Accesibilidad.client.lua`, `client/MenuAjustes.client.lua`, `shared/Settings.lua` |
| 2 | 6 | H · Telemetría | `server/TelemetriaService.lua`, `Config/TelemetriaConfig.lua`, `server/MonsterService.lua`, `server/PinasService.lua` |
| 3 | 5 | I · Monetización servidor | `server/MonetizacionService.lua`, `Config/MonetizacionConfig.lua`, `server/PinasService.lua`, `server/RopaService.lua`, `server/AccesoriosService.lua`, `client/Linterna.client.lua` |
| 3 | 5 | J · Monetización UI | `client/TiendaUI.client.lua`, `client/ReanimarPersonalUI.client.lua` |
| 4 | 6 | K · Audio/subtítulos | `client/AudioService.client.lua`, `client/Subtitulos.client.lua`, `Config/AudioConfig.lua`, `server/HazardService.lua`, `server/TroncoService.lua`, `server/PlayerStateService.lua`, `server/MonsterService.lua`, `server/MatchService.lua` |
| 4 | 7 | L · Soft launch | `docs/launch/soft-launch.md`, `docs/launch/creator-dashboard.md` |
| 4 | 7 | M · QA y métricas | `docs/launch/qa-matrix.md`, `docs/launch/metrics.md` |
| 5 | 6 | N · Localización | `shared/Localization/Strings.lua` y todos los `client/*.client.lua` |
| 5 | 6 | O · Revisión apple-design | `docs/design/revision-fase6.md` (solo informe, sin código) |

## Dependencias

- La oleada 2 empieza cuando la fase 2 está integrada y verificada.
- La fase 5 depende de `RopaService` (ranuras) y de la tienda con scroll.
- El audio toca `PlayerStateService` después de fase 5 para no pisar el revive personal.
- La localización va al final porque toca todas las pantallas.
- La revisión apple-design va después de localización y no edita código.

## Verificación

- `rojo build` tras cada oleada.
- Playtest MCP al cerrar cada fase: consola sin errores, capturas de lobby,
  personalización, tienda, ranking y audio/subtítulos.
- Evidencia en `docs/skill-log.md` (la escribe el coordinador, no los agentes).
