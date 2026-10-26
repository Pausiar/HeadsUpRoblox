# AGENTS.md · Heads Up! Mountain Mayhem

Juego cooperativo de Roblox para 2–8 jugadores. **Fuente de verdad: [docs/PLAN.md](docs/PLAN.md).**
Si el plan contradice la documentación oficial de Roblox, gana la documentación: avísalo y propón la corrección.

## Principios de arquitectura (PLAN §3.3)

1. **Servidor autoritativo:** distancia, daño, estado de caída, compras y recompensas se resuelven en el servidor.
2. **Remotes tipados y validados**, con limitación de frecuencia en todos.
3. **Todo por datos:** peligros, etapas, frases, precios y balances viven en ModuleScripts de `src/shared/Config`.
4. **Presupuestos de rendimiento desde el día uno:** máximo de objetos físicos activos, pooling y StreamingEnabled; los valores concretos se miden en el spike S4.
5. **Persistencia:** DataStore con `UpdateAsync`, reintentos, guardado al salir y periódico; el ranking de amigos usa OrderedDataStore.
6. **Rojo = código, MCP = escena:** el Luau vive en `src/` y se sincroniza del disco a Studio con Rojo. El MCP de Studio **nunca** edita un script sincronizado (Rojo lo sobrescribiría); úsalo para escena, playtest, consola y capturas.

## Reglas de uso de skills (obligatorias durante TODO el proyecto)

**Preflight:** antes de cada tarea escribe una sola línea, p. ej.
`SKILLS: graphify✓ ponytail✓ apple-design✗(sin UI) hallmark✗ caveman✓`.
Si omites una que correspondía, justifícalo en una frase.

| Cuándo | Skill obligatoria | Evidencia |
| --- | --- | --- |
| Empezar sesión o tarea sobre código existente | **graphify**: consulta el grafo antes de grep o de leer archivos grandes | Consulta usada, en `docs/skill-log.md` |
| Escribir o modificar Luau | **ponytail**: reutiliza antes de crear, mínimo necesario | Qué se reutilizó o por qué no |
| Antes de cada commit | `/ponytail-review` y `/caveman-commit` | Hallazgos y cómo se resolvieron |
| Cualquier pantalla, HUD, tienda o editor | **apple-design** (revisión) + ADN de **hallmark** (`docs/design/design-dna.md`) | Informe Qué / Por qué / Arreglo |
| Páginas web o material de marketing | **hallmark** | Tema y macroestructura elegidos |
| Mensajes de progreso y subagentes | **caveman** | — |
| Cierre de fase | `/ponytail-audit`, `/ponytail-debt` y `/graphify . --update` | Entrada de cierre en `docs/skill-log.md` |

**Skill-log:** al terminar cada tarea, una línea en `docs/skill-log.md` (fecha · tarea · skills · resultado). Una tarea sin esa línea no está terminada.

## Reglas de modelo

- **GLM-5.3:** arquitectura, sistemas del servidor (MatchService, StageService, HazardService, RevivalService, MonsterService, ChatMimicService, CustomizationService, DataService, MonetizationService), networking, refactors y revisión final de cada fase.
- **GLM-5.3-Flash:** maquetación de UI, Config y datos, localización, boilerplate, tareas rápidas y verificación visual comparando `screen_capture` con `docs/concept/`.
- Al delegar en subagentes, pásales este archivo y exige las mismas reglas de skills.

## Reglas de trabajo

- Una fase del plan a la vez. Cada fase termina cuando se cumple su «Hecho cuando» **con evidencia**: playtest con el MCP (`start_stop_play`, `get_console_output`, `screen_capture`, subagente de playtest) y consola sin errores.
- Seguridad y cumplimiento: remotes validados, texto de jugadores siempre por `TextService:FilterStringAsync`, nada de compras aleatorias de pago y `PolicyService` en la tienda.
- Commits pequeños y frecuentes; todo se publica en `github.com/Pausiar/HeadsUpRoblox`.
- Una sola tanda de preguntas por fase.
- No marques nada como hecho sin haberlo ejecutado.
