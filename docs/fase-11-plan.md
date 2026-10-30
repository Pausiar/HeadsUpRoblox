# Fase 11 · Mejoras antes de publicar

Fecha: 2026-10-30 · Estado: planificado · Base: `docs/PLAN.md`, `docs/HANDOFF.md`, `docs/pendiente-usuario.md`.

## 0. Alcance cerrado

47 mejoras. Numeración de la lista del 2026-10-30.

| Bloque | Incluido | Fuera |
| --- | --- | --- |
| A. Flujo | 1–8 (todas) | — |
| B. Gameplay | 3–10 y 12–16 | B1 aviso visual, B2 vista de caído, B11 troncos rodantes |
| C. Economía | 25–33 (todas) | — |
| D. Accesibilidad | 34–42 (todas) | — |
| E. Técnico | 43–50 (todas) | — |

Detalle:

- A: tutorial, pantalla de carga, invitar, descripción de modos, transferencia de host, reconexión, aviso de cierre de servidor, resultados con desglose.
- B: refugio, semillas, récord en HUD, medallas de ronda rápida, causa de caída, frases rápidas, arrastrar compañeros, empujón/modo amistoso, niebla, bengala, segundo Doble, reacciones del Doble, tres biomas.
- C: confirmación de compra, misiones diarias, racha, insignias, ventajas en HUD, cosméticos, ranking global, niveles, pack de bienvenida.
- D: reflujo 140 %, primera persona, mando, escala de UI, brújula, avisos visuales de sonido, daltónico, sensibilidad táctil, reducir movimiento.
- E: estamina en servidor, mensajes localizados, DataStore versionado, telemetría, streaming adaptativo, LOD/pooling, prueba de humo, música.

## 1. Reglas de ejecución

- Un lote a la vez. Cada lote: configurar → servidor → cliente → QA en Studio con MCP → `/ponytail-review` → `/caveman-commit` → push → fila en `docs/skill-log.md` y HANDOFF.
- Servidor autoritativo; remotes nuevos tipados, validados y con `RateLimiter`; nada de valores mágicos fuera de `src/shared/Config`.
- Texto de jugadores por `TextService:FilterStringAsync`; `PolicyService` antes de cualquier oferta de pago.
- Todo texto nuevo en ES/EN desde el primer commit (`Localization.Strings`).
- Toda pantalla nueva usa los patrones de `Accesibilidad`, `MenuCamara.Vincular` y safe area móvil.
- Los `ScreenGui` nuevos no se destruyen: `ResetOnSpawn=false` y limpieza por `Enabled`.
- Nada se marca «hecho» sin evidencia de playtest y consola limpia.
- No se añaden assets externos: modelos procedurales con Parts salvo que el usuario aporte IDs/licencias.

## 2. Orden, dependencias y paralelización

Cadena crítica:

1. **Datos y protocolo primero:** E45 (esquema v2) → E44 (mensajes por clave) → E43 (estamina servidor) → E46/E49.
2. **P0 de UX:** C25 (confirmar compra) y D34 (reflujo 140 %) antes de añadir pantallas nuevas.
3. **Flujo:** A5/A7 → A1/A2/A3/A4/A8 → A6 (reconexión, al final por su coste de QA).
4. **Partida:** B4/B5/B6/B7/B8 → B3 (refugio) → B9/B10 → B12–B15.
5. **Mundo:** B16a (zonas de bioma en la ruta actual) y después B16b (tres etapas con transiciones), que reutiliza el refugio de B3.
6. **Economía:** C26/C27/C28 dependen del esquema v2; C30 → C32 (desbloqueos) y C33 (pack).
7. **Controles/accesibilidad:** D34/D37 antes de las pantallas nuevas; D35–D42 después.
8. **Rendimiento:** E47/E48 se miden con B16a construido; E50 depende del audio del usuario.

Dependencias duras:

- E45 antes de A1, B6, C26, C27, C32, C33 (campos persistidos nuevos).
- E44 antes de C25 y de cualquier resultado de tienda/ropa/reanimación.
- E43 antes de tocar D36/D41 y de equilibrar B3.
- B3 antes de B16b.
- B14 antes de B15 (estado por clon).
- B16a antes de E48 (medir con el bosque/bioma final).
- D37 requiere persistir ajustes (ver §3.1) para que la escala no se pierda al rejoin.

