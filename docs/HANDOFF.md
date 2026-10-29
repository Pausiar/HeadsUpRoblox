# Handoff — Heads Up! Mountain Mayhem

Estado a **2026-10-29** · rama `main` en `02537b7` · repo `github.com/Pausiar/HeadsUpRoblox`.

Documento para retomar el trabajo en otro chat. Fuente de verdad del diseño: [`docs/PLAN.md`](PLAN.md).
Reglas de trabajo obligatorias: [`AGENTS.md`](../AGENTS.md).

---

## 1. Qué es y en qué punto está

- Juego cooperativo de Roblox para 2–8 jugadores: subir una montaña siguiendo un sendero, esquivar peligros diegéticos, reanimar compañeros y sobrevivir a El Doble.
- **Estado:** jugable de principio a fin en Studio (lobby → partida → meta → resultados), en español e inglés.
- **No publicado.** Sin DataStore real, sin IDs de monetización, sin audio definitivo.
- Fases cerradas: 0 (prep/spikes), 1 (vertical slice), 2 (lobby + ranking), 3 (El Doble + chat imitado), 4 (ropa y personalización), 5 (Robux), 6 (audio, móvil, accesibilidad, telemetría, i18n), 7 (docs de lanzamiento), 8 (terreno voxel y rutas), 9 (mundo largo por teselas, meta, tienda, peligros, noche/sustos) y el cierre formal de la 9 (auditoría, ledger, graphify).

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

### Números y datos clave

- Ruta historia: **4846 studs**, 18 checkpoints cada 260, ~5 min; meta a 10 studs del final.
- Piñas: 1 por 20 studs caminados, +25 por récord, +100 por meta; se pagan en vivo a 1 Hz.
- Tienda del campamento a 12 studs del spawn: 11 items (bebida 20 Piñas, mejoras de niveles).
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

---

## 5. Lo que falta

### A. Cierre formal de la fase 9 — hecho (2026-10-29)

- `/ponytail-audit`: sin «must fix» abiertos; los hallazgos de servidor y cliente se corrigieron en `0cb38bc` y `02537b7`. Los abiertos pasan a la fase 10.
- `/ponytail-debt`: 11 marcadores `shortcut:`, todos con disparador; tabla C actualizada.
- `graphify update .`: 859 nodos, 1509 aristas, 42 comunidades (AST de código; los docs conservan sus nodos previos, sin reextracción semántica por falta de `GEMINI_API_KEY`).
- Fila de cierre en `docs/skill-log.md` con la evidencia de `QATestVelocidad`, `QATestDoble` y `QATestBeber`.

### B. Verificación que nunca se ha hecho (riesgo real)

- **2–8 jugadores simultáneos**: hay una partida de 2 en Studio; faltan 3–8 en la misma partida y la prueba con amigos reales.
- **Móvil real** (la UI táctil y el escalado solo se han mirado en Studio).
- **Mando** y cámara en 1.ª persona.
- **Rendimiento con 8 jugadores** y streaming de teselas a la vez (el tirón de 0,33–0,44 s al reconstruir el mapa sigue sin medir en carga).
- **Modo Puro** sin ventajas de pase en partida real (el filtro del ranking ya está implementado y probado en código, no en una partida de 8).

### C. Deuda registrada (marcadores `shortcut:`)

11 marcadores en 10 archivos, todos con disparador de revisión:

| Archivo | Qué queda pendiente |
| --- | --- |
| `src/client/Acciones.lua` | En pantallas muy estrechas la fila táctil roza el thumbstick |
| `src/client/Accesibilidad.client.lua` | 140 % no refluye alturas fijas; algunos rótulos se recortan |
| `src/client/CameraController.client.lua` | La sensibilidad de Ajustes no se aplica en 1.ª persona; el ajuste se muestra y no hace nada |
| `src/client/CustomizationUI.client.lua` | Panel fijo sin scroll; a 568×320 las filas inferiores pueden quedar fuera del área táctil |
| `src/client/Estamina.client.lua` | Estamina cliente (ventaja máxima ≈33 % sobre el sprint real); sin bindings de gamepad |
| `src/client/LobbyUI.client.lua` | Botones de 44 px base quedan por debajo de 40 px físicos a 0,68 |
| `src/client/ReanimarPersonalUI.client.lua` | Escalado sin validar en hardware real |
| `src/client/TiendaUI.client.lua` | Por debajo de ~360 px el texto ROBUX vuelve a ~10 px |
| `src/server/AmigosRankingService.lua` | Una consulta lee hasta 50 claves por jugador; vigilar con grupos grandes |
| `src/shared/Config/TiendaConfig.lua` | Los nombres del catálogo están en español fijo; en EN la tienda mezcla idiomas |

Hallazgos de la fase 7 y su estado:
- `ProcessReceipt` **no comprueba `Activo`**: decisión consciente. Un recibo real debe entregarse aunque el catálogo esté desactivado; para retirar un producto, no reutilizar su ID.
- El recibo se marca **antes** del guardado asíncrono: riesgo residual solo si el servidor cae entre la caché y el DataStore; el rollback cubre el fallo de entrega.
- 3 de 5 pases no tienen efecto y están desactivados a propósito (`botas_agarre`, `mochila_pro`, `club_montanero`); no activarlos hasta implementarlos.
- Sin DataStore, el ranking de amigos cae a «no disponible» (en Studio es lo normal).
- Modo Puro ya separa los récords del ranking de amigos (`AmigosRankingService`); falta la prueba con una partida real de 8.

### D. Bloqueado por el usuario

- Publicar el juego y activar **API Services** (sin eso no hay DataStore real ni telemetría).
- Crear en el Creator Dashboard los **IDs de 5 pases y 3 productos**, rellenarlos en `MonetizacionConfig` y poner `Activo = true`.
- Probar una **compra real** (los productos de prueba del dashboard).
- **Música definitiva** (`AudioConfig.Musica.id = 0`; los efectos usan sonidos nativos de Roblox).
- **Iconos y thumbnails** de la ficha del juego.
- Decidir **cuenta personal o de grupo** (afecta a ingresos y servidores privados).
- Lista de **.obj de Sketchfab con licencia** (spike S2, sin usar aún).
- 4–8 amigos para el playtest real (el criterio «Hecho cuando» de la fase 3 lo pide).

---

## 6. Mapa rápido del código

```
src/
  server/   Main.server.lua (arranque), DataService, LobbyService, MatchService,
            StageService, TerrenoService, HazardService, MonsterService, ChatMimicService,
            PlayerStateService, PinasService, PuntosService, TiendaService, RopaService,
            CustomizationService, AccesoriosService, MonetizacionService,
            RankingService, AmigosRankingService, RondaRapidaService, TelemetriaService
  client/   MenuInicio, LobbyUI, Hud, HudPuntos, HudPinas, HudRanking, FinScreen,
            CameraController, Estamina, Linterna, AudioService, Subtitulos, Acciones,
            Accesibilidad, MenuAjustes, TiendaUI, ReanimarPersonalUI,
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

1. **Fase 10: QA multijugador y rendimiento** — ejecutar la matriz de 2–8 jugadores, móvil real, mando + 1.ª persona, perfilado del streaming y Modo Puro en partida. «Hecho cuando» en `docs/PLAN.md` §9.
2. **Cerrar la fase 10** con `/ponytail-audit`, `/ponytail-debt`, `graphify update .` y fila en `docs/skill-log.md`.
3. Cuando haya datos de publicación (IDs + `Activo=true`), hacer la prueba de compra real y el smoke de soft launch de `docs/launch/soft-launch.md`.
