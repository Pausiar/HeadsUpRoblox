# Revisión apple-design — HUD y pantallas del slice (fase S4)

**Fecha:** 2026-10-27
**Alcance:** `src/client/Hud.client.lua`, `src/client/HudPuntos.client.lua`, `src/client/FinScreen.client.lua`, `src/client/HudRanking.client.lua` + 2 capturas de playtest + `docs/concept/concepto-ui-pantallas.png`.
**Método:** skill **apple-design** completa (HIG: `accessibility.md`, `typography.md`, `color.md`, `layout.md`, `buttons.md`, `feedback.md`, `motion.md`) + ADN de **hallmark** (`docs/design/design-dna.md`). Contrastes calculados con WCAG 2 a partir de los hex **del código** (no estimados del JPEG).
**Límite de una sola escritura:** esta revisión vive solo en este archivo; la línea de `docs/skill-log.md` no se ha podido escribir por la restricción de un único archivo de esta tarea — añadirla al cerrar la tarea padre.

**Limitaciones honestas:** no he podido verificar táctil real, mando, ni notch físico (no hay dispositivo); la cuenta «CAÍDO · Ns» depende del cadencia del servidor que no está en los archivos revisados. Las dos capturas disponibles muestran el **HUD en partida** (jugador caído), **no** el panel «¡HAS CAÍDO!» de FinScreen: ese hallazgo es solo de código, sin confirmación visual.

---

## Resumen

**Valoración: Bueno, con 1 crítico (P0).** La tesis del HUD —«leer el estado de la partida de un vistazo sin dejar de mirar la pendiente»— está bien servida por la paleta de madera/crema del ADN: jerarquía clara (distancia > tiempo > estado), contrastes sobre madera casi todos sobrados (11.46:1, 8.83:1, 6.46:1). Lo que falla es justo el momento de mayor carga emocional: los popups de puntos y el texto «CAÍDO» conviven con fondos que no controlamos (cielo, nieve) o colores justo en el límite. Lo que se recordará hoy: el panel de madera marrón oscuro. Para que sea memorable falta el toque del ADN (iconos, corona) y la robustez móvil.

---

## 1. HUD en partida — `Hud.client.lua`

**Lo que funciona:** crema sobre madera 11.46:1 y amarillo 8.83:1 (verificado, coincide con el comentario del código); el estado se comunica con texto Y color, no solo color (`accessibility.md › Vision`, «Convey information with more than color alone»); panel oscuro sólido legible sobre el cielo de las capturas.

| # | Prioridad | Qué | Por qué | Arreglo |
| --- | --- | --- | --- | --- |
| H1 | **P1** | «CAÍDO · Ns» en rojo `#E0453A` a **18 px bold** → **3.28:1**. 18 px bold = 13,5 pt bold, por debajo del umbral de 14 pt bold que baja el requisito a 3:1 → necesita 4.5:1 y no llega. Es el estado más importante del juego y el texto menos legible del HUD. | `accessibility.md › Vision`: «Strive to meet color contrast minimum standards» (tabla WCAG: hasta 17 pt → 4.5:1). | Subir el estado a **20 px** (15 pt bold, umbral 3:1, pasa 3.28:1) **y** aclarar el rojo de texto a `#F26B5B` (**4.54:1**) o `#FF6F61` (**4.97:1**) sobre madera; el rojo `#E0453A` queda reservado para fondos y el título de 40 px. |
| H2 | **P1** | La cuenta atrás solo se escribe dentro de `OnClientEvent` (líneas 51-60); `Heartbeat` no la refresca. Si el servidor no reenvía cada segundo (los remotes van con rate-limit según el repo), la cuenta se congela — la captura 2 muestra «CAÍDO · 116s», plausible de valor rancio. | `feedback.md › Best practices`: el estado debe reflejar lo que pasa ahora; una cuenta congelada miente. | Guardar `marcaReloj = os.clock()` al recibir `restante` y en `Heartbeat` pintar `restanteCaido - (os.clock() - marcaReloj)`. |
| H3 | **P2** | Posición en offsets fijos sin safe area: panel de ranking en x 20–240 y panel de estado desde `width-260`. En móvil vertical (~390 px de ancho lógico) los paneles se solapan (130–240); en horizontal el notch queda a la izquierda, justo sobre el ranking. | `layout.md › Guides and safe areas`: «Respecting the safe area is essential». | Posicionar con `GuiService:GetGuiInset()` como margen y, a medio plazo, anclas en escala con `UISizeConstraint`/UIListLayout. No verificable sin dispositivo: queda pendiente de prueba real. |
| H4 | **P3** | El tiempo de partida lo cuenta el cliente con `os.clock()`; el servidor es autoritativo (principio §3.3 del plan). | Puede divergir del tiempo real del servidor al reconectar/resincronizar. | Usar el `tiempo` que ya viaja en el payload de `HudEstado` y solo interpolar entre eventos. |
| H5 | **P3** | Sin iconos: el ADN reserva corazón (vida), reloj (tiempo), regla/flecha (distancia). Todo son prefijos de texto hoy. | Glanceability en partida: un icono se reconoce sin leer (`icons`/ADN §Iconografía). | Añadir los iconos con contorno del ADN cuando existan como assets; no usar emoji (regla del ADN). |

