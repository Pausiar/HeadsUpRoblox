# Handoff — Heads Up! Mountain Mayhem

Estado a **2026-10-30** · rama `main` · repo `github.com/Pausiar/HeadsUpRoblox`.

Documento para retomar el trabajo en otro chat. Fuente de verdad del diseño: [`docs/PLAN.md`](PLAN.md).
Reglas de trabajo obligatorias: [`AGENTS.md`](../AGENTS.md).

---

## 1. Qué es y en qué punto está

- Juego cooperativo de Roblox para 2–8 jugadores: subir una montaña siguiendo un sendero, esquivar peligros diegéticos, reanimar compañeros y sobrevivir a El Doble.
- **Estado:** jugable de principio a fin en Studio (lobby → partida → meta → resultados), en español e inglés.
- **No publicado.** Sin DataStore real, sin IDs de monetización, sin audio definitivo.
- Fases cerradas: 0 (prep/spikes), 1 (vertical slice), 2 (lobby + ranking), 3 (El Doble + chat imitado), 4 (ropa y personalización), 5 (Robux), 6 (audio, móvil, accesibilidad, telemetría, i18n), 7 (docs de lanzamiento), 8 (terreno voxel y rutas), 9 (mundo largo por teselas, meta, tienda, peligros, noche/sustos) y el cierre formal de la 9 (auditoría, ledger, graphify).
- **Fase 10 en curso:** el QA que no depende de publicar ya está hecho (hitch de teselas, 3 clientes en Studio, UI en A06/iPhone con Device Simulator). Lo que falta necesita tu cuenta o hardware: `docs/pendiente-usuario.md`.
- **Fase 11 en curso (2026-10-30):** lotes **L0 cerrado** (E45, E44, E43, E46, E49), **L1 cerrado** (C25, D34, A5, A7), **L2 cerrado** (A1 tutorial, A2 pantalla de carga, A3 invitar, A4 descripciones de modo, A8 resultados ampliados) y **L4 cerrado** (B4 semillas curadas, B5 récord en HUD, B6 medallas y mejor rápida, B7 causa de caída con feed, B8 frases rápidas filtradas). L5 cerrada a nivel de 1 jugador (2026-10-31, commits 7d42e9a + 61962ba): boot limpio con «Refugio construido en el checkpoint 9 (ruta 2340 studs)», «Cargar servicio iniciado (radio 8, velocidad 10, portadores 1)» y «Empujon activo (enfriamiento 3 s)»; humo E49 con L5 en verde («QA-HUMO OK: lobby → partida → meta con 44 checkpoints en 2 pasadas, refugio en el mundo en (734, 9.3, 172), servicios L5 activos», Piñas de meta +125 y +100). **L6 cerrada a nivel de 1 jugador (2026-10-31, commit 68c6ae1): boot limpio con «Bengala listo (radio 40, aturde 4 s, luz 20 s)», «Clima servicio activo (evento cada 60-120 s)» y «Tienda lista: 12 items» (bengala incluida, rama consumible en TiendaService); fix de Enum en CreditosUI. Pendiente: QA de 2 clientes (QA-65) para cargar/empujón/segundo Doble/bengala entre cuentas** y revisión visual del refugio (árboles sobre la losa). Después sigue **L6** (B12 clima, B13 bengala, B14 segundo Doble, B15 reacciones); **L3** (reconexión) queda para después del soft launch según el corte de lanzamiento §7 — ver `docs/fase-11-plan.md`. Pendiente de place publicado: confirmar que el récord sobrevive a un rejoin (en Studio el DataStore es memoria) y ajustar los umbrales de medalla con tiempos reales; los «refugios» del criterio B4 llegan con B3.

---

## 2. Cómo arrancar

```bash
cd D:\HeadsUpRoblox
rojo build default.project.json -o build/HeadsUp.rbxlx
```

1. Cerrar cualquier sesión de Studio abierta (**nunca dos a la vez**).
2. Abrir `build/HeadsUp.rbxlx` en Roblox Studio con el MCP de Studio activo (Assistant).
3. Playtest con `start_stop_play`, `get_console_output`, `screen_capture`, `user_keyboard_input`.

### Notas de tooling (dolores ya conocidos)

- **Rojo = código, MCP = escena.** El MCP nunca edita un script sincronizado: se cambia en disco y se regenera el place.
- `require` dentro de `execute_luau` no comparte el estado de los módulos: para probar, inspeccionar objetos del mundo o disparar remotes reales desde el datamodel Client.
- `screen_capture` sale **en blanco** si la ventana de Studio está ocluida por otra app; hay que traerla al frente antes de capturar.
- `user_keyboard_input` solo llega al juego con Studio en primer plano (si no, la tecla se pierde en silencio).
- DataStore no funciona en Studio: `[Datos] servicio listo (modo memoria)`.
- Cerrar Studio con `CloseMainWindow` se cuelga por un diálogo oculto de guardado; se usa `Stop-Process -Id <pid> -Force` (el place es un artefacto regenerable).

---

## 3. Lo que ya está hecho

| Fase | Contenido | Evidencia / commit |
| --- | --- | --- |
| 0 | Rojo, MCP, git, graphify, spikes (objetos, chat, físicas, R15) | — |
| 1 | Slice jugable: ruta corta, peligros, caído y reanimar, HUD, cámara 3.ª/1.ª | — |
| 2 | Lobby 2–8 (esperando/cuenta/partida/resultados), ranking de amigos (OrderedDataStore) | `3d8c81a` |
| 3 | El Doble (máquina de estados, raptos, retirada, máx. 2, nunca mata), chat imitado con filtro por receptor, linterna F | — |
| 4 | Ropa plan B (2 SurfaceGui, 9 ranuras), editor de cuerpo y camisetas, sombreros | `24b2fa5`, `2101a96` |
| 5 | Robux: 5 pases, 3 productos, `ProcessReceipt`, reanimación personal, Modo Puro | `a75e7e5` |
| 6 | Audio con pool, subtítulos, fila táctil, accesibilidad (100–140 %), telemetría (embudo `PrimeraPartida`), ES/EN | `a911fe3` |
| 7 | Soft launch, creator dashboard, matriz QA (59 casos + 16 negativos), métricas | `0b0b7d9` |
| 8 | Terreno voxel determinista + rutas Catmull-Rom, StageService/RondaRapida sobre rutas, progreso por altura | `e04a788` |
| 9 | Ruta de 4846 studs en teselas de 160 con streaming, meta con victoria (+100 Piñas), tienda del campamento, peligros diegéticos (árboles/piedras), Piñas en vivo | `b255370` |
| 9+ | Noche cerrada, linterna ampliada, sustos ambientales, fin del teletransporte fuera de ruta | `f7bcbd6` |
| 9-cierre | Auditoría y ledger; El Doble/ChatFalso por partida; tope de progreso; Modo Puro en ranking; rollback de recibos; guardas de reanimar/beber | `0cb38bc`, `02537b7` |
| 10+ | Sendero desenterrado en ronda rápida y tienda de campamento compartida por Historia y Ronda Rápida | `20860c1`, `b3a3a9f` |
| 10+ | Animación de beber: lata 3D en la mano que sube a la boca, con pose-lock sobre el rig R15 | `8390486` |
| 10+ | Ratón libre con paneles en 1.ª persona: `MenuCamara` avisa en `MenusAbiertos` y la cámara sale a Classic con zoom 8; al cerrar el último panel vuelve el modo elegido | `74047e9` |