Paralelización recomendada (2–4 agentes + coordinador):

- **Stream A (servidor/datos):** E45, E44, E43, E46, E49, A5, A7, A6, A8, B3, B4, B6, B7, B14, B15, C26–C28, C31–C33, E47, E48.
- **Stream B (cliente/UI):** C25, D34, A1–A4, B5, B8, B9 (cliente), B10, C29, C30, D35–D42.
- **Stream C (mundo/audio):** B12, B13 (visual), B16, E50, capturas y matriz de QA.
- El coordinador integra, revisa y commitea por lote; nunca dos agentes en el mismo archivo.

## 3. Datos persistidos (esquema v2)

E45 introduce `schema = 2` en `DataService`. Clave nueva `HUMM_Jugador_v2`, lectura de respaldo de `HUMM_Jugador_v1`, copia de seguridad antes de migrar y escritura solo de campos cambiados.

| Campo | Tipo | Origen |
| --- | --- | --- |
| `schema` | number | DataService |
| `tutorialVisto` | boolean | A1 |
| `estadisticas` | `{partidas, metas, reanimaciones, mejorDistancia, mejorRapida}` | A8, B5, B6, C28, C32 |
| `misiones` | `{dia, progreso, reclamadas}` | C26 |
| `racha` | `{ultimoDia, dias}` | C27 |
| `xp` | number | C32 |
| `cosmeticos` | `{poseidos, equipados}` | C30 |
| `bienvenidaComprada` | boolean | C33 |
| `ultimaPartida` | `{jobId, ts}` | A6 |

No se guarda el nivel: se deriva de `xp` con `ProgresionConfig`.

### 3.1 Ajustes persistentes (prerrequisito de D37/D41)

Hoy `Settings` es solo memoria y se pierde al rejoin. D37 (escala de UI) y D41 (sensibilidad táctil) necesitan persistencia:

- Nuevo remoto `GuardarAjustes` (cliente → servidor, validado) y `AjustesCargados` (servidor → cliente).
- `DataService` guarda la tabla `ajustes` dentro del esquema v2.
- El cliente aplica los ajustes recibidos al arrancar; el servidor no decide valores, solo los almacena.

## 4. Remotes nuevos o modificados

Todos con límite de frecuencia y validación de tipos. Actualizar `src/shared/Remotes.lua` y su comentario.

| Remoto | Dirección | Uso |
| --- | --- | --- |
| `Sprint` | C→S | intención de esprintar; el servidor decide estamina y velocidad (E43) |
| `EstaminaEstado` | S→C | estamina y estado de sprint (E43, D36) |
| `TutorialVisto` / `TutorialEstado` | C→S / S→C | A1 |
| `ChatRapido` / `ChatRapidoMensaje` | C→S / S→C | B8, filtrado por receptor |
| `Cargar` / `CargarEstado` | C→S / S→C | B9 |
| `Empujar` | C→S | B10 |
| `Bengala` / `BengalaResult` | C→S / S→C | B13 |
| `LinternaAim` | C→S | B15, 5 Hz, validado en servidor |
| `Clima` | S→C | B12 |
| `RankingGlobal` / `RankingGlobalDatos` | C→S / S→C | C31 |
| `Misiones` / `ReclamarMision` / `MisionesResult` | S→C / C→S / S→C | C26 |
| `Racha` | S→C | C27 |
| `Progresion` | S→C | C32 |
| `Cosmeticos` / `EquiparCosmetico` | S→C / C→S | C30 |
| `ServidorCerrando` | S→C | A7 |
| `AjustesCargados` / `GuardarAjustes` | S→C / C→S | §3.1 |

E44 cambia los resultados existentes (`CompraResult`, `BebidaResult`, `RopaResult`, `ReanimarResult`, `RobuxResult`) para enviar `clave` + `params` en lugar de `mensaje` en español; el cliente resuelve con `Localization.L`.