**Comparado con el concepto:** el concepto además lleva estamina abajo-izquierda y controles mapeados abajo-derecha; es asumible que el slice no los tenga, pero son parte del HUD definitivo.

---

## 2. Puntos y popups — `HudPuntos.client.lua`

**Lo que funciona:** pool de 4 etiquetas reutilizables (nada que crear/destruir por evento); color semántico del popup (amarillo puntos, lima reanimar) alineado con el ADN; animación de 1 s breve y única, dentro de lo que pide `motion.md › Providing feedback` («Aim for brevity and precision»).

| # | Prioridad | Qué | Por qué | Arreglo |
| --- | --- | --- | --- | --- |
| P1 | **P0** | Los popups «+N» flotan **sin fondo ni contorno sobre el mundo 3D**: amarillo `#FFC93C` sobre cielo claro ≈ **1.13–1.54:1**, lima `#8BC34A` ≈ **2.10:1**. El premio del juego es ilegible exactamente cuando se gana. En la práctica del proyecto (nieve, cielo, piedras claras del concepto) ocurrirá a cada rato. | `accessibility.md › Vision` + `color.md › Inclusive color`: «insufficient contrast can cause icons and text to blend with the background». Rompe usabilidad, no es pulido. | Añadir `UIStroke` (Color `#3E2A18`, Thickness 2, `ApplyStrokeMode.Contextual`) a cada popup — coste de 3 líneas — o una píldora de madera detrás. Con contorno marrón, el amarillo mantiene su lectura sobre cualquier fondo. |
| P2 | **P2** | Los popups suben desde y=124 hasta ~46 (slots 2–4) cruzando el panel de estado (y 20–116) con ZIndex 2: pasan por encima del texto «CAÍDO · Ns» justo cuando más se necesita. | `layout.md › Visual hierarchy`: los elementos no deben tapar información de mayor prioridad. | Bajar la base a y≥132 (debajo del panel de puntos) y que la subida recorra la franja libre; o desplazar los popups hacia el centro (x −330) para que no coincidan con la columna del estado. |

---

## 3. Pantalla «¡HAS CAÍDO!» — `FinScreen.client.lua`

**Sin captura de verificación** (las dos capturas son de partida): hallazgos de código.

**Lo que funciona:** el comentario del código decía «insignia amarilla 8.8:1» — **verificado: 8.83:1**, correcto; entrada sutil de 0,25 s con fundido + 24 px de subida, sin sacudidas (respeta el §8 del plan y `motion.md`); un solo botón prominente verde, coherente con «verde solo para la acción primaria» del ADN; blanco sobre verde 4.07:1 a 26 px bold (19,5 pt ≥ 14 pt → umbral 3:1, pasa).