### Números y datos clave

- Ruta historia: **4846 studs**, 18 checkpoints cada 260, ~5 min; meta a 10 studs del final.
- Piñas: 1 por 20 studs caminados, +25 por récord, +100 por meta; se pagan en vivo a 1 Hz.
- Tienda de campamento compartida por Historia y Ronda Rápida (`TiendaCampamento` sobre `Escenario`), 11,8×8,8 studs con el centro a 13,5 del inicio: mostrador, toldo, cartel «TIENDA», guirnalda, dos faroles, hoguera, estanterías, cajas y barriles; 11 items.
- Entrada en partida desde el lobby (mín. 1 para probar), cuenta atrás 5 s, resultados 12 s.
- Peligros: cada 8–13 s, 55 % árbol / 45 % piedras, derribo instantáneo, sin aviso sonoro.
- El Doble aparece a los 45 s de partida; el chat falso máx. 6 veces por partida.
- Streaming: carga 480 studs por delante, descarga 520 por detrás, nunca bajo un jugador.
- Noche: `ClockTime 0.3`, brillo 1.15; linterna F 46° (52,9° con pase), 60 studs, brillo 4; sustos cada 18–40 s para todos los que están en partida (sin subtítulo).
- Fuera del sendero: sin teleport; solo rescate al vacío (`Y < -10`). El progreso solo cuenta dentro del corredor (25 studs).

---

## 4. Última tanda (2026-10-29 · `f7bcbd6`)

Pedido del usuario: «si te sales del camino te tepee → quítalo; noche con poca visibilidad; sonidos creepy aleatorios».

- `MatchService`: eliminado el rescate por distancia (>90 studs); queda solo el de vacío con enfriamiento de 2 s.
- `TerrenoConfig.Ambiente`: noche azulada con niebla baja; sin tocar la lógica de terreno.
- `Linterna.client.lua`: cono y alcance ampliados, brillo 4 (antes fijo a 2).
- `AudioConfig` + `HazardService`: 4 sustos nativos a velocidad baja, remoto `Sonido`, no críticos (se omiten con «reducir efectos»).
- Revisión: un susto a un jugador al azar dejaba 2,4–5,3 min entre sustos con 8 jugadores → ahora suena para todos los que están en partida.

**Evidencia de playtest:** captura `Fase9_NochePartida2` (noche + cono visible); `[Susto]` de los 4 tipos en consola; HRP anclado 60 studs fuera de la ruta 3,5 s sin `[Match] rescate` y `Distancia=0`; a `Y=-50` el rescate devuelve al jugador a la ruta; build limpio con `[Susto] Rama a 1 jugador(es)`. Consola sin errores nuevos.

### Cierre de fase 9 (2026-10-29 · `0cb38bc`, `02537b7`)

Correcciones que salieron de la auditoría y del repaso de flujos:

- `MonsterService`: un token de partida (`generacion`) mata el hilo anterior; El Doble vuelve a aparecer en cada partida (antes solo una vez por servidor).
- `ChatMimicService`: el tope de 6 mensajes se reinicia en `AlEmpezar`, no con la heurística de «hubo caídos».
- `MatchService`: tope de progreso de 32 studs/s + 4 de holgura; un teletransporte de cientos de studs no cobra checkpoints, Piñas ni meta.
- `AmigosRankingService`: solo guarda marcas si `MonetizacionService.EsModoPuro(player)` (PLAN §7.3); la tienda avisa «Ranking: solo en Modo Puro».
- `MonetizacionService`: si la entrega de un recibo falla, se desmarca para que Roblox reintente; `ReanimarPersonal` rechaza partidas cerradas.
- `TiendaService`: beber exige `EnJuego`, no `Terminado` y no estar caído.
- `RateLimiter`: claves débiles para no retener jugadores que abandonan.
- Cliente: el chat imitado escapa RichText; el velo de `FinScreen` bloquea clics; botones táctiles ordenados 1–4; aviso de ranking Puro.

**Evidencia:** prueba sintética `QATestVelocidad` → `[QA] teleport: distancia antes=0 despues=0` y `[QA] paso corto de 20 studs: distancia=20`; `QATestDoble` → dos ciclos completos con `[Doble] retirada (raptos 1/1)` y `[Doble] fin: máximo de raptos (1/1) alcanzado`; `QATestBeber` → stock 3→2 de pie, y se queda en 2 caído o con `Terminado=true`; dos arranques limpios en Studio; compilación Luau 0.744 de los 16 archivos. `graphify update .`: 859 nodos, 1509 aristas, 42 comunidades.

### Animación de beber (2026-10-29 · `8390486`)

Pedido del usuario: «añade una animación simple al usar los objetos: que salga un objeto 3D en la mano y, por ejemplo, la bebida energética se acerque a la cara».