## 5. Configs nuevos y ampliados

| Archivo | Cambio |
| --- | --- |
| `GameConfig` | estamina/sprint en servidor, impulso de empujón, tiempos de carga |
| `TerrenoConfig` | semillas curadas de Historia, zonas de bioma, parámetros por zona |
| `LobbyConfig` | descripciones de modo, tiempos de cierre de servidor |
| `TiendaConfig` | bengala, cosméticos de Piñas, precios y stock |
| `MonetizacionConfig` | pack de bienvenida (ID del usuario) |
| `AudioConfig` | música, viento, indicadores de sonido |
| `TutorialConfig` | pasos, textos y orden |
| `MisionesConfig` | 3 misiones diarias, metas y recompensas |
| `ProgresionConfig` | XP por evento y tabla de niveles |
| `CosmeticosConfig` | catálogo procedural, precios, desbloqueos |
| `ClimaConfig` | tipos, duración, frecuencia e intensidad |
| `BengalaConfig` | radio, aturdimiento, duración y stock |
| `RankingGlobalConfig` | top N, periodo, filtros |
| `InsigniasConfig` | IDs de insignias (usuario) |
| `TelemetriaConfig` | eventos nuevos de tienda, datos y modos |

## 6. Lotes

Estimaciones para un agente; con 2–3 en paralelo se solapan.

### L0 · Cimientos y deudas P0 (6–8 días)

**Items:** E45, E44, E43, E46, E49.

- **E45 DataStore v2:** versión, migración, respaldo y `QATestDatos` para simular datos v1. Criterio: un perfil v1 migra sin perder campos y dos cargas seguidas no duplican.
- **E44 mensajes por clave:** resultados de tienda, bebida, ropa, reanimación y Robux. Criterio: en EN no aparece ninguna frase en español; en ES no hay regresión.
- **E43 estamina servidor:** nuevo `EstaminaService` (estado, drenaje, regeneración, `WalkSpeed`), cliente solo pinta y pide sprint. Reutilizar el tope de progreso de `MatchService`; documentar el riesgo residual de física cliente. Criterio: el cliente no puede mantener sprint sin estamina y dos clientes ven el mismo estado.
- **E46 telemetría:** eventos de apertura de tienda, pestaña, compra, fallo de datos y fin de partida por modo. Criterio: eventos visibles en consola/Analytics con `pcall`.
- **E49 humo:** módulo Studio-only `QATestHumo` que recorre lobby → partida → meta → resultados → reintento. Criterio: una llamada MCP imprime `[QA-HUMO] OK` y deja el servidor limpio.

**Archivos:** `DataService`, `Localization/Strings`, `Remotes`, `TiendaService`, `MonetizacionService`, `RopaService`, `Estamina.client`, nuevo `EstaminaService`, `GameConfig`, `TelemetriaService`, `TelemetriaConfig`, `Main.server`, módulo QA.

### L1 · P0 de UX y flujo base (5–7 días)

**Items:** A5, A7, C25, D34.

- **A5 host:** confirmar que el siguiente participante hereda el host en `LobbyService`; aviso localizado en el lobby. Criterio: el host sale y el siguiente puede cambiar modo/iniciar; el resto lo ve.
- **A7 cierre de servidor:** `BindToClose` avisa con `ServidorCerrando`, cuenta atrás de 5 s, cierra la partida y guarda. Criterio: aviso visible y datos guardados (seam en Studio).
- **C25 confirmación de compra:** diálogo dentro de `TiendaUI` con item, precio y saldo; cancelar no cobra, confirmar cobra una vez. Criterio: doble clic no duplica; cancelar no cambia Piñas.
- **D34 reflujo 140 %:** inventario de rótulos recortados; `AutomaticSize`/scroll/alturas mínimas en menú, lobby, ajustes, tienda, personalización y HUD. Criterio: capturas a 140 % en A06/iPhone simulado sin recortes ni solapes.

**Archivos:** `LobbyService`, `LobbyUI`, `Main.server`, `MatchService`, `TiendaUI`, `Accesibilidad`, paneles con alturas fijas.

### L2 · Onboarding y carga (6–9 días)

