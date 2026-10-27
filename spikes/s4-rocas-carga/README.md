# Spike S4 — Banco de pruebas de carga para físicas de rocas

Plan §9: «S4: físicas de rocas con 8 jugadores (red y rendimiento)» (`docs/PLAN.md`, línea 214).
Este harness cubre la parte de **rendimiento en servidor**; la parte de red (réplica a 8 clientes) se prueba aparte.

## Qué mide

- El **dt real del `RunService.Heartbeat` del SERVIDOR** (delta entre frames medido con `os.clock()` dentro del callback, no un `task.wait` simulado), mientras caen N rocas activas.
- Cada tanda crea N `Part` en forma de Ball (tamaño 3–6 studs, Slate, `Anchored=false`, `CanCollide=true`) cayendo desde y=60–120 sobre una base plana propia 400x400 (Grass, en la carpeta `S4Carga` de workspace), para no depender del sendero del mapa.
- Por tanda imprime `[S4] rocas=N dt_medio=X.XXXs dt_max=X.XXXs (objetivo: dt_medio < 0.033)`; las rocas de la tanda anterior se destruyen entre tandas.
- Al final imprime `[S4] RESUMEN: <conclusión>` con el veredicto contra el presupuesto.

**Límite:** solo mide el coste de físicas en el servidor de Studio (1 jugador). Con 8 jugadores reales el coste de red y de réplica se suma; los resultados aquí son el suelo, no el techo.

## Cómo ejecutarlo

1. Abre el lugar en Roblox Studio.
2. Crea un **Script** (no LocalScript) dentro de `ServerScriptService` y pega el contenido de `s4-carga.server.lua`.
3. Dale a **Play**. El script se ejecuta al arrancar: espera 2 s, construye la base y corre las tandas 0 → 50 → 100 → 200 → 400.
4. Lee la salida en **View → Output** (o con `get_console_output` del MCP). Duración total ≈ 2 + 5 × (6 s de medición + 2 s de pausa) ≈ 42 s.
5. Borra el script al terminar: es código desechable, como el spike S3. Deja la tabla de abajo rellenada.

## Resultados

**Ejecutado el 2026-10-27** en el servidor de Studio (1 jugador, playtest MCP):

| rocas | dt_medio (s) | dt_max (s) | veredicto |
| ----- | ------------ | ---------- | --------- |
| 0     | 0.018        | 0.230      | CUMPLE    |
| 50    | 0.017        | 0.070      | CUMPLE    |
| 100   | 0.017        | 0.019      | CUMPLE    |
| 200   | 0.017        | 0.019      | CUMPLE    |
| 400   | 0.017        | 0.019      | CUMPLE    |

**Conclusión (S4, parte servidor): CUMPLE con holgura.** El dt_medio del Heartbeat del servidor se mantiene en ~17 ms (60 Hz) incluso con **400 rocas físicas activas simultáneas**; el dt_max sube a 70 ms solo al soltar la tanda de 50 y se estabiliza en 19 ms desde 100 rocas. El pico de 230 ms en la tanda vacía es el arranque del playtest (jugador + réplicas), no las rocas.

Veredicto sugerido: `CUMPLE` si dt_medio < 0.033 s, `JUSTO` si 0.033 ≤ dt_medio < 0.050, `NO CUMPLE` en caso contrario.

## Presupuesto propuesto

**`dt_medio` < 1/30 s (≈ 0.033 s) en el servidor** para cualquier tanda. **Resultado: se cumple hasta las 400 rocas probadas** → presupuesto provisional del HazardService: **hasta 400 objetos físicos activos**; la cifra final se re-validará con 8 jugadores reales (la parte de red queda pendiente).

- Origen, plan §3.3 (`docs/PLAN.md`, línea 62): «Presupuestos de rendimiento desde el día uno: máximo de objetos físicos activos, pooling y StreamingEnabled en el mapa grande. Los valores concretos se miden en el spike S4.»
- Plan §11 (`docs/PLAN.md`, línea 232), riesgo «Rendimiento con 8 jugadores y en móvil», mitigación: «Spike S4, StreamingEnabled, pooling y perfiles en móvil».
- Justificación de 1/30 s: Roblox simula físicas a 60 Hz; 1/30 s (2 frames) deja al servidor margen para todo lo demás (jugadores, remotes, lógica del match) antes de perder el ritmo con 8 jugadores. Si la tanda de 400 rocas cumple de sobra, el presupuesto de objetos físicos activos del HazardService se fija en el mayor N que cumpla con holgura.

## Configuración

Constantes al principio de `s4-carga.server.lua`:

| Constante | Valor por defecto | Significado |
| --------- | ----------------- | ----------- |
| `TANDAS` | `{0, 50, 100, 200, 400}` | rocas activas por tanda |
| `DURACION_MEDICION` | `6` | segundos de medición por tanda |
| `PAUSA_ENTRE_TANDAS` | `2` | segundos de descanso entre tandas |
| `ESPERA_INICIAL` | `2` | segundos al arrancar (deja entrar al jugador) |
| `TAMANO_ROCA` | `{3, 6}` | rango de tamaño en studs |
| `ALTURA_CAIDA` | `{60, 120}` | rango de altura de caída en studs |
| `RADIO_DISPERSION` | `180` | radio de caída sobre la base 400x400 |
| `DT_OBJETIVO` | `1 / 30` | presupuesto de dt_medio en servidor |