- `AnimacionBeber.client.lua` (nuevo, cliente): al recibir `BebidaResult {ok=true}`, arma una lata de 3 cilindros (cuerpo verde, banda amarilla, tapa metálica) soldada a `RightHand`; desactiva `RightShoulder`/`RightElbow` y tweenea la pose con Welds (hombro 50°/60°/−70°, codo 135°; la mano queda a 1,26 studs de la boca). Subida 0,45 s, aguante 0,85 s y bajada 0,35 s a la pose de reposo; al terminar suelta los Welds y reactiva las juntas.
- Guardas: `reducirEfectos` (accesibilidad §8), fuera de partida, segunda bebida durante la animación y rig sin `AnimationConstraint`; `CharacterRemoving` y fin de partida cancelan con token y limpian.
- `shortcut:` la animación es solo local: los demás jugadores no ven la lata; en rigs R6/Motor6D se omite.

**Evidencia:** capturas de ventana real con la lata en la boca de noche (cuerpo verde y banda amarilla) en 6 bebidas seguidas; observador `[QA-ANIM] lata visible` → `[QA-ANIM] lata retirada`; con la pose activa `hombroEnabled=false` y al acabar `hombroEnabled=true codoEnabled=true restos=ninguno`; `[QA] reducirEfectos=true stock 2->1 lata=false enJuego=true` (la bebida se consume y la animación se omite); artefacto final reconstruido y jugado; consola limpia (solo DataStore en memoria y asset 203785492).

### Camino de ronda rápida y tienda nueva (2026-10-29 · `20860c1`, `b3a3a9f`)

Pedido del usuario: «en el modo ronda rápida el camino hay veces que desaparece y no hay tienda al principio; haz una mejor tienda, más grande, con estética de tienda de campamento».

- `TerrenoService.alturaConSendero`: las plazas de inicio/meta/madriguera aplanaban el terreno **después** del corredor; donde la ruta llegaba más baja, la plaza tapaba el sendero y el camino desaparecía. Ahora la plaza se aplica antes y el corredor manda sobre ella.
- `TiendaCampamento` (nuevo): puesto de campaña compartido por Historia (`StageService`) y Ronda Rápida (`RondaRapidaService`), con toldo a dos aguas, faldón y cartel «TIENDA», guirnalda de bombillas, dos faroles con luz, mostrador, estanterías con mercancía y botellas, cajas, barriles, hoguera con bancos y banderín. Sustituye la tienda pequeña de Historia (6 studs) y cubre el hueco de Ronda Rápida, que no tenía ninguna.
- `Escenario` (nuevo): `pieza` y `cartelTexto` compartidos; ambos escenarios dejan de duplicar helpers y colores.
- Revisión: los cuatro postes medían 8,8 y atravesaban la lona (a su altura el toldo baja a ~7,24) → 7,2; verificado en vivo y en el artefacto final.

**Evidencia:** auditoría `ReadVoxels` en 10 semillas con el techo de la cinta a 0,49–0,50 studs sobre el terreno y 0 muestras < 0,2; `[Stage] etapa 0: 4846 studs, 18 checkpoints, tienda ok, meta ok`; dos rondas rápidas con `[RondaRapida] camino con semilla … tienda ok` (280 y 309 studs); capturas de ventana real en ambos modos con cartel, faroles y prompt «ABRIR TIENDA» que abre `TiendaUI`; artefacto final reconstruido y jugado (tienda de 63 piezas, 4 postes de 7,2); consola limpia (solo DataStore en memoria y el asset 203785492 de siempre); los 5 archivos compilan y `rojo build` limpio.

### Paneles en primera persona (2026-10-29 · `74047e9`)

Pedido del usuario: «si entras al menú de la tienda en primera persona se queda bugueado porque no te deja menear el ratón y no te puedes salir».

- Causa: `CameraMode = LockFirstPerson` hace que el motor reimponga `MouseBehavior = LockCenter` cada frame; ningún mecanismo de modal (ni `GuiButton.Modal` ni un `MouseBehavior = Default` puntual) lo libera.
- `MenuCamara` (nuevo, cliente): cada ScreenGui bloqueante lo engancha con `MenuCamara.Vincular(gui)`; mantiene el atributo local `MenusAbiertos` con ±1 por panel (con `math.max` para no bajar de 0), así los paneles anidados no se pisan.
- `CameraController`: con cualquier panel abierto y primera persona activa sale a `Classic` y fuerza `CameraMinZoomDistance = 8` (con el zoom 0,5 actual, Classic seguiría en primera persona), destruye el viewmodel y, al cerrar el último panel, restaura el zoom guardado y el modo elegido. El respawn reaplica lo mismo vía `CurrentCamera`.
- Enganchados: TiendaUI, ReanimarPersonalUI, FinScreen, MenuInicio, LobbyUI, MenuAjustes, CustomizationUI y RankingAmigosUI. El resto de ScreenGui son HUD no bloqueante.

**Evidencia:** en 1.ª persona (`camara=LockFirstPerson mouse=LockCenter dist=0.51`) abrir la tienda deja `menus=1 camara=Classic mouse=Default dist=8.51`; clic real en VOLVER → `tienda=false menus=0 camara=LockFirstPerson mouse=LockCenter`; en tercera persona abrir/cerrar no toca cámara ni zoom (`Classic`, `0.50/400.00`) y los paneles anidados cuentan bien (`menus=2→3→2`); al volver al lobby `menus=0` con solo HUD activo; consola sin errores.

### Fase 11 · L0: esquema v2 y resultados por clave (2026-10-30)

- **E45 · `DataService` v2:** clave `HUMM_Jugador_v2` con `schema = 2` y los campos del plan §3 (`tutorialVisto`, `estadisticas`, `misiones`, `racha`, `xp`, `cosmeticos`, `bienvenidaComprada`, `ultimaPartida`, `ajustes`). Migración pura e idempotente desde `HUMM_Jugador_v1` **solo si v2 no existe**, con respaldo previo en `u_<UserId>_respaldo_v1` (nunca pisa un respaldo anterior). El autoguardado de 60 s escribe **solo los campos sucios** con `UpdateAsync`; salida y `BindToClose` escriben el perfil completo. Si una lectura falla, `sinPersistir` bloquea toda escritura de la sesión para no pisar lo guardado; `cargando` evita cargas duplicadas entre `PlayerAdded` y el barrido de arranque.
- **Revisión previa al commit:** la fusión de la caché aplicaba los defaults del esquema **antes** de lo cargado, así que un perfil guardado habría perdido `xp`, `estadisticas`, `misiones` y `ajustes` en cada entrada. Corregido: primero lo escrito por la sesión, después lo guardado y al final los defaults solo para huecos; seam `_ProbarFusion` para probarlo.
- **E44 · resultados por clave:** `CompraResult`, `BebidaResult`, `RopaResult`, `ReanimarResult` y `RobuxResult` envían `{ ok, clave, params? }` en vez de frases en español. `Localization.L(clave, params)` aplica `string.format`; 14 claves nuevas con paridad ES/EN; `MonetizacionConfig.AvisoNoPublicadoClave`; `TiendaUI`, `CustomizationUI` y `ReanimarPersonalUI` traducen también los rechazos.