**Items:** A1, A2, A3, A4, A8.

- **A1 tutorial:** `TutorialUI` + `TutorialConfig`; 4 pasos en el lobby (mover, saltar/sprint, linterna, caída/reanimar y aviso de El Doble), saltable; el servidor persiste `tutorialVisto`. Criterio: cuenta nueva lo ve una vez; tras rejoin no reaparece; no bloquea partida.
- **A2 carga con consejos:** `PantallaCarga` al entrar, consejos rotando hasta personaje listo + 2 s (máximo 8 s). Criterio: no se queda colgada ni tapa el lobby.
- **A3 invitar:** botón en `LobbyUI` con `SocialService:PromptGameInvite` y `pcall`. Criterio: abre el prompt en Studio/cliente publicado.
- **A4 modos:** descripciones de Historia/Rápida en `LobbyConfig` y `LobbyUI`. Criterio: ES/EN y en pantalla móvil.
- **A8 resultados:** `FinPartida` añade reanimaciones, checkpoints, Piñas ganadas y mejor del equipo; `FinScreen` los pinta. Criterio: datos correctos en una partida con 2 clientes.

**Archivos:** nuevos `TutorialUI`/`PantallaCarga`, `TutorialConfig`, `LobbyUI`, `LobbyConfig`, `MatchService`, `PuntosService`, `FinScreen`, `Remotes`, `Strings`.

### L3 · Reconexión (5–8 días; QA completa requiere place publicado)

**Items:** A6.

- **A6a memoria de partida:** al iniciar, el servidor guarda `ultimaPartida {jobId, ts}`; en el menú, si hay una partida reciente (<5 min), botón VOLVER que usa `TeleportService:TeleportToPlaceInstance`.
- **A6b gracia de reconexión:** `LobbyService`/`MatchService` conservan 120 s la plaza de quien se cae; al volver, respawn en su último checkpoint; si la partida terminó, al lobby.
- Validar `jobId` contra el place actual; no exponer servidores ajenos; rate limit del botón.
- Criterio Studio: simulación con seam de `ultimaPartida` y roster de gracia. Criterio real: prueba en place publicado con 2 cuentas (usuario).

**Archivos:** `DataService`, `LobbyService`, `MatchService`, `PlayerStateService`, `MenuInicio`/`LobbyUI`, `Remotes`.

### L4 · Feedback de partida (6–8 días)

**Items:** B4, B5, B6, B7, B8.

- **B4 semillas:** `HistoriaSemillas` curadas; rotación por partida; semilla visible en resultados y telemetría. Criterio: 3 semillas construyen inicio, meta, tienda y refugios válidos.
- **B5 récord en HUD:** `TusDatos`/`Hud` muestran récord y delta en vivo; aviso al superarlo. Criterio: récord correcto tras una partida y rejoin.
- **B6 medallas:** umbrales por longitud en config; medalla en `FinScreen`; mejor tiempo persistido (`estadisticas.mejorRapida`). Criterio: 3 tiempos sintéticos dan oro/plata/bronce.
- **B7 causa de caída:** `PlayerStateService` recibe causa; HUD y `FinScreen` la muestran; feed de las últimas 3 caídas del equipo. Criterio: árbol, piedra, Doble y vacío tienen texto propio.
- **B8 frases rápidas:** 6–8 frases en config; remoto con filtro por receptor y rate limit; UI para móvil/mando. Criterio: llegan filtradas, no se puede spamear y se leen en ES/EN.

**Archivos:** `TerrenoConfig`, `LobbyService`, `MatchService`, `DataService`, `Hud`, `FinScreen`, `PlayerStateService`, `HazardService`, `MonsterService`, `ChatMimicService`/nuevo `ChatRapidoService`, `Remotes`, `Strings`.

### L5 · Cooperación y refugio (8–12 días)

**Items:** B3, B9, B10.

