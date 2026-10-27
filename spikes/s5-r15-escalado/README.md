# Spike S5 — Límites de escalado del cuerpo R15

Plan §9 (`docs/PLAN.md`, línea 215): «S5: límites de escalado del cuerpo R15.»
Plan §6 (`docs/PLAN.md`, línea 146): «**Cuerpo:** altura, ancho (el «peso») y tamaño de cabeza con las escalas de Humanoid de R15. La longitud independiente de brazos y piernas no existe como escala estándar: se evalúa en el spike S5 y, si es costosa, pasa a la versión 2.»

## Qué mide

1. **Qué escalas existen realmente en `HumanoidDescription`**: sondas con `pcall` (set + get numérico) sobre nombres candidatos por rol (`HeightScale`/`BodyHeightScale`, `WidthScale`/`BodyWidthScale`, `DepthScale`/`BodyDepthScale`, `HeadScale`, `ProportionScale`, `BodyTypeScale`) y sobre candidatas de longitud independiente de brazos/piernas (`ArmLengthScale`, `LegLengthScale`, `TorsoLengthScale`, `ArmScale`, `LegScale`, `TorsoScale`, `HandSizeScale`, `FootSizeScale`). Respuesta esperada: **ninguna** escala de extremidades existe → pasa a la versión 2.
2. **Altura real por caso**: rig R15 creado con `Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)` (con `pcall`), altura medida como el lado Y de `Model:GetExtentsSize()` (bounding box del rig completo, incluido el HumanoidRootPart; método constante entre casos). Cada caso queda de pie sobre **su propia base plana** (8x1x8, cara superior en y=0) en la carpeta `S5R15` de workspace, en fila sobre el eje X, con la raíz anclada, para capturar con `screen_capture`.
3. **Saturación (clamp)**: se escribe 10 y 0.01 en la escala de altura y se lee de vuelta, para documentar si `HumanoidDescription` satura al escribir o al aplicar.

Casos (valores del plan §6 — alturas 0.9/1.0/1.05, anchos 0.7/1.0/1.3, cabezas 0.85/1.0/1.25): `normal`, `minimo`, `maximo`, `alto_delgado`, `bajo_ancho`.

## Cómo ejecutarlo

1. Abre el lugar en Roblox Studio.
2. Crea un **Script** (no LocalScript) dentro de `ServerScriptService` y pega el contenido de `s5-r15.server.lua`.
3. Dale a **Play**. El script espera 2 s, sondea las escalas y crea los 5 rigs en fila. Duración total < 1 min (la primera llamada a `CreateHumanoidModelFromDescription` puede tardar unos segundos).
4. Lee la salida en **View → Output** (o con `get_console_output` del MCP) y captura la fila de rigs con `screen_capture`.
5. Borra el script al terminar: es código desechable, como los spikes S3 y S4. Deja la tabla de abajo rellenada.

## Resultados

**Ejecutado el ____** en el servidor de Studio (1 jugador, playtest MCP):

| caso         | altura real (studs) | error | veredicto |
| ------------ | ------------------- | ----- | --------- |
| normal       |                     |       |           |
| minimo       |                     |       |           |
| maximo       |                     |       |           |
| alto_delgado |                     |       |           |
| bajo_ancho   |                     |       |           |

Escalas que existen en `HumanoidDescription` (según probes): ____

Longitud independiente de brazos/piernas (esperado: NO existe): ____ → ¿pasa a versión 2? ____

Clamp observado (set 10 / 0.01 → leído): ____

Veredicto sugerido por caso: `CUMPLE` si el rig se crea sin error y la altura escala de forma monótona con la escala configurada; `REVISAR` si hay error o la altura no cambia.

## Conclusión (rellenar tras el playtest)

- Límites prácticos observados (altura real mínima/máxima y rangos de Config propuestos para `CustomizationService`): ____
- Decisión brazos/piernas independientes: ____

## Configuración

Constantes al principio de `s5-r15.server.lua`:

| Constante | Valor por defecto | Significado |
| --------- | ----------------- | ----------- |
| `CASOS` | 5 casos (normal/mínimo/máximo/alto_delgado/bajo_ancho) | combinaciones altura/ancho/cabeza |
| `ESPERA_INICIAL` | `2` | segundos al arrancar |
| `SEPARACION` | `10` | studs entre bases en la fila (eje X) |
| `LADO_BASE` | `8` | lado de la base plana de cada caso |
| `CANDIDATAS_ROL` | alt/ancho/prof/cabeza/proporción/tipo | nombres candidatos por rol; se usa el primero que exista |
| `CANDIDATAS_EXTREMIDADES` | 8 nombres | candidatas de extremidades; se espera que ninguna exista |