**Evidencia:** `QATestDatos` (nuevo módulo Studio-only, no lo arranca Main) → `[QA-DATOS] OK migracion=v1 idempotente=true fusion=defaults<guardado<sesion`; `[QA-E45] schema=2 faltan={} pinas=170 comprados=2`; `_ProbarMigracion` → `schema=2 pinas=7 idempotente=true`; `_ProbarFusion` → `xp=42 partidas=3 idioma=en tutorialPorDefecto=false sesionManda=170 sesionNoPisaXp=42`; E44 en EN: «Not enough Pinecones», «Available when the game is published», «Invalid design», «You're not down», «Wool beanie», «Equipped», «Green shirt», «Unknown item»; en ES: «Piñas insuficientes», «Bebida energética»; `Sin reanimaciones ni 100 Piñas` / `No revives or 100 Pinecones` con `faltanEN=0 faltanES=0`; playtest de arranque con consola limpia (solo DataStore en memoria y asset 203785492) y `rojo build` limpio. No probado en Studio: migración/respaldo/autoguardado reales y rejoin (QA-60/61/62, requieren place publicado).

### Fase 11 · L0: estamina autoritativa (2026-10-30)

- **E43 · `EstaminaService` (nuevo, servidor):** lleva por jugador `valor`, intención de sprint y bloqueo; simula a `GameConfig.Estamina.Ritmo` (10 Hz) drenaje × `Cansancio` (Botas ligeras), regeneración y `WalkSpeed` (16/24). Publica `EstaminaEstado { estamina, max, esprintando, bloqueado }` solo cuando cambia. El remoto `Sprint` (boolean) sustituye al cálculo local del cliente; valida tipo y limita frecuencia a 20 ms (idempotente, no se pierden sueltas humanas).
- **Cliente:** `Estamina.client.lua` ya no toca `WalkSpeed` ni simula drenaje; pide sprint con `Sprint`, pinta la barra con `EstaminaEstado` y mantiene el rótulo de bebidas. `TiendaService` repone +25 (`GameConfig.Estamina.Bebida`) al beber. Al vaciarse, el servidor suelta la intención: hay que volver a pulsar tras recuperar el umbral (antes el cliente reanudaba solo con la tecla mantenida).
- **Interacción con caído:** mientras `PlatformStand` o `EstaCaido`, el bucle no escribe `WalkSpeed` ni drena/regenera; al revivir vuelve a 16 y, si la intención sigue activa, a 24.
- **Riesgo residual:** la física del personaje sigue siendo del cliente; un exploit puede fijar su propia `WalkSpeed` local. Mitigación vigente: `MatchService` limita el progreso de ruta a 32 studs/s (sprint real 24). Documentado en la cabecera de `EstaminaService`.

**Evidencia (MCP, 1 jugador):** consola `[Estamina] activo (servidor autoritativo)`; sprint real con Shift (`user_keyboard_input`): `[QA-E43]` 100→97,7→…→5,0 con `ws=24`, y al vaciarse `est=3.5 sprint=false bloq=true ws=16`; regenerado a `11,5` con `bloq=false`; cliente `ws=16 enJuego=false barra=1.00`. Segundo pase: caído `est=56.3` congelada 3 s y `ws=0 ps=true`; reanimado `ws=16` y regeneración 56,3→84,1; bebida por Q → `[Tienda] ... bebió una bebida (2 restantes)`, `bebidas=2` y barra a 100 en el cliente. Arranque limpio (solo DataStore en memoria y asset 203785492) y `rojo build` limpio. No probado: dos clientes simultáneos (el MCP solo lanza Play de 1 jugador; queda en E2) ni una partida real iniciada por `MatchService` (la prueba fijó `EnJuego` desde el script QA; resuelto después con E49).

### Fase 11 · L0: telemetría ampliada (2026-10-30)

- **E46 · eventos nuevos:** `TiendaAbierta`, `TiendaPestanaPinas` y `TiendaPestanaRobux` (cliente → remoto `TelemetriaUI`, con lista blanca `TelemetriaConfig.EventosUI` y límite de 1 cada 0,25 s por jugador), `DatosFallo` (`DataService.AlFallar`, cuando la lectura del perfil agota reintentos y la sesión no persistirá) y el cierre por modo.
- **Fin por modo:** `MatchService.AlTerminar` pasa un tercer argumento `modoActual`; `TelemetriaService` emite `PartidaFinHistoria` o `PartidaFinRapida` y deja `PartidaFin` solo como respaldo si faltara el modo. Los demás oyentes (`PinasService`, `AmigosRankingService`) ignoran el argumento extra.
- **Apertura de tienda:** `TiendaUI` escucha `Enabled` (vale el botón del menú y el ProximityPrompt del campamento). Anuncia la pestaña de entrada 0,3 s después: los dos eventos no caben en el mismo frame sin que el límite descarte el segundo.
- **Visibilidad en Studio:** `evento` y `pasoEmbudo` imprimen `[Telemetria] <evento> · <jugador>` solo en Studio; en producción no hay prints nuevos.
- **Cobertura:** `Compra` sigue siendo solo Piñas; las compras de Robux se leen en Monetization (documentado en `docs/launch/metrics.md`).

