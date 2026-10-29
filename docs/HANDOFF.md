# Handoff — Heads Up! Mountain Mayhem

Estado a **2026-10-29** · rama `main` en `f7bcbd6` · repo `github.com/Pausiar/HeadsUpRoblox`.

Documento para retomar el trabajo en otro chat. Fuente de verdad del diseño: [`docs/PLAN.md`](PLAN.md).
Reglas de trabajo obligatorias: [`AGENTS.md`](../AGENTS.md).

---

## 1. Qué es y en qué punto está

- Juego cooperativo de Roblox para 2–8 jugadores: subir una montaña siguiendo un sendero, esquivar peligros diegéticos, reanimar compañeros y sobrevivir a El Doble.
- **Estado:** jugable de principio a fin en Studio (lobby → partida → meta → resultados), en español e inglés.
- **No publicado.** Sin DataStore real, sin IDs de monetización, sin audio definitivo.
- Fases cerradas: 0 (prep/spikes), 1 (vertical slice), 2 (lobby + ranking), 3 (El Doble + chat imitado), 4 (ropa y personalización), 5 (Robux), 6 (audio, móvil, accesibilidad, telemetría, i18n), 7 (docs de lanzamiento), 8 (terreno voxel y rutas), 9 (mundo largo por teselas, meta, tienda, peligros) + última tanda de noche/sustos.

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

---

## 5. Lo que falta

### A. Cierre formal de la fase 9 (siguiente paso natural)

Según `AGENTS.md`, una fase no está cerrada sin:
1. `/ponytail-audit` del repo.
2. `/ponytail-debt` (y actualizar el ledger de `shortcut:`).
3. `/graphify . --update`.
4. Fila de cierre en `docs/skill-log.md`.

### B. Verificación que nunca se ha hecho (riesgo real)

- **2–8 jugadores simultáneos** en la misma partida (todos los playtests han sido 1 jugador).
- **Móvil real** (la UI táctil y el escalado solo se han mirado en Studio).
- **Mando** y cámara en 1.ª persona.
- **Rendimiento con 8 jugadores** y streaming de teselas a la vez (el tirón de 0,33–0,44 s al reconstruir el mapa sigue sin medir en carga).
- **Modo Puro** sin ventajas de pase en partida real.

### C. Deuda registrada (marcadores `shortcut:`)

| Archivo | Qué queda pendiente |
| --- | --- |
| `src/client/Acciones.lua` | En pantallas muy estrechas la fila táctil roza el thumbstick |
| `src/client/Accesibilidad.client.lua` | 140 % no refluye alturas fijas; algunos rótulos se recortan |
| `src/client/LobbyUI.client.lua` | Botones de 44 px base quedan por debajo de 40 px físicos a 0,68 |
| `src/client/ReanimarPersonalUI.client.lua` | Escalado sin validar en hardware real |
| `src/client/TiendaUI.client.lua` | Por debajo de ~360 px el texto ROBUX vuelve a ~10 px |
| `src/server/AmigosRankingService.lua` | Una consulta por jugador (hasta 50 claves); vigilar con grupos grandes |
| `src/server/MonetizacionService.lua` | Modo Puro aún no separa récords del ranking |

Hallazgos de la fase 7 que siguen abiertos:
- `ProcessReceipt` **no comprueba `Activo`**: si se retira un producto hay que desactivarlo, no solo despublicarlo.
- El recibo se marca **antes** del guardado asíncrono (riesgo residual si cae el servidor entre medias).
- 3 de 5 pases no tienen efecto y están desactivados a propósito (`botas_agarre`, `mochila_pro`, `club_montanero`).
- Sin DataStore, el ranking de amigos cae a «no disponible» (en Studio es lo normal).

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

1. **Cerrar la fase 9** con la auditoría, el ledger de deuda y `graphify --update` (barato y deja el repo limpio).
2. **Fase 10 propuesta: QA multijugador y rendimiento** — partida de 2–8 jugadores, móvil real y medición del streaming; definir su «Hecho cuando» en `docs/PLAN.md`.
3. Cuando haya datos de publicación (IDs + `Activo=true`), hacer la prueba de compra real y el smoke de soft launch de `docs/launch/soft-launch.md`.