| # | Prioridad | Qué | Por qué | Arreglo |
| --- | --- | --- | --- | --- |
| F1 | **P1** | Panel fijo de **420×420 px** en offsets anclado al centro: en viewport de móvil (~390–430 px lógicos en vertical) se recorta por ambos lados — se pierden las esquinas redondeadas y parte del margen interior; el botón de 300 px aún cabe, pero la composición se rompe. Roblox es mayoritariamente móvil. | `layout.md › Adaptability`: la interfaz debe adaptarse a tamaños de pantalla sin perder composición. | `Size = UDim2.fromScale(0.9, 0)` + `UISizeConstraint` (Max 420×420) + alto por contenido, o `UIAspectRatioConstraint`. Verificar con el simulador de dispositivos. |
| F2 | **P2** | Enfriamiento de 3 s sin feedback: tras tocar, `Active=false` y `AutoButtonColor=false`, pero el botón se ve idéntico. El jugador no distingue «ya está pulsado» de «no funcionó». | `buttons.md › Best practices`: «Always include a press state for a custom button»; `feedback.md`: la acción debe confirmarse. | Durante el enfriamiento: atenuar (`BackgroundColor3` → verde ×0.7) y cambiar el texto a «Reanudando…»; restaurar al terminar. |
| F3 | **P2** | Copia «Checkpoint: sin checkpoint» — la palabra repetida dos veces no dice nada nuevo. | `writing` (lens 5): una etiqueta dice lo que ocurre, sin relleno. | «Sin checkpoint» a secas, o «Checkpoint: —». |
| F4 | **P3** | Solo REINTENTAR: el concepto muestra REINTENTAR + MENÚ PRINCIPAL; sin teclado/mando no hay ruta de salida del bucle de caída salvo respawn. | `buttons.md › Role`: la acción primaria además debería responder a Enter/confirmar del mando (`SelectedObject`). | En el slice vale; para fase 4 añadir «MENÚ PRINCIPAL» secundario y fijar `NextSelectionRight`/`SelectedObject` al botón. |
| F5 | **P3** | La insignia de récord es solo texto amarillo; el ADN la asocia a corona. | ADN §Iconografía: corona = récord/ranking. | Cuando haya iconos, corona a la izquierda de «¡NUEVO RÉCORD!». El amarillo como color único ya funciona (no es color-alone: el texto lo dice). |

---

## 4. Ranking — `HudRanking.client.lua`

**Lo que funciona:** el líder se marca con amarillo **y** con el «1.» — no es color-alone (`accessibility.md › Vision`); «Sin jugadores» al 40 % de transparencia → contraste efectivo **5.18:1** (mezcla `172,158,139` sobre madera), pasa incluso para 16 px bold que exige 4.5:1; `TextTruncate` evita desbordes; sin RichText, los displayName no pasan por inyección.

| # | Prioridad | Qué | Por qué | Arreglo |
| --- | --- | --- | --- | --- |
| R1 | **P2** | El sufijo «(tú)» se trunca: el nombre tiene 84 px a 16 px ≈ 9-10 caracteres; con un DisplayName largo, `TextTruncate.AtEnd` se come precisamente el «(tú)», que es lo único que el jugador busca. | Jerarquía: la información propia es la más importante de la lista para el jugador. | Para la propia fila, prescindir del nombre largo: mostrar «Tú» + puntos, o reservar los últimos 28 px sin truncar y truncar solo el nombre. |
| R2 | **P3** | El título «RANKING» gasta una fila (26 px) y en mayúsculas, cuando el concepto no muestra título ninguno en el HUD — la lista se lee sola. Además el ADN pide etiquetas en minúscula/oración. | Craft (remove one accessory): quitar sin pérdida. | Eliminar el título o dejarlo solo en el estado vacío («Sin jugadores» ya avisa). El panel gana altura para 5 filas futuras (2–8 jugadores). |
| R3 | **P3** | Máximo 4 filas con partidas de 2–8: los puestos 5–8 nunca se ven, ni siquiera «tú» si vas 5.º o peor. | El jugador fuera del top-4 pierde su feedback (posición propia). | Fila 5 fija «tú: N pts» cuando no estás en el top-4 (el concepto de resultados hace exactamente eso con «Lex 2.504 m»). |

---

## Transversal