**Evidencia (MCP, 1 jugador):** consola `[Telemetria] embudo 1 · Lobby · PausiarOG` y `AnalyticsService: LogFunnelStepEvent event fired.`; script QA de servidor → `DatosFallo`, `PartidaFinRapida`, `PartidaFinHistoria` y `PartidaFin` (respaldo), todos con `LogCustomEvent event fired.`; cliente real con `TiendaUI.Enabled = true` → `TiendaAbierta` y `TiendaPestanaPinas`; `FireServer('EventoInventado')` no llegó a consola (lista blanca); `TiendaPestanaRobux` válida emitida. Arranque limpio (solo DataStore en memoria y asset 203785492) y `rojo build` limpio. No probado: clic real en la pestaña ROBUX (el MCP no es fiable con clics por píxeles; la conexión `Activated` es de 5 líneas) ni eventos en Analytics de producción (requiere publicar).

### Fase 11 · L0: humo de partida (2026-10-30)

- **E49 · `QATestHumo` (nuevo, Studio-only):** `Main` no lo arranca; se lanza con un Script temporal (MCP) y comprueba lobby (`esperando`, participante y fuera de partida) → `MatchService.IniciarPartida` (la misma llamada del botón del host y de REINTENTAR) → fase `partida` y `EnJuego=true` → salto a meta → 18 checkpoints cobrados y `Terminado=true` → fase `resultados` → reintento con `recargarCaidos` → segundo salto y meta → vuelta automática a `esperando` con `EnJuego=false` y sin partida activa. En un servidor publicado se niega a ejecutar.
- **Seam `MatchService._ProbarAvanzarRuta`:** Studio-only; coloca al jugador a 2 studs de la meta y deja la distancia un stud por detrás del destino. El bucle de 1 Hz sigue validando el tope de 32 studs/s, cobrando checkpoints y cerrando la meta, así que el humo prueba la lógica real en ~2 s en vez de caminar 4.846 studs. Con `RunService:IsStudio()` la ruta no existe en producción.
- **Por qué un script temporal:** `require` dentro de `execute_luau` no comparte la caché con los servicios ya iniciados; un Script creado en runtime sí, y se autodestruye al terminar.

**Evidencia (MCP, 1 jugador):** una llamada `execute_luau` (Server) creó `QARunE49` → `[QA-HUMO] OK lobby -> partida -> meta (36 checkpoints) -> resultados -> reintento -> lobby`; en consola, `[Lobby] fase partida` ×2, `[Match] inicio modo historia con 1 jugadores` ×2, `[Match] checkpoint 1..18` ×2, `[Match] meta alcanzada` ×2, `[Lobby] resultados: vuelta al lobby en 12 s` ×2, `[Match] vuelta al lobby` y `[Lobby] vuelta al lobby con 1 jugadores`; los eventos de E46 (`PartidaInicio`, `Checkpoint`, `PartidaFinHistoria`, embudo 4) se emitieron en ambos pases. **Repetibilidad:** una segunda llamada en la misma sesión repitió el recorrido con otro `[QA-HUMO] OK` (36 checkpoints). Al terminar, `QARunE49=nil`, `EnJuego=false`, vida 100 y el jugador de vuelta en el spawn del lobby; entre pases, la vuelta al lobby recargó el personaje y `CustomizationService` reintentó la apariencia (2 avisos `ApplyDescription ... no HumanoidRootPart` y aplicación correcta, comportamiento previo a E49). Arranque y cierre sin errores rojos y `rojo build` limpio. Queda resuelta la salvedad de E43: la partida ya se probó arrancada por `MatchService`. No cubre dos clientes (QA-65), que sigue en E2.

### Fase 11 · L1: confirmación de compra (2026-10-30)

- **C25 · diálogo en `TiendaUI`:** toda compra de la pestaña PIÑAS que no sea un re-uso pasa por un modal con nombre del item, precio del siguiente nivel (mejoras) o precio base, y el saldo actual. CANCELAR solo oculta el velo; COMPRAR cierra el diálogo y lanza la petición de siempre, así que el servidor sigue siendo quien valida saldo, límite de 1 compra/s y propiedad. Re-equipar un cosmético ya comprado sigue siendo un clic directo sin diálogo. El diálogo se cierra también al cerrar la tienda (`Enabled=false`), para que no quede armado en la siguiente apertura; si el saldo cambia con el diálogo abierto (evento `Pinas`), se repinta. La pestaña ROBUX no cambia: su compra ya abre el prompt nativo.
- **Revisión apple-design:** velo al 45 % y diálogo centrado con título, item, precio en amarillo y saldo; CANCELAR secundario a la izquierda y COMPRAR primario a la derecha, con 56 px de alto para que la escala mínima 0,8 deje ≥ 44 px de objetivo táctil (el borrador usaba 48 px y llegaba a 33,6 px a 0,7).
- **Clave nueva:** `confirmar_compra` en ES/EN.

**Evidencia (MCP, 1 jugador, clics reales con `user_mouse_input`):** tienda abierta con saldo 200 → COMPRAR una camiseta abre el modal con `Camiseta verde · 20 Piñas · Piñas: 200`; CANCELAR lo cierra y el saldo sigue en 200; repetir y CONFIRMAR deja `Piñas: 180`, el botón pasa a EQUIPAR y la consola registra una sola `[Tienda] PausiarOG compró Camiseta verde (20 Piñas)`; pulsar EQUIPAR no abre diálogo ni cobra (sigue 180); en la bebida, doble clic seguido en CONFIRMAR deja `Piñas: 160` y `Bebidas: 1/5` (un solo cobro); cerrar la tienda con el modal abierto y reabrirla lo deja oculto (`antes=true trasReabrir=false`); consola sin errores nuevos (solo el aviso previo del asset 203785492) y `rojo build` limpio.

### Fase 11 · L1: reflujo al 140 % (2026-10-30)

