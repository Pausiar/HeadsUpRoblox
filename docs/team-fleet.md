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

## Contrato de fase 5 (oleada 3)

`MonetizacionService` (servidor, nuevo) expone:

- `Estado(player)` → payload de `PaseEstado`:
  `{ activo, pases = { ranurasRopa = bool, linternaPro = bool }, reanimaciones, pinasX2Hasta, modoPuro }`.
- `TienePase(player, efecto)`, `RanurasRopa(player)` (3 o 9),
  `MultiplicadorPinas(player)` (1 o 2), `EsModoPuro(player)`.
- `Refrescar(player)`: recalcula pases y publica `PaseEstado` a ese jugador.
- Pases: `UserOwnsGamePassAsync` al entrar y tras `ReclamarPase` (el servidor revalida;
  el cliente solo avisa). En Studio sin API degrada a «sin pases» con warn.
- `ComprarRobux` valida id y `disponible`; si `MonetizacionConfig.Activo` es false
  responde `RobuxResult { ok=false, clave="aviso_no_publicado" }` sin prompt.
  Si está activo y es pase → `PromptGamePassPurchase`; producto → `PromptProductPurchase`.
- `ProcessReceipt` de productos: valida productId, idempotencia con DataService `recibos`
  (lista acotada), y entrega: `pinas_x2` (os.time+1800 en `pinasX2Hasta`),
  `reanimacion_personal` (+1 en `reanimacionesPersonales`), `pack_sombreros`
  (los 3 ids a `comprados` vía `TiendaService.ConcederItem`).
- `ReanimarPersonal`: exige caído, no Puro, límite 1 por partida y stock
  (`reanimacionesPersonales`) o `PinasService.Gastar(player, costoPinas)`; reanima con
  `PlayerStateService.Reanimar`; responde `ReanimarResult { ok, clave, params? }`.
  El límite se reinicia en `MatchService.AlEmpezar`.
- `ModoPuro` (boolean): persiste en DataService `modoPuro` y republica `PaseEstado`.
  En Puro no hay reanimación personal ni efecto de Linterna Pro.
- Seams de prueba SOLO Studio (`RunService:IsStudio()`): `_ProbarConceder(player, id)`
  (pase o producto, misma entrega que un recibo válido) y `_ProbarRecibo(player, purchaseId, id)`
  (repetir el mismo purchaseId no entrega dos veces). En producción no existen.

Integraciones:

- `PinasService`: ganadas × `MultiplicadorPinas` y aviso en el payload.
- `RopaService`: `guardarRopa`/`pedirRopa` usan `RanurasRopa`; `RefrescarRanuras(player)`
  publica estado fresco tras un pase.
- `TiendaService.ConcederItem(player, id)`: valida catálogo, añade a `comprados` sin cobrar
  y aplica el cosmético (sombreros/camiseta).
- `Linterna.client.lua`: con `linternaPro` y sin Puro, cono 40,25 y color propio.
- `TiendaUI`: pestañas PIÑAS/ROBUX, catálogo de `MonetizacionConfig`, `PaseEstado` para
  estados, `ReclamarPase` tras `PromptGamePassPurchaseFinished`, toggle Modo Puro.
- `ReanimarPersonalUI`: visible solo con HudEstado «CAÍDO»; muestra stock o coste en Piñas;
  envía `ReanimarPersonal` y muestra `ReanimarResult`.

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
| 3 | 5 | I · Monetización servidor | `server/MonetizacionService.lua`, `Config/MonetizacionConfig.lua`, `server/PinasService.lua`, `server/RopaService.lua`, `server/TiendaService.lua`, `client/Linterna.client.lua` |
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

## Contrato de fase 6 (oleadas 4-5)

Objetivo (plan §9): presupuestos y beta cerrada sin bloqueantes — móvil y mando,
accesibilidad, audio con subtítulos, telemetría y localización ES/EN. Ningún agente toca
`Main.server.lua`, `Remotes.lua`, `docs/skill-log.md` ni `AGENTS.md`; el coordinador integra.