| # | Prioridad | Qué | Por qué | Arreglo |
| --- | --- | --- | --- | --- |
| T1 | **P2** | La paleta vive duplicada como constantes locales en 3 scripts (ya con dos nombres para el mismo marrón `#3E2A18`/«MADERA_OSCURA»/«COLOR_PANEL»). Riesgo de deriva: cambiar la madera del juego será una búsqueda manual. | `color.md › Best practices`: un color significa una cosa — y para eso hace falta una única fuente de verdad. | Módulo `src/shared/Config/UITokens.lua` (por Rojo) con los 8 hex del ADN; los scripts lo requieren. Reutilizar antes que copiar. |
| T2 | **P2** | Roblox no escala el texto con ajustes del sistema (no hay Dynamic Type). Los tamaños son fijos de por vida para el jugador. | `accessibility.md › Vision`: «give people the option to enlarge text by at least 200 percent» cuando el sistema no lo da. | Cuando exista la pantalla Ajustes (plan: pestañas Juego/Gráficos/Sonido/Controles), añadir un multiplicador de tamaño de UI (0,85 / 1 / 1,25) que escale TextSizes. |
| T3 | **P3** | Fuentes `Enum.Font.GothamBold/GothamBlack`: Roblox las renombró (alias de Montserrat). Funcionan hoy, pero son la vía legacy. | Evitar depender de un alias deprecable; el ADN pide «sans chunky redondeada» — Montserrat ya es un paso, falta la redondeada (Fredoka/Baloo) a validar en Studio. | Migrar a `FontFace` con `rbxasset://fonts/families/Montserrat.json` cuando se toque UI; spike de fuente display para titulares pendiente del plan (fase 1). |
| T4 | **P3** | Par rojo/verde (Sano/CAÍDO) — el cruce clásico de daltonismo citado textualmente en las guías. Mitigado: el texto cambia («Sano» vs «CAÍDO · Ns»), no es color-alone. | `accessibility.md › Vision`: «particular difficulty with pairings such as red-green». | Con los iconos del ADN (corazón/estado) queda resuelto del todo. Prioridad baja por la mitigación existente. |

---

## Las 5 mejoras por impacto (ordenadas)

1. **Contorno marrón `UIStroke` en los popups de puntos** (P0, 3 líneas): convierte el premio de 1.13:1 (invisible sobre cielo) en legible sobre cualquier fondo. Máximo retorno por esfuerzo del informe entero.
2. **Estado de caída legible:** rojo de texto a `#FF6F61` (4.97:1) y estado a 20 px; de paso, cuenta atrás interpolada en `Heartbeat` para que no se congele (H1+H2). El momento más tenso del juego debe ser el más legible.
3. **Móvil de verdad:** safe area vía `GetGuiInset()` en los 3 paneles y `FinScreen` con escala + `UISizeConstraint` (F1+H3). Es la plataforma mayoritaria y hoy se solapan paneles y se recorta la pantalla de fin.
4. **Feedback del botón REINTENTAR:** atenuado + «Reanudando…» durante los 3 s de enfriamiento (F2); y copia «Sin checkpoint» (F3). Evita el doble toque y la sensación de botón muerto.
5. **Tokens compartidos + fila «tú» en el ranking** (T1+R1+R3): una sola fuente de verdad de la paleta del ADN y que el jugador siempre vea su posición, esté donde esté.

---

## Veredicto: ¿HUD definitiva?

**No, todavía — y eso es lo esperable en el slice.** Como entrega del slice S4 está por encima del mínimo: paleta fiel al ADN, jerarquía correcta, contrastes sobre madera sobrados (11.46/8.83/6.46:1) y código ordenado con pool y debounces. Pero no es la HUD definitiva porque le faltan: (a) legibilidad sobre el mundo (popups P0, estado P1), (b) adaptación móvil y safe area, (c) los iconos del ADN (corazón, reloj, corona, regla) y la estamina del concepto, (d) opciones de tamaño de texto. Con las mejoras 1–3 aplicadas y verificadas con `screen_capture` + simulador de dispositivos, esta arquitectura de paneles sí puede convertirse en la definitiva sin reescribirla — el esqueleto es correcto; faltan los acabados.

*Citas usadas (archivos HIG abiertos): `accessibility.md › Vision`, `color.md › Inclusive color`, `typography.md › Ensuring legibility`, `layout.md › Guides and safe areas` y `› Adaptability`, `buttons.md › Best practices`, `feedback.md › Best practices`, `motion.md › Providing feedback`.*

---

## Fase 2 — lobby formal y ranking de amigos (2026-10-28)

Revisión estática con la skill apple-design de `src/client/LobbyUI.client.lua` y `src/client/RankingAmigosUI.client.lua` (set siempre-necesario + buttons, lists-and-tables, loading, feedback y writing). Veredicto inicial: **problemas críticos**; tras los arreglos, sin críticos pendientes. Verificado con `screen_capture` del lobby (escala 1) y del ranking con velo; consola sin errores nuevos.

**Resuelto**