- **Criterio:** a `escalaTexto = 140` ningún rótulo propio se corta ni se solapa, y ningún control se sale de su panel. La escala sigue recortando al mayor tamaño que cabe (nunca por debajo del base), así que la auditoría cuenta «topes»: etiquetas que no llegan a `round(base × 1,4)`.
- **D34 · inventario y arreglos:** `HudRanking` pasa a 310×164 con filas de 26/30, nombre de 152 px y puntos de 106; `LobbyUI` sube los botones de modo a 210×44 y reequilibra la fila (nombre 260, HOST en x=290, ESPERANDO 148 de ancho) para que quepan HOST y el estado; `NotaRanuras` (personalización) se envuelve a dos líneas en 320×46; patrones y pegatinas pasan a 100×44 con paso 104 desde x=22, alineados con la última muestra de color (538); las tarjetas ROBUX crecen a 128 px de alto con título de dos líneas, precio en y=56 y botón en y=80; la camiseta de Piñas gana 16 px de nombre (de −56 a −40).
- **Tipografía con una sola fuente de verdad:** `Hud` ya no cambia `TextSize` al caer/levantarse (el estado se comunica con color), `ReanimarPersonalUI` fija el tamaño antes del texto para que el reajuste de escala mande también en Modo Puro, y `Accesibilidad` reengancha el ajuste en cuanto llega texto nuevo (`Text` cambiado), con un atajo que no reescribe `TextSize` si ya cumple. Etiquetas nuevas se escalan solas al añadirse, como antes.
- **Revisión apple-design (5 hallazgos):** la fila de 22 px recortaba «(tú)» en el ranking; ESPERANDO no cabía en 112 px; la nota de ranuras se truncaba; «Montaña» y «Huella» se salían del panel (el botón quedaba cortado por el borde); el título ROBUX de 39 px chocaba con el precio al 140 %. Todos resueltos en el propio lote.

**Evidencia (MCP, 1 jugador):** auditoría Client sobre 300 rótulos a 140 % → 2 topes de 1 px sin recorte visible (`Camiseta amarilla` 23/24, limitada por el cuadro de color, y `Montaña` 24/25); el resto al objetivo; `HudRanking`, `LobbyUI`, `Personalizacion` y `Hud` sin topes. Prueba dinámica: etiqueta creada en runtime → 22 px con «Ok» y 16 px (base) con una frase larga, sin desbordar. Solapes: ninguno entre textos propios (solo el billboard de `ProximityPrompts` de Roblox); controles fuera de panel: ninguno. Capturas `D34_140_menu`, `D34_140_lobby`, `D34_140_ajustes`, `D34_140_tienda_pinas`, `D34_140_tienda_robux`, `D34_140_personalizacion3`, `D34_140_ropa_fix` y `D34_140_hud_partida`. Consola limpia (DataStore en memoria, pases sin publicar, asset 203785492 y chat legacy) y `rojo build` limpio. **No probado:** emulación de dispositivo en esta pasada (capturas de la ventana de Studio a 1307×600); la validación en móvil real sigue en QA-47.

### Fase 11 · L1: host y cierre de servidor (2026-10-30)

- **A5 · herencia de host:** el servidor ya elige host por `participantes[1]` y `publicar()` lo reemite al irse alguien, así que no hizo falta tocar `LobbyService`. `LobbyUI` guarda el host anterior y, cuando el estado pasa a otro nombre y `propio.host == true`, muestra 6 s «Ahora eres el host» en la franja de mensajes; el resto ve la etiqueta HOST moverse de fila. Clave nueva `ahora_host` ES/EN.
- **A7 · cierre de servidor:** `CierreService` (servidor) crea `ServidorCerrando`, registra `game:BindToClose` y, al apagarse, avisa `{ segundos = 5 }` y espera ese margen; `DataService` sigue volcando perfiles en su propio `BindToClose` en paralelo. `CierreServidor` (cliente) pinta velo al 45 %, panel 360×176 centrado, título localizado y cuenta atrás 5→0; `UIScale` 0,8–1 en pantallas pequeñas, velo con `IgnoreGuiInset` y tipografía sujeta a la escala global (a 140 % el título ocupa dos líneas y cabe).
- **Mayúsculas:** `String.upper` de Luau no convierte «á» («ESTá»), así que el título se guarda ya en mayúsculas en Strings (ES/EN) y no se aplica `:upper()`.

**Evidencia (MCP, 1 jugador):** arranque limpio con `[Cierre] servicio listo (5 s de aviso)` y `[Cierre] aviso de apagado listo`; Script temporal que `require`s el módulo cacheado → `[Cierre] servidor cerrándose: aviso de 5 s` y `Avisar -> true`; captura `A7_final` (ES, cuenta en 1) con el velo cubriendo también la franja superior; remoto reemitido → lecturas del rótulo 3 y 0 (cuenta atrás real); EN «THE SERVER IS SHUTTING DOWN» y vuelta a ES; a 140 % sin recortes. A5 con dos estados sintéticos de `LobbyEstado` («OtroJugador» → host real) → «Ahora eres el host» y «You are the host now». **No probado:** herencia con dos cuentas reales (el MCP juega con un cliente; sigue en QA-65) ni el guardado real al apagar (Studio no ejecuta `BindToClose` y DataStore está en memoria).

### Fase 11 · L2: onboarding, carga y resultados (2026-10-30)

- **A1 · tutorial:** `TutorialUI` pinta una tarjeta de 480×268 (DisplayOrder 56, escala 0,7–1 con safe area) con 4 pasos de `TutorialConfig` (mover, saltar, linterna, caída y aviso de El Doble); SIGUIENTE avanza, SALTAR o el último paso envían `TutorialVisto` una sola vez. `TutorialService` persiste `tutorialVisto` con límite de 2 s y emite `TutorialEstado` al cargar el perfil, con repetición a los 2 s por la carrera con el cliente; la tarjeta solo aparece con fase `esperando`, lobby abierto y `EnJuego` falso.
- **A2 · carga:** `PantallaCarga` (DisplayOrder 240) cubre la pantalla con «HEADS UP! / MOUNTAIN MAYHEM», un consejo de `CargaConfig` rotando cada 2,2 s y «CARGANDO…» pulsante; se oculta con `CharacterAdded` + 2 s y tiene tope de 8 s, así que no puede tapar el lobby.
- **A3 · invitar:** `LobbyUI` añade INVITAR (180×44) entre VOLVER y RANKING; `SocialService:PromptGameInvite` va en `pcall` y, si falla, muestra «No se pudo abrir la invitación» 6 s en la franja de mensajes. Clave ES/EN `invitar` / `invitar_no_disponible`.
- **A4 · modos:** `LobbyConfig` gana `descripcion` por modo y `LobbyUI` pinta «Ruta completa con 18 checkpoints.» o «Camino aleatorio corto, sin checkpoints.» solo en fase `esperando` (la cuenta atrás es fase `cuenta`, sin solape); se refresca al cambiar de idioma y no se ve durante la partida.
- **A8 · resultados:** `MatchService` cuenta las reanimaciones hechas por el jugador dentro de la partida (evento `Reanimado`, sin autorreanimaciones y solo con la partida viva) y calcula `mejorDelEquipo()` como la máxima distancia de los participantes; `FinPartida` lleva `reanimaciones` y `mejorEquipo` en victoria y derrota. `FinScreen` añade 3 filas (Piñas ganadas, Reanimaciones, Mejor del equipo), crece a 432/560 px y recalcula la escala al cambiar de variante (suelo 0,6: la victoria mide 336 px en un A06 de 338).
- **Piñas de la partida:** `FinScreen` acumula el campo `ganadas` del remoto `Pinas` (caminar + bonus) en `pinasPartida`; se reinicia al arrancar una partida y al pulsar REINTENTAR. El ganador no respawnea y `EnJuego` no cambia de valor en el servidor, así que el reintento cierra el velo a mano (`gui.Enabled = false`).
- **Revisión apple-design (A1/A2/A8):** el botón primario del tutorial pasa a 20 px en negrita (crema sobre verde 3,44:1 supera el 3:1 de texto grande; a 16 px no llegaba a 4,5:1); tarjeta y textos caben en 705×338; el panel de victoria crecía a 560 px sin adaptar la escala (SEGUIR quedaba fuera en A06) y se corrigió con la escala por altura; el velo de carga usa `IgnoreGuiInset` y contrastes 8,53:1 (crema/madera) y 8,83:1 (amarillo/madera).