- **B3 refugio:** campamento a mitad de ruta reutilizando `TiendaCampamento`: plaza plana, hoguera, tienda con prompt y checkpoint. `HazardService` no genera peligros a <30 studs. Criterio: se abre la tienda, el checkpoint respawnea ahí y no hay peligros dentro.
- **B9 cargar caídos:** prompt «Cargar» en el caído; 1 portador (2 permitidos), velocidad reducida, soltar con prompt; se cancela al caer, ser raptado o respawnear; no se reanima mientras se carga. Criterio: 2 clientes, cruzar 50 studs y soltar sin desincronizar.
- **B10 empujón:** impulso suave validado en servidor, sin derribo, enfriamiento 3 s, desactivado en caído/portador/fuera de partida; ajuste «modo amistoso» que lo desactiva. Criterio: no mueve a nadie fuera de partida; el ajuste persiste en la sesión.

**Archivos:** `StageService`, `TiendaCampamento`, `Escenario`, `TerrenoService`, `HazardService`, `MatchService`, `PlayerStateService`, nuevo `CargarService`, `Remotes`, `Settings`, `MenuAjustes`, prompts.

### L6 · El Doble y clima (8–11 días)

**Items:** B12, B13, B14, B15.

- **B12 niebla/ventisca:** `ClimaService` programa eventos de 20–30 s cada 60–120 s; el cliente tweenea `Lighting` y añade partículas si `reducirEfectos=false`; sin daño. Criterio: 3 eventos en una partida y consola limpia.
- **B13 bengala:** item de tienda con stock; al usarlo, el servidor crea luz/partículas y aturde al Doble 4 s dentro del radio; duración 20 s. Criterio: el clon se detiene y no rapta durante el aturdimiento.
- **B14 segundo Doble:** refactor de `MonsterService` a lista de clones (1 con 2–5 jugadores, 2 con 6–8); víctimas distintas; máximo de raptos por partida. Criterio: 3 clientes + seam de 8, dos clones activos y sin doble rapto a la misma víctima.
- **B15 reacciones:** árboles/piedras pueden aturdir al clon; la linterna apuntada (validada en servidor a 5 Hz) lo hace retroceder o cubrirse; no muere. Criterio: haz a 25 studs lo ahuyenta; un árbol lo detiene.

**Archivos:** `MonsterService`, `HazardService`, nuevo `ClimaService`, `Linterna.client`, `TiendaService`, `TiendaConfig`, `AudioConfig`, `ClimaConfig`, `BengalaConfig`, `Remotes`.

### L7 · Biomas (10–16 días)

**Items:** B16.

- **B16a zonas de bioma (prioridad):** la ruta actual se divide en 3 tramos (verde, oscuro, gigante) con parámetros de árboles, niebla, ambiente y sonido por zona; transición suave al cruzar. Criterio: capturas de las 3 zonas, mismo rendimiento y sin costuras visibles.
- **B16b tres etapas:** rutas separadas por refugio de B3, con checkpoint y tienda por etapa y meta final. Criterio: partida completa de las 3 etapas con 2 clientes; si el tiempo aprieta, B16b pasa a actualización posterior al soft launch.
- Medir teselas y FPS con E47/E48 antes de dar por cerrada la fase.

**Archivos:** `TerrenoConfig`, `TerrenoService`, `StageService`, `MatchService`, `TiendaCampamento`, `RondaRapidaService` (sin regresión), `Lighting`, `AudioConfig`.

### L8 · Economía y progresión (12–18 días)

**Items:** C26, C27, C28, C29, C30, C31, C32, C33.