- **C1 · Escala móvil (crítico):** con suelo 0,62 el panel de 560×540 dejaba el texto en 9–10 px y los botones por debajo de 40 px en un móvil apaisado (390 px de alto). Arreglo: fuentes base +25 % (nombre 20, estado 18, HOST 17, botones 30/26/20), chip HOST 62×21, suelo de escala 0,68 y aviso de que el reflujo táctil completo (objetivos ≥44 px) entra en la fase 6.
- **A1 · Acuse del LISTO (alto):** el botón no cambiaba hasta el siguiente payload. Arreglo: al pulsar muestra «…» y se deshabilita; `aplicarEstado` lo restaura (≤5 s por el latido).
- **A2 · Deshabilitado indistinguible (alto):** verde apagado 1,53:1 contra verde activo. Arreglo: los estados bloqueados usan el marrón de botón #6B4A2B, no el verde.
- **A3 · Aviso temporal de 2 s (alto):** demasiado corto para leerlo. Arreglo: 6 s.
- **M3 · Ranking sin velo modal:** el panel se fundía con la sala y VOLVER podía dejarlo huérfano sobre el menú. Arreglo: velo #3E2A18 al 0,35 que absorbe clics + VOLVER lo cierra. Verificado en captura.
- **M6 · Salto del LISTO:** al empezar la cuenta el botón saltaba 106 px y cambiaba de significado. Arreglo: para el host se mantiene en x=24 durante «esperando» y «cuenta».

**Diferido a fase 6 (pulido móvil):** M1 marca de selección del modo, M2 chip «TÚ» en la fila propia del lobby, M4 reintento desde el error del ranking, M5 indicador de carga animado, M7 mensaje con cuántos jugadores/listos faltan, M8 igualar alturas de LISTO/EMPEZAR y B1 botón AMIGOS duplicado con la sala abierta.

---

## Fase 4 — editor de ropa plan B (2026-10-28)

Revisión con la skill apple-design de `src/client/CustomizationUI.client.lua` (pestaña ROPA y controles compartidos), `src/server/RopaService.lua` y `src/shared/RopaArte.lua` (set siempre-necesario + buttons, pickers, feedback, layout y writing). Verificado con `screen_capture` del editor abierto (`Capture_1`) y del personaje en el mundo con la camiseta aplicada (`Capture_2`), más clics reales del MCP (`PestanaRopa`, patrón, color, pegatina, GUARDAR) y consola del servidor: `[Ropa] diseño guardado por PausiarOG: ranura 1`; el torso mostró 2 `SurfaceGui` «RopaCamiseta» (Front/Back) con el mismo dibujo que la vista previa. CUERPO sigue enviando `Personalizacion` (el servidor aplicó escalas aleatorias en el smoke). Consola sin errores nuevos.

**Resuelto durante la revisión**

- **E1 · `RopaEstado` pisaba ediciones tempranas (medio):** la primera respuesta del servidor sobrescribía un diseño que el jugador ya hubiera tocado antes de que llegara. Arreglo: la condición ahora es solo `not estadoRopa.modificado`, también en la primera carga.
- **E2 · Cambiar de ranura descartaba el borrador (medio):** editar la ranura 1 sin guardar y saltar a la 2 perdía los cambios al volver. Arreglo: borrador local por ranura (`estadoRopa.borradores`), que se restaura al volver y se limpia solo cuando el guardado coincide; `RopaEstado` no lo pisa.
- **E3 · Carrera de guardado perceptible (bajo):** el enfriamiento de 1 s del cliente descarta pulsaciones rápidas sin explicación; se mantiene (el servidor tiene el mismo límite y el aviso GUARDADO llega con la respuesta) y se documenta aquí.

**Lo que funciona:** una sola fuente de arte (`RopaArte`) para vista previa y torso, así lo que se ve es lo que se guarda; selección con texto además de color (nombre de patrón/pegatina en amarillo y `Color 1/2: <nombre>`), nunca color-alone; contrastes del ADN ya validados (crema sobre madera 11,46:1, amarillo 8,83:1) y texto oscuro sobre amarillo en los botones activos; GUARDAR solo aparece con función clara por pestaña y el aviso de éxito/error vive en la interfaz, no en un alert; la nota de ranuras dice la verdad del sistema («3 de 9 ranuras · las extra llegan con el pase»).

**Pendiente para fase 6 (pulido móvil):** objetivos táctiles de 40–42 px (ranuras 56×40, patrón/pegatina 92×40, muestras 42×42), por debajo del objetivo de 44 y que a escala 0,68 quedan en ~27–29 px; anillo de selección crema sobre muestras crema/blanca casi invisible (mitigado por el nombre bajo la fila); panel de 600 px de alto que en viewports cortos depende del suelo de escala 0,68; feedback explícito al descartar un guardado por enfriamiento.