**Evidencia (MCP, 1 jugador):** partida real con `QATestHumo` (no sintética) → `[QARun] fin modo=historia victoria=true checkpoint=18 distancia=4846 reanimaciones=0 mejorEquipo=4846 puntos=180` y segunda pasada `puntos=360`; el panel pintó las 8 filas. El reintento real destapó un fallo: las Piñas se sumaban entre partidas (467 = 125 + 100 + 242) porque `EnJuego` no cambia de valor en el servidor; corregido y verificado con paneles sintéticos (125 → REINTENTAR → oculto + REANUDANDO… → 0). Carga: `[Carga] pantalla activa` y `cargaVisible=false` tras personaje + 2 s con el lobby detrás. Tutorial: tarjeta con «ASÍ SE JUEGA», SIGUIENTE/SALTAR a 20 px y `[Tutorial] tutorialVisto guardado para PausiarOG` al saltar. A4 con clics reales: RONDA RÁPIDA → «Camino aleatorio corto, sin checkpoints.», vuelta a HISTORIA → «Ruta completa con 18 checkpoints.». A3: clic INVITAR → `[QA] clic BotonInvitar` y se abre el diálogo nativo «Invitar amistades» (captura `L2_lobby_A3_A4`). Consola limpia salvo avisos conocidos (DataStore en memoria, pases sin publicar, asset 203785492 y chat legacy) y `rojo build` limpio. **No probado:** persistencia del tutorial tras rejoin (Studio usa DataStore en memoria), A8 con dos clientes (QA-65: `reanimaciones` reales y `mejorEquipo` en co-op), la rama de error de INVITAR (`PromptGameInvite` devuelve ok en Studio) ni móvil físico (QA-47).

---

## 5. Lo que falta

### A. Cierre formal de la fase 9 — hecho (2026-10-29)

- `/ponytail-audit`: sin «must fix» abiertos; los hallazgos de servidor y cliente se corrigieron en `0cb38bc` y `02537b7`. Los abiertos pasan a la fase 10.
- `/ponytail-debt`: 11 marcadores `shortcut:`, todos con disparador; tabla C actualizada.
- `graphify update .`: 859 nodos, 1509 aristas, 42 comunidades (AST de código; los docs conservan sus nodos previos, sin reextracción semántica por falta de `GEMINI_API_KEY`).
- Fila de cierre en `docs/skill-log.md` con la evidencia de `QATestVelocidad`, `QATestDoble` y `QATestBeber`.

### B. Verificación de la fase 10 (estado real)

Hecho en Studio:

- **Hitch de teselas:** rampa sintética de distancia a 500 studs/s → frame máximo del servidor **115 ms**, típico 54–62 ms, 6–7 teselas/s. Dentro del presupuesto de 150 ms; no hizo falta bajar `TilesPorTick` ni mover la generación de hilo.
- **3 clientes en la misma sesión** (Studio «Servidor y clientes»): los tres entran al lobby, listo, cuenta atrás y partida con HUD por jugador (Distancia, Tiempo, Sanos, Puntos, Piñas, Bebidas) y ranking con 3 jugadores a 0. Sin errores en consola. Los checkpoints, Piñas en vivo, rescate de El Doble y reanimación entre clientes siguen sin validar (hace falta playtest real).
- **UI en móvil simulado:** Samsung Galaxy A06 (705×338) e iPhone 17 Pro (750×381). Menú, lobby, ajustes y personalización caben o se desplazan con `ScrollingFrame`; el botón AMIGOS se movió por encima del salto (antes lo tapaba: 586–726×251–299 contra 655–725×233–303) y ya no se solapa. Menú de inicio baja a escala 0,7 en pantallas cortas y muestra SALIR sin scroll.

Falta (bloqueado por hardware/personas/publicación):

- **4–8 jugadores simultáneos** y partida completa de 8 por Historia.
- **Móvil real** y **FPS ≥30** en gama media (el Device Simulator no mide rendimiento real).
- **Mando** y cámara en 1.ª persona.
- **Modo Puro** en una partida real: el filtro del ranking está implementado y verificado en código, no en producción.
- **DataStore, ranking de amigos y telemetría** reales tras publicar.

### C. Deuda registrada (marcadores `shortcut:`)

3 marcadores, todos con disparador de revisión:

| Archivo | Qué queda pendiente |
| --- | --- |
| `src/client/Accesibilidad.client.lua` | 140 % no refluye alturas fijas; algunos rótulos se recortan |
| `src/server/AmigosRankingService.lua` | Una consulta lee hasta 50 claves por jugador; vigilar con grupos grandes |
| `src/client/AnimacionBeber.client.lua` | Animación solo local (otros jugadores no ven la lata) y omitida en rigs R6/Motor6D; migrar a una animación subida si la co-op lo pide |