**Oleada 4 (paralela):** G móvil/accesibilidad y K audio/subtítulos. Archivos disjuntos.

### G · Móvil y accesibilidad

- Nuevos: `client/Movil.client.lua`, `client/Accesibilidad.client.lua` y `client/Acciones.lua`
  solo si el helper se reutiliza en dos scripts.
- Edita: `MenuAjustes.client.lua`, `Estamina.client.lua`, `Linterna.client.lua`,
  `CameraController.client.lua`, `shared/Settings.lua` y los ajustes de encaje táctil de
  `TiendaUI`, `ReanimarPersonalUI`, `CustomizationUI`, `LobbyUI`, `MenuInicio`,
  `RankingAmigosUI`, `FinScreen` y los `Hud*.client.lua`.
- `Settings`: añade `idioma = "es"` (lo usará N).
- `MenuAjustes`: sliders de tamaño de texto (80-140) y toggles de subtítulos y reducir
  efectos; safe area en los cuatro lados; el panel debe caber y escalar.
- `Accesibilidad`: aplica `escalaTexto` a los TextSize de PlayerGui (guarda el tamaño base
  una vez en un atributo) y respeta `reducirEfectos`; se reaplica al cambiar el ajuste.
- `Movil`: con `UserInputService.TouchEnabled` añade botones táctiles para sprint (mantener),
  linterna (toque) y cámara (toque) reutilizando `ContextActionService:BindAction`
  (`createTouchButton=true`) o el patrón existente; sin duplicar el manejo de teclado.
- Encaje táctil: resolver los pendientes de `docs/design/revision-apple-design.md`
  (Modo Puro 42→44 px, controles de 40 px de Customization, panel de reanimación con
  UIScale, ROBUX con escala legible). No cambia copia ni remotes.

### K · Audio y subtítulos

- Nuevos: `client/AudioService.client.lua`, `client/Subtitulos.client.lua`.
- Mantiene los sonidos `rbxasset://` de `AudioConfig`; sin assets nuevos ni IDs externos.
- Emite por `Remotes.Crear(Nombres.Sonido)` desde `HazardService` (Aviso), `TroncoService`
  (Aviso/Impacto), `PlayerStateService` (Reanimar), `MonsterService` (Monstruo) y
  `MatchService` (Checkpoint/Fin): `{ id, posicion?, subtitulo? }`.
- `AudioService`: respeta `volumenEfectos`, `volumenMusica` y `reducirEfectos`; música solo
  si `AudioConfig.Musica.id ~= 0`; reutiliza un pool de `Sound`; pcall y consola limpia.
- `Subtitulos`: muestra `subtitulo` 2,5 s abajo-centro, por encima del panel de reanimación,
  solo si `Settings.subtitulos`; crema sobre madera, sin emojis ni alertas.

**Oleada 5 (paralela):** H telemetría (servidor) y N localización (cliente).

### H · Telemetría

- Nuevo: `server/TelemetriaService.lua`; el coordinador llama `Iniciar()` en Main.
- `AnalyticsService` en pcall, con `TelemetriaConfig.Activo`; degrada con un warn en Studio
  sin API. Sin datos personales ni texto libre.
- Conecta `MatchService.AlEmpezar/AlTerminar`, `LobbyService`, `MonsterService` (Rapto),
  `PinasService` (economía) y `TiendaService` (Compra) sin cambiar su comportamiento.
- Embudo `PrimeraPartida`: Lobby → PrimeraEtapa → PrimerCheckpoint → PartidaCompletada,
  una vez por jugador.

### N · Localización

- `Strings.lua` con todas las claves ES/EN del texto visible; los formatos numéricos
  (`%d`, `%02d`) se quedan en cada UI.
- Todos los `client/*.client.lua` componen su texto con `Localization.L`; las pantallas
  estáticas guardan referencias y reasignan al cambiar el idioma.
- `MenuAjustes`: selector ES/EN que llama `Localization.Establecer` y avisa por
  `Settings.AlCambiar("idioma")`; el idioma vive en `Settings.idioma`.
- No toca servidor ni remotes.