**Diferido a fase 5:** el editor pinta 9 ranuras pero el servidor acepta 3 (`RanurasGratis`); al abrir las ranuras con el pase hay que ampliar también la validación del servidor, ajustar la nota y revisar la segunda fila de ranuras (40 px de alto con 4 px de separación, y la nota baja a y=232).

**Veredicto:** el editor cumple el «Hecho cuando» de la fase 4 — se ve igual en cliente y servidor, se guarda y se replica en el mundo — con deuda táctil acotada y ya asignada a la fase 6.

---

## Fase 5 — tienda Robux, reanimación personal y Modo Puro (2026-10-28)

Revisión con la skill apple-design de `src/client/TiendaUI.client.lua` (reescrita con pestañas PIÑAS/ROBUX), `src/client/ReanimarPersonalUI.client.lua` (nueva) y el perfil visual de `src/client/Linterna.client.lua` con el pase (set siempre-necesario + buttons, tab-bars, lists-and-tables, feedback, loading, writing y color). Verificado con `screen_capture` de la tienda en ambas pestañas, del panel de reanimación sobre el HUD caído, del aviso REANIMADO y del Modo Puro activo; clics reales del MCP y consola del servidor (`[Monetizacion] reanimación personal usada por PausiarOG (stock)`, rechazo por límite por partida, rechazo en Modo Puro, `Modo Puro on/off`, linterna 40,25° ↔ 35° en vivo). Consola sin errores del juego.

**Resuelto durante la revisión**

- **E1 · «AL PUBLICAR» para lo no vendible (alto):** con `Activo=false`, los pases `disponible=false` mostraban «AL PUBLICAR», que sugiere que basta publicar. Arreglo: `disponible == false` se evalúa antes y el botón dice «PRÓXIMAMENTE», deshabilitado.
- **E2 · Recompra de Piñas x2 (alto, dinero):** recomprar reiniciaba el vencimiento desde el momento de la compra, así que el jugador pagaba otra vez por el mismo tramo. Arreglo: la recompra extiende desde el vencimiento vigente.
- **E3 · Saldo inicial invisible (alto):** la tienda y el HUD mostraban «Piñas: 0» hasta cerrar una partida, aunque el jugador tuviera saldo guardado. Arreglo: `PinasService` publica el total al cargar los datos y al entrar.
- **E4 · Copia de stock (bajo):** «1 reanimación(es) personal(es)» → singular/plural.

**Lo que funciona:** la propiedad se comunica con texto («ACTIVO», amarillo) además de color; una sola barra de estado resume stock, x2 y Puro; los rechazos del servidor se explican en la interfaz (2 s) y no en alerts; PIÑAS/ROBUX son pestañas de 44 px con estado activo amarillo y texto oscuro; los precios van en amarillo junto al botón; el panel de reanimación aparece solo con CAÍDO y se retira con Sano; el Modo Puro se explica en el propio botón («Modo Puro: sin reanimación de pago») y apaga la ventaja de la linterna en vivo; safe area en ambos paneles; salidas claras (VOLVER y el menú ESC de Roblox).

**Pendiente para fase 6 (pulido móvil):** botón Modo Puro de 164×42 px y panel de reanimación de 320 px sin `UIScale` (se recortan en pantallas de menos de 320); tarjetas ROBUX a escala 0,62 con objetivos por debajo de 44 px; panel de la tienda de 500×440 en viewports cortos; la tienda no recibe la lista de `comprados`, así que tras reentrar los cosméticos ya comprados muestran COMPRAR hasta pulsarlos (el servidor re-equipa gratis). `PolicyService` ya se consulta en la tienda de Piñas y el catálogo no tiene compras aleatorias de pago.

**Veredicto:** cumple el «Hecho cuando» de la fase 5 en Studio — pases y productos con estado, entrega idempotente, reanimación personal con límite por partida y Modo Puro efectivo — con deuda táctil acotada para la fase 6. Queda bloqueado por el usuario: publicar el place, crear pases y productos en el Creator Dashboard, poner sus IDs y `Activo=true`, y probar una compra real de Robux.

---

## Fase 6 — audio, subtítulos, móvil, accesibilidad, telemetría y localización (2026-10-28)