- **C26 misiones diarias:** 3 misiones por día UTC (caminar, reanimar, llegar, beber, checkpoints), progreso desde eventos del servidor, reclamar con remoto limitado, recompensa en Piñas, panel en lobby/menú. Criterio: progreso correcto en 2 clientes, reclamo único y reset diario simulado.
- **C27 racha:** recompensa diaria 5–7 días, día UTC, sin castigo por saltarse uno; persistida. Criterio: simulación de 8 días con hueco.
- **C28 insignias:** `BadgeService` con IDs de `InsigniasConfig` (los crea el usuario); meta, primer rescate, 10 partidas, partida de 8; dedupe del propio servicio. Criterio: se concede una vez y aparece el toast.
- **C29 ventajas en HUD:** chip de Piñas x2 y stock de reanimaciones desde `PaseEstado`; oculto si no hay. Criterio: aparece/desaparece con el estado y cabe en móvil.
- **C30 cosméticos:** 6–10 piezas procedurales (gorros/mochilas/estelas) con precio en Piñas, compra y equipado persistidos; estelas solo cliente. Criterio: compra, equipa, rejoin y se ve; Modo Puro no las bloquea.
- **C31 ranking global:** OrderedDataStore mensual, top 50, solo Modo Puro, pestaña junto a amigos, rate limit. Criterio: datos sembrados y actualización tras una meta.
- **C32 niveles:** XP por distancia, reanimar, checkpoint y meta; tabla en config; desbloqueos cosméticos y Piñas; UI en lobby/resultados. Criterio: subir de nivel con datos sintéticos y no duplicar recompensa.
- **C33 pack de bienvenida:** producto de Developer Product con Piñas + cosmético, una compra por jugador, recibo revalidado, `PolicyService`; ID del usuario. Criterio: seam de recibo entrega una vez y rejoin no repite.

**Archivos:** nuevos `MisionesService`, `ProgresionService` (o extensión de `PuntosService`), `InsigniasService`, `RankingGlobalService`; `AccesoriosService`/`RopaService`; `MonetizacionService`, `TiendaService`; `DataService`; `Hud`, `LobbyUI`, `MenuInicio`, `TiendaUI`, `CustomizationUI`, `FinScreen`; configs nuevos.

### L9 · Accesibilidad y controles (8–12 días)

**Items:** D35, D36, D37, D38, D39, D40, D41, D42.

- **D35 primera persona:** manos/viewmodel, linterna alineada, ropa que no atraviese, lata visible al beber; QA visual en 1.ª persona. Criterio: capturas en partida y con tienda abierta.
- **D36 mando:** bindings completos (sprint L3, linterna, beber, reanimar, cámara R3) con `ContextActionService`; navegación de menús con `GuiService`. Criterio: partida corta sin teclado; prueba física del usuario.
- **D37 escala de UI:** ajuste 80–120 % aplicado con `UIScale` por ScreenGui, persistido (§3.1). Criterio: 3 tamaños en A06/iPhone sin recortes.
- **D38 brújula:** dirección al próximo checkpoint, meta y tienda; nunca al Doble; datos desde el servidor en `HudEstado`. Criterio: gira con la cámara y no revela al clon.
- **D39 avisos visuales de sonido:** iconos para checkpoint, reanimar, susto y pasos del Doble; ajuste propio. Criterio: se ven sin audio y no tapan el HUD.
- **D40 daltónico/alto contraste:** paleta y formas alternativas para peligros y HUD; ajuste persistido. Criterio: revisión con simulador de daltonismo.
- **D41 sensibilidad táctil:** spike de API nativa; si no existe, cámara táctil propia o limitación documentada con `shortcut:`. No se promete soporte sin prueba.
- **D42 reducir movimiento:** extender el ajuste a cámara, balanceo, tweens y clima con un helper común. Criterio: activado, no hay balanceo ni transiciones bruscas.

**Archivos:** `CameraController`, `Linterna`, `AnimacionBeber`, `Acciones`, `Estamina`, `MenuAjustes`, `Settings`, nuevo helper `Movimiento`/`EscalaUI`, `Hud`, `Brujula` nuevo, `Subtitulos`/`AudioService`, `ClimaService`, `FinScreen`.

### L10 · Rendimiento y audio (6–10 días)

**Items:** E47, E48, E50.

- **E47 streaming adaptativo:** ajustar teselas por tick según `Heartbeat` del servidor (1–2), sin superar 150 ms; telemetría del hitch. Criterio: rampa sintética a 500 studs/s ≤150 ms.
- **E48 LOD/pooling:** árboles lejanos simplificados, props y peligros reutilizados; medir partes y memoria con 3 clientes. Criterio: sin pop visible a 480 studs y FPS estable.
- **E50 música:** pista del usuario en `AudioConfig.Musica.id`, crossfade lobby/partida y ducking en reanimar/susto. Criterio: sin ID, no suena y no falla; con ID, mezcla correcta.