Cerrada en la fase 10: los paneles de LobbyUI, CustomizationUI, MenuInicio, MenuAjustes y TiendaUI ya escalan con suelo y scroll vertical donde hacía falta; el aviso de ReanimarPersonalUI ya está documentado y el botón AMIGOS esquiva el salto táctil.

Hallazgos de la fase 7 y su estado:
- `ProcessReceipt` **no comprueba `Activo`**: decisión consciente. Un recibo real debe entregarse aunque el catálogo esté desactivado; para retirar un producto, no reutilizar su ID.
- El recibo se marca **antes** del guardado asíncrono: riesgo residual solo si el servidor cae entre la caché y el DataStore; el rollback cubre el fallo de entrega.
- 2 de 5 pases están desactivados a propósito (`botas_agarre`, `club_montanero`): la v1 no tiene sistema de adherencia y la API de suscripciones no está validada. `mochila_pro`, `ranuras_ropa` y `linterna_pro` sí tienen efecto implementado.
- Sin DataStore, el ranking de amigos cae a «no disponible» (en Studio es lo normal).
- Modo Puro ya separa los récords del ranking de amigos (`AmigosRankingService`); falta la prueba con una partida real de 8.

### D. Bloqueado por el usuario

Todo el detalle accionable, con pasos y verificaciones esperadas, está en **[`docs/pendiente-usuario.md`](pendiente-usuario.md)**. Resumen:

- Publicar el juego y activar **API Services**.
- Crear en el Creator Dashboard los **IDs de 3 pases vendibles y 3 productos**, rellenarlos en `MonetizacionConfig` y poner `Activo = true` (las Botas y el Club siguen fuera de la v1).
- Probar una **compra real** y comprobar el guardado tras rejoin.
- **Música definitiva**, **iconos/thumbnails** y ficha del juego.
- Decidir **cuenta personal o de grupo** y si se usan los modelos CC-BY de `assets-source/`.
- Playtest real de **8 jugadores**, **móvil físico**, **mando** y **Modo Puro** en producción.

---

## 6. Mapa rápido del código

```
src/
  server/   Main.server.lua (arranque), DataService, QATestDatos (Studio-only), LobbyService, MatchService,
            StageService, TerrenoService, HazardService, MonsterService, ChatMimicService,
            PlayerStateService, EstaminaService, PinasService, PuntosService, TiendaService, RopaService,
            CustomizationService, AccesoriosService, MonetizacionService,
            RankingService, AmigosRankingService, RondaRapidaService, TelemetriaService
  client/   MenuInicio, LobbyUI, Hud, HudPuntos, HudPinas, HudRanking, FinScreen,
            CameraController, Estamina, Linterna, AudioService, Subtitulos, Acciones,
            Accesibilidad, MenuAjustes, TiendaUI, ReanimarPersonalUI, AnimacionBeber,
            CustomizationUI, RankingAmigosUI, ChatMimicView
  shared/   Remotes.lua, Ruta.lua, Settings.lua, RopaArte.lua, Localization/, Util/, Types/
  shared/Config/  GameConfig, TerrenoConfig, LobbyConfig, TiendaConfig, AudioConfig,
                  MonetizacionConfig, RankingAmigosConfig, RopaConfig, TelemetriaConfig
```

---

## 7. Reglas que no se pueden romper

- Servidor autoritativo (distancia, daño, caída, compras, recompensas); remotes tipados, validados y con límite de frecuencia.
- Todo por datos en `src/shared/Config`; nada de valores mágicos en la lógica.
- Texto de jugadores siempre por `TextService:FilterStringAsync`; nada de compras aleatorias de pago; `PolicyService` en la tienda.
- Una fase a la vez y con evidencia de playtest (MCP) antes de decir «hecho».
- Cada tarea: fila en `docs/skill-log.md`. Cada commit: `/ponytail-review` + `/caveman-commit`.
- **Una sola sesión de Studio abierta**: cerrar la anterior antes de abrir un build nuevo.

---

## 8. Siguiente paso sugerido

1. **Fase 10: cerrar lo que depende de ti** — sigue `docs/pendiente-usuario.md`: publicar + API Services, IDs de monetización, compra real, playtest de 8, móvil físico, mando y Modo Puro en producción. El QA de Studio (hitch, 3 clientes, UI A06/iPhone) ya está hecho y registrado.
2. **Cerrar la fase 10** cuando A–E del documento estén verdes: `/ponytail-audit`, `/ponytail-debt`, `graphify update .` y fila en `docs/skill-log.md`.
3. Cuando haya datos de publicación (IDs + `Activo=true`), hacer el smoke de soft launch de `docs/launch/soft-launch.md`.
4. **Fase 11 (en curso desde el 2026-10-30):** 47 mejoras antes de publicar en `docs/fase-11-plan.md`, con lotes L0–L11, esquema de datos v2, remotes nuevos y corte de lanzamiento. **L0 cerrado** con E45 (esquema v2), E44 (resultados por clave), E43 (estamina autoritativa), E46 (telemetría de tienda, datos y modo) y E49 (`QATestHumo`). **L1 cerrado** con C25 (confirmación de compra), D34 (reflujo 140 %), A5 (herencia de host con aviso) y A7 (cierre de servidor con cuenta atrás). **L2 cerrado** con A1 (tutorial de 4 pasos), A2 (pantalla de carga con consejos), A3 (invitar), A4 (descripciones de modo) y A8 (resultados con Piñas, reanimaciones y mejor del equipo). **L4 cerrado** con B4 (rotación de 3 semillas curadas, visibles en FinScreen y telemetría `PartidaSemilla`), B5 (récord y delta en vivo en el HUD, aviso al superarlo), B6 (medallas por segundos/1000 studs, meta también en Ronda rápida y `estadisticas.mejorRapida`), B7 (causa árbol/piedra/Doble/vacío en HUD, FinScreen y feed de 3) y B8 (8 frases rápidas con filtro por receptor y rate limit, UI móvil/mando). Sigue **L5** (B3 refugio, B9 cargar caídos, B10 empujón); **L3** (A6 reconexión) queda para después del soft launch según el corte §7. Pendiente de publicación: rejoin del récord (DataStore de Studio en memoria) y umbrales de medalla con tiempos reales. Con E43 cerrado también se puede tocar D36/D41 (ajustes persistentes y pantalla de ajustes nuevos).