Revisión con la skill apple-design de `src/client/AudioService.client.lua`, `src/client/Subtitulos.client.lua`, `src/client/Acciones.lua`, `src/client/Accesibilidad.client.lua`, el selector ES/EN de `src/client/MenuAjustes.client.lua` y los popups de `src/client/HudPuntos.client.lua` / `HudPinas.client.lua` (set siempre-necesario + feedback, motion, settings, accessibility y layout). Evidencia: capturas `fase6-ajustes-es` y `fase6-ajustes-en` (cambio de idioma en vivo sobre ajustes, HUD y ranking), consulta de estado de los 8 popups (texto vacío y trazo transparente en reposo), `[Telemetria] activa: embudo PrimeraPartida con 4 pasos`, `AnalyticsService: LogFunnelStepEvent event fired.` y consola sin errores nuevos.

**Resuelto durante la revisión**

- **P0 · Popups fantasma en el HUD (crítico visual):** los 8 `TextLabel` del pool nacían con el texto por defecto «Label» y un `UIStroke` marrón visible al 100 %, dibujando corchetes sobre el cielo. Arreglo: `Text = ""` y `Transparency = 1` al crear, y en HudPuntos el trazo se desvanece con su propio tween cancelable (`tweenTrazo:Cancel()`); en HudPinas se añadió la cancelación que faltaba. Verificado: todos los slots en reposo quedan `Text='' Transparencia=1 Trazo=1` y «Piñas: 35» actualiza sin fantasmas.
- **P1 · Eco de subtítulos:** dos eventos casi seguidos repetían el mismo texto; se deduplica en menos de 1 s y cada aviso renueva el token de visibilidad.

**Deuda documentada (no bloquea la fase)**

- **M1 · Subtítulos con temporizador (medio):** 2,5 s fijos; `accessibility.md › Cognitive` pide minimizar elementos que se autodescartan por tiempo porque quien necesita más tiempo los pierde. Mitigación actual: se puede desactivar en Ajustes y cada sonido vuelve a mostrarlo; recomendación para la fase 7: 3,5–4 s o persistir hasta el siguiente aviso.
- **M2 · Escala de texto 100–140 % (medio):** `accessibility.md › Vision` recomienda hasta 200 %; ampliar más exige reflujo real (los paneles están posicionados en píxeles). `shortcut:` registrado en Accesibilidad; 140 % ya cubre el mínimo de watchOS y no rompe ninguna UI verificada.
- **M3 · Controles táctiles no escalan (medio):** `Acciones` usa `TextScaled` con `MaxTextSize` 15 y `Accesibilidad` omite `TextScaled`, así que SPRINT/LINTERNA/CÁMARA no crecen con la escala de texto; el objetivo táctil de 56×56 sí cumple. Arreglo barato: subir el tope del `UITextSizeConstraint` con `escalaTexto`.
- **B1 · Subtítulos bajo Ajustes (bajo):** Subtítulos tiene DisplayOrder 59 y Ajustes 60; con el panel abierto el subtítulo queda detrás, pero el sonido sigue y Ajustes no pausa. Es coherente con «el ajuste se ve donde se cambia».

**Lo que funciona:** el audio no es la única vía de la información —cada efecto crítico tiene subtítulo, popup y estado en HUD (`feedback.md › Best practices`, «Make sure all feedback is accessible»); los controles táctiles son 56×56 con 8 px de separación (por encima del 44×44 de `accessibility.md › Mobility`); safe area en subtítulos (IgnoreGuiInset → DeviceSafeInsets) y en la fila táctil; el selector ES/EN usa 44×44 y estado por luminancia (amarillo #FFC93C sobre marrón #3E2A18), no solo por tono; Ajustes mantiene 8 controles generales y poco frecuentes, con el ESC de Roblox como salida (`settings.md › Best practices`); «Reducir efectos» atenúa o silencia efectos no críticos sin quitar los avisos de peligro (`motion.md › Best practices`, movimiento opcional); el idioma cambia en vivo las 17 UIs sin recargar y el fallback es→clave nunca deja un hueco.

**Veredicto:** la capa de pulido hereda el ADN (madera, crema, amarillo) sin añadir plantilla nueva y cumple el «Hecho cuando» de la fase 6 en Studio — audio con subtítulos, controles táctiles, escala de texto, telemetría y ES/EN en vivo — con la deuda de reflujo acotada. Queda bloqueado por el usuario: subir los audios reales (hoy `Musica.id = 0` y efectos con `rbxasset://` provisionales) y publicar el place con API para que la telemetría y los DataStore sean reales.