### L11 · QA de lanzamiento (5–10 días)

- Ampliar `docs/launch/qa-matrix.md` con los casos nuevos: tutorial, compra con confirmación, misiones, racha, cargar, empujón, bengala, segundo Doble, clima, 140 %, escala UI, brújula, reconexión.
- 3 clientes en Studio para todo lo coop; 8 jugadores reales, móvil físico, mando y compras reales quedan en `docs/pendiente-usuario.md`.
- Cierre: `/ponytail-audit`, `/ponytail-debt`, `graphify update .`, HANDOFF y skill-log.
- Criterio de salida: consola sin errores, `rojo build` limpio, matriz sin casos P0 abiertos.

## 7. Corte de lanzamiento recomendado

El alcance completo son 47 mejoras y varias son contenido grande (B16b, C30, C32, E48). Orden sugerido si se quiere publicar antes de terminar todo:

- **Publicable (soft launch):** L0, L1, L2, L4, L5, L6, más C29 y D37 adelantados de L8/L9, y L11 parcial. Deja el juego justo, estable y presentable.
- **Después del lanzamiento:** L3 (reconexión), L7b (tres etapas), L8 completo (misiones/niveles/cosméticos/global), el resto de L9 y L10.
- No publicar sin: E43, E44, E45, C25, D34, A1, A5, A7, A8.

## 8. Bloqueado por el usuario

- IDs de 3 pases y 3 productos (ya en `pendiente-usuario.md`), pack de bienvenida y 4–6 insignias.
- Pista de música con licencia.
- Prueba real de compra y DataStore tras publicar/API Services.
- Playtest de 8, móvil físico, mando y reconexión en place publicado.
- Decisión de cuenta personal/grupo y uso de assets CC-BY.

## 9. Riesgos

| Riesgo | Mitigación |
| --- | --- |
| 47 mejoras retrasan la publicación indefinidamente | corte de lanzamiento §7; lotes cerrados con evidencia |
| Migración de datos rompe perfiles | esquema v2, respaldo, `QATestDatos`, rollback a v1 |
| Estamina servidor lucha con la física cliente | spike primero, tope de progreso existente y documentar el residual |
| Cargar/empujar rompen personajes | configs de velocidad/impulso, pruebas con 2 clientes, desactivar por modo |
| Reconexión difícil de QA en Studio | separar A6a/A6b y validar en place publicado |
| Segundo Doble desequilibra raptos | máximo por partida, víctimas distintas y prueba con 8 |
| Reflujo 140 % reabre deuda de UI | hacerlo antes de pantallas nuevas y capturar cada panel |
| Sensibilidad táctil sin API | spike con salida documentada; no prometer soporte |
| Localización por claves toca todos los resultados | cambio mecánico + prueba ES/EN en el mismo lote |
| Rendimiento al añadir biomas | medir E47/E48 con B16a antes de B16b |

## 10. Checklist por lote

- [ ] Config y remotes documentados; RateLimiter y validación.
- [ ] Servidor autoritativo; ningún valor mágico fuera de Config.
- [ ] Cliente con textos ES/EN, safe area, `MenuCamara.Vincular` y accesibilidad.
- [ ] `rojo build` limpio y playtest MCP con consola sin errores.
- [ ] Matriz de QA actualizada con el caso nuevo.
- [ ] `/ponytail-review`, `/caveman-commit`, push.
- [ ] Fila en `docs/skill-log.md` y actualización de `docs/HANDOFF.md`.

## 11. Primeros pasos en el próximo chat

1. Leer `docs/HANDOFF.md`, este plan y `docs/pendiente-usuario.md`.
2. Preflight de skills (`SKILLS: …`).
3. Crear la lista de tareas con los lotes L0–L11.
4. Empezar por **L0/E45** (esquema v2) y **L0/E44** (claves de mensajes); sin eso, el resto de persistencia y textos se rehace.
5. No abrir L8/L9 antes de cerrar E45 y D34/D37.
6. Mantener una sola sesión de Studio abierta y reconstruir con `rojo build` antes de cada QA.
