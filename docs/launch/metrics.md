# Métricas y telemetría · Heads Up! Mountain Mayhem

Versión 1.0 · 28-10-2026 · Fase 7 (lanzamiento y vivo)

Objetivo: dejar por escrito qué se mide, con qué fórmula se lee, dónde se consulta, quién lo revisa y qué decisión dispara cada métrica. Los objetivos de este documento son **hipótesis de trabajo**, no benchmarks de Roblox ni resultados de playtests. No hay datos de producción en el repo; cualquier cifra real debe salir del Creator Dashboard después de publicar.

Fuente de implementación: `src/server/TelemetriaService.lua`, `src/shared/Config/TelemetriaConfig.lua`, `src/server/PinasService.lua`, `src/server/TiendaService.lua`, `src/server/MonetizacionService.lua`, `src/server/MatchService.lua`, `src/server/MonsterService.lua` y `src/server/PlayerStateService.lua`.

## 1. Qué se mide hoy y cómo se envía

### 1.1 Arquitectura

`TelemetriaService` corre solo en el servidor y llama a `AnalyticsService` dentro de `pcall`. Si la API falla, avisa una vez y deja de intentarlo durante esa sesión; si `TelemetriaConfig.Activo` no es `true`, no se envía nada. Los nombres de evento se validan contra `TelemetriaConfig.Eventos`, de modo que un llamador no puede enviar texto libre como nombre de evento. Los pasos del embudo se emiten una sola vez por jugador y sesión de servidor, y la economía exige cantidad positiva, saldo numérico, tipo de transacción e `itemSku` no vacíos.

El identificador de sesión del embudo es `JobId + os.time() + random`; en Studio, `JobId` vacío se sustituye por `"studio"`. No contiene nombre, UserId ni texto del jugador.

La API de Analytics asocia el evento al `Player` que se pasa como argumento, pero el payload del código no incluye nombres, mensajes de chat ni identificadores legibles. Las reglas de privacidad se detallan en §6.

### 1.2 Eventos personalizados

| Evento | Cuándo se emite | Unidad | Qué mide | Qué no mide |
| --- | --- | --- | --- | --- |
| `PartidaInicio` | `MatchService.AlEmpezar`, al arrancar una partida o un reintento | 1 por jugador y partida | Inicios de jugador-partida | No lleva modo, roster ni si es la primera partida |
| `PartidaFinHistoria` | `MatchService.AlTerminar` con modo `historia` | 1 por jugador y partida cerrada | Cierres en Historia | No se emite si todos abandonan; no lleva duración ni motivo |
| `PartidaFinRapida` | `MatchService.AlTerminar` con modo `rapida` | 1 por jugador y partida cerrada | Cierres en Ronda rápida | Lo mismo que Historia |
| `PartidaFin` | `MatchService.AlTerminar` sin modo reconocible (respaldo) | 1 por jugador y partida cerrada | Cierres que no encajan en los dos eventos anteriores | No debería aparecer con el código actual |
| `Reanimacion` | `PlayerStateService.Reanimado` con un reanimador válido | 1 por reanimación | Reanimaciones cooperativas, incluido el rescate de El Doble | No incluye la reanimación personal de monetización |
| `Checkpoint` | `MatchService.CheckpointAlcanzado` | 1 por jugador y checkpoint | Checkpoints alcanzados en Historia | No lleva índice; no ocurre en Ronda rápida |
| `Rapto` | `MonsterService` al agarrar a la víctima, antes de la ventana de rescate | 1 por intento de rapto | Intentos de rapto | No confirma que el rapto se completara; un rescate posterior también deja el evento |
| `Compra` | `TiendaService` tras una compra exitosa con Piñas | 1 por compra | Compras del catálogo de Piñas | No cubre compras de Robux; no identifica compradores únicos |
| `ReanimacionPersonal` | `MonetizacionService` tras una reanimación personal exitosa, con stock o Piñas | 1 por uso | Uso de la reanimación de comodidad | No incluye reanimaciones cooperativas ni rescates |
| `TiendaAbierta` | `TiendaUI` al habilitarse la gui (botón del menú o ProximityPrompt del campamento), por el remoto `TelemetriaUI` | 1 por apertura (el servidor limita a 4 eventos de UI/s) | Aperturas de tienda | No mide el tiempo dentro ni si hubo compra |
| `TiendaPestanaPinas` | `TiendaUI` al entrar en la pestaña PIÑAS (clic real o pestaña de entrada 0,3 s tras abrir) | 1 por cambio | Interés por el catálogo de Piñas | Un clic en la pestaña ya activa no cuenta; clics a menos de 0,25 s pueden perderse |
| `TiendaPestanaRobux` | Igual que la anterior, pestaña ROBUX | 1 por cambio | Interés por la oferta de Robux | Igual que la anterior |
| `DatosFallo` | `DataService.AlFallar` cuando la lectura del perfil agota los reintentos | 1 por jugador y sesión | Sesiones que no persistirán | No cubre fallos de escritura ni el modo memoria de Studio |

`TelemetriaService` también expone `Economia` para Piñas; no hay un evento `CompraRobux` en el código actual.

### 1.3 Embudo `PrimeraPartida`

| Paso | Nombre | Cuándo se emite | Lectura correcta |
| --- | --- | --- | --- |
| 1 | `Lobby` | Al entrar al servidor, o al arrancar la telemetría si el jugador ya estaba | Usuarios que llegaron al lobby |
| 2 | `PrimeraEtapa` | Al empezar una partida; no hay una señal separada de entrada a la etapa | Usuarios que iniciaron una partida |
| 3 | `PrimerCheckpoint` | Al alcanzar un checkpoint; solo existe en Historia | Usuarios que llegaron a un checkpoint |
| 4 | `PartidaCompletada` | Al cerrar la partida por caída de todos (`AlTerminar`) | Usuarios que cerraron una partida, no necesariamente que la ganaran |

Dos advertencias de lectura:

- **El paso 3 se salta en Ronda rápida.** Roblox documenta que, si se registra un paso posterior sin el anterior, el anterior se completa automáticamente. Como Ronda rápida no tiene checkpoints pero sí emite el paso 4, el embudo puede inflar `PrimerCheckpoint`. Para la tasa de checkpoints se usa el evento `Checkpoint`, no el paso 3.
- **El paso 4 no es una victoria.** `MatchService` cierra la partida cuando todos caen; hoy no hay condición de meta ni evento de victoria. `PartidaCompletada` significa «partida cerrada», no «partida ganada».

El embudo es por usuario, no por partida: Roblox cuenta la primera ocurrencia de cada paso y aplica la sesión de embudo. Los eventos personalizados sí son por jugador-partida.

### 1.4 Economía de Piñas

| Flujo | `transactionType` | `itemSku` | Cuándo | Cantidad |
| --- | --- | --- | --- | --- |
| Fuente | `Partida` | `pinas_partida` | Al cerrar la partida, después de calcular `floor(distancia/10)`, el bonus de récord y el multiplicador x2 | Piñas ganadas, positivas |
| Sumidero | `Tienda` | `item.id` del catálogo | Tras una compra exitosa con Piñas | Precio del item, positivo |

La moneda declarada es `Pinas`. El saldo que se envía es el total después de la transacción. `pinas_x2` es un producto de Robux que multiplica la fuente; no se registra como una fuente de Piñas. La tienda de Piñas no tiene compras aleatorias; el catálogo actual va de 20 a 120 Piñas (`TiendaConfig`).

`LogEconomyEvent` se llama solo si la compra o la ganancia ya se completó; el código no registra intentos fallidos. Eso es correcto para el panel, pero significa que la economía no mide fricción de compra ni clics rechazados.

### 1.5 Límites y comportamiento de la plataforma

Según la documentación oficial de Analytics:

- Los eventos se envían solo desde el servidor y en places publicados; el panel no agrega eventos de Studio.
- Las gráficas suelen tardar hasta 24 h en aparecer; `View Events` muestra una lista casi en tiempo real.
- Los eventos se conservan 90 días desde la última recepción.
- Límite global de 120 + 20 × CCU solicitudes por minuto.
- Hasta 100 eventos personalizados, 10 embudos con 100 pasos, 5 monedas y 3 campos personalizados por evento; tras 8.000 valores únicos, el resto se agrupa como «Other».
- El panel de Analytics puede exigir un mínimo de actividad (la documentación del dashboard menciona más de 10 DAU y 10 horas de juego durante 7 días consecutivos); en un soft launch pequeño puede tardar en habilitarse.

## 2. KPIs, fórmulas y objetivos iniciales

### 2.1 Unidad de medida

`PartidaInicio` y los cierres (`PartidaFinHistoria`, `PartidaFinRapida` y el respaldo `PartidaFin`) son eventos **por jugador y partida**, no por servidor. Por eso:

- «por jugador-partida» = denominador `PartidaInicio`.
- Para estimar «por partida de servidor» haría falta el tamaño del roster, que hoy no se instrumenta. No se debe dividir por 8 ni por el aforo máximo.
- Las tasas de embudo son por usuario, no por partida.

Los objetivos marcados **H** son hipótesis iniciales. Se inspiran en la intención de diseño (rondas de 5–8 min, 2–8 jugadores, 2 raptos máximos, checkpoints cada 80 studs en una etapa de 220, precios de 20–120 Piñas) y en la necesidad de tener una primera referencia operativa. No son datos históricos ni promesas externas.

### 2.2 Tabla de KPIs

| KPI | Definición y fórmula | Fuente actual | Objetivo inicial (H) | Alarma | Decisión que dispara |
| --- | --- | --- | --- | --- | --- |
| Retención D1 | Usuarios nuevos de una cohorte que vuelven al día siguiente / usuarios nuevos de esa cohorte | Creator Dashboard → Analytics → Retention | ≥ 8–10 % | < 5 % con ≥200 usuarios nuevos y 7 días de cohorte | Revisar onboarding, lobby y primera partida; mirar embudo 1→2 |
| Retención D7 | Usuarios nuevos que vuelven a los 7 días / usuarios nuevos de esa cohorte | Creator Dashboard → Retention | ≥ 2–3 % | < 1,5 % | Revisar contenido, rejugabilidad y rondas rápidas |
| Tasa de cierre | `(PartidaFinHistoria + PartidaFinRapida + PartidaFin) / PartidaInicio` | Eventos personalizados | ≥ 0,80 | < 0,60 | Investigar desconexiones, abandonos y bloqueos; revisar consola y duración |
| Tasa de reintento | `max(0, PartidaInicio / cierres − 1)`; si cada partida cerrada se reintenta una vez, vale 1 | Eventos personalizados | ≥ 0,25 | < 0,10 | Revisar dificultad, FinScreen y tiempo hasta REINTENTAR; no hay evento dedicado de REINTENTAR |
| Tasa de finalización (embudo) | Usuarios con paso 4 / usuarios con paso 2 del embudo `PrimeraPartida` | Creator Dashboard → Funnel | ≥ 0,70 | < 0,50 | Revisar estabilidad y duración; recordar que el paso 4 es «partida cerrada», no victoria |
| Checkpoints por jugador-partida | `Checkpoint / PartidaInicio` | Eventos personalizados | ≥ 1,0 | < 0,5 | Revisar longitud de etapa, frecuencia de peligros y posición de checkpoints |
| Reanimaciones cooperativas por jugador-partida | `Reanimacion / PartidaInicio` | Eventos personalizados | ≥ 0,8 | < 0,3 | Revisar visibilidad del prompt, cooperación y dificultad de los peligros |
| Raptos por jugador-partida | `Rapto / PartidaInicio`; es un intento, no un rapto completado | Eventos personalizados | 0,1–0,3 (aprox. 0,8–2,4 por partida de 8) | 0 en 20 partidas seguidas o > 0,5 | Revisar aparición/fases de El Doble si es 0; revisar frustración y `MaxRaptos` si es alto |
| Compras de Piñas por jugador-partida | `Compra / PartidaInicio`; no son compradores únicos | Eventos personalizados | 0,01–0,03 (1–3 compras por 100 jugador-partidas) | < 0,0025 | Revisar visibilidad de tienda, precios, saldo y estado de «comprado» |
| Conversión Robux | Usuarios que pagan / DAU, según Monetization | Creator Dashboard → Monetization → Overview | ≥ 0,5 % | < 0,1 % | Revisar valor percibido y oferta; no se puede unir a `PartidaInicio` con los eventos actuales |
| Piñas ganadas por jugador | Suma de `amount` fuente / DAU | Creator Dashboard → Economy | Referencia inicial: 20–60 Piñas por jugador activo al día | Caída > 50 % respecto a la media de 7 días | Revisar fórmula de ganancia, récord y multiplicador |
| Piñas gastadas por jugador | Suma de `amount` sumidero / DAU | Creator Dashboard → Economy | Ratio sumidero/fuente 0,3–0,8 | Ratio < 0,15 (inflación) o > 1,0 (drenaje) | Añadir sumideros, ajustar precios o dar más fuentes |
| Sesiones por jugador | Sesiones / DAU si el panel las expone; proxy actual: `PartidaInicio / DAU` | Creator Dashboard → Engagement y eventos | ≥ 1,3 | < 1,05 | Revisar fricción de primera sesión y tiempo hasta la primera partida |
| Tiempo medio de partida | `suma(stats.tiempo) / cierres`; hoy no se envía la duración | Proxy: Average session time del dashboard | 5–12 min | < 3 min o > 18 min | Revisar dificultad, ritmo de etapa y duración de la ronda rápida |

Notas de lectura:

- La **tasa de cierre** baja si un jugador se va a mitad de partida: no recibe `PartidaFin`. No es lo mismo que un crash.
- La **tasa de reintento** se contamina con los primeros inicios de cada jugador y con partidas abandonadas. Se lee en ventanas de 7 días, no en un día aislado.
- **Checkpoints, reanimaciones y raptos** se expresan por jugador-partida. Un valor de 1,0 en checkpoints significa que, en promedio, cada jugador-partida alcanza un checkpoint; no significa que cada servidor haya alcanzado uno.
- **Rapto** se emite al agarrar, antes del rescate; si hay muchos rescates, la métrica parece más alta que los raptos completados. El código no tiene un evento de rescate exitoso.
- **Compra** es solo Piñas. Las compras de Robux se leen en Monetization, no en el evento `Compra`; no se deben sumar ambos como si fueran la misma moneda.
- Los **cierres** llegan separados por modo (`PartidaFinHistoria` / `PartidaFinRapida`). `PartidaFin` queda como respaldo si falta el modo: no sumar los tres como si fueran eventos distintos de una misma partida.
- **TiendaAbierta** y **TiendaPestana\*** llegan por el remoto `TelemetriaUI` con lista blanca y límite de un evento cada 0,25 s: sirven para proporciones de interés, no para contar clics exactos.
- **Tiempo medio de partida** no es calculable con los eventos actuales porque los cierres envían valor 1, sin duración. El promedio de sesión del dashboard es un proxy, no la duración de la partida.

### 2.3 Cómo se calibran las hipótesis

1. Se publica el soft launch y se esperan 14 días o 200 usuarios nuevos, lo que llegue después.
2. Se usan ventanas de 7 días; no se cambia un umbral por un día malo ni por menos de 100 usuarios en la ventana.
3. Se comparan cohortes antes/después de cada cambio; el panel permite filtrar la fecha de inicio.
4. Cada cambio de objetivo se anota en el registro de lanzamiento con fecha, motivo y datos que lo justifican. Este documento no se reescribe para que «parezca» que se cumplió.
5. Si el panel aún no tiene volumen, se usan `View Events` y los eventos personalizados para QA, no para conclusiones de retención.

## 3. Cómo consultarlas en Creator Dashboard

Ruta general: Creator Dashboard → experiencia → **Analytics**. Los filtros (`Filter By`) se aplican a todas las páginas hasta que se desactivan; incluyen fecha, plataforma, sistema operativo, país, idioma, edad, estado de pago, fuente de adquisición y actividad. La documentación del panel indica que las gráficas pueden requerir un mínimo de actividad y que la exportación de ventas se actualiza cada 48 h.

| Qué se quiere ver | Dónde | Qué se mira | Cadencia |
| --- | --- | --- | --- |
| Salud general | Analytics → Overview | DAU, retención, engagement, monetización, errores de la experiencia | Diaria los primeros 14 días; semanal después |
| Retención | Analytics → Retention | Cohortes D1/D7/D30; la cohorte se agrupa por fecha de primera partida; D7/D30 llegan con retraso | Semanal; D30 mensual |
| Tiempo de sesión | Analytics → Engagement | Average session time = tiempo total / número de sesiones; New User First Session Retention | Diaria/semanal |
| Dinero real | Analytics → Monetization → Overview | Conversion rate = pagadores / DAU; paying users; ARPPU; ARPDAU; ingresos por productos, pases y suscripciones | Semanal; revisar tras cada cambio de precio |
| Piñas | Analytics → Economy | Top sources, top sinks, average wallet balance, total por categoría; moneda `Pinas` | Diaria/semanal |
| Embudo | Analytics → Funnel → `PrimeraPartida` | Usuarios por paso 1–4; filtros por cohorte; advertencia de cambio de pasos | Semanal; no usar el paso 3 en Ronda rápida |
| Eventos crudos | Analytics → Custom/Explore → `View Events` | Conteo de `PartidaInicio`, `PartidaFin`, `Reanimacion`, `Checkpoint`, `Rapto`, `Compra`, `ReanimacionPersonal`; lista casi en tiempo real | Diaria durante el soft launch; útil para QA |
| Ventas y recibos | Monetization → Developer Products/Passes; registro de ventas | Productos vendidos, ingresos, reembolsos; no sustituye al log del servidor para entrega | Semanal y tras cada compra de prueba |

Flujo operativo recomendado:

1. **Diario (10–15 min, primeros 14 días):** errores/crash, compras y recibos, `PartidaInicio` vs `PartidaFin`, embudo 1→2, economía fuente/sumidero, consola del servidor del build. Lo revisa el coordinador de lanzamiento con el responsable técnico de guardia.
2. **Semanal:** D1/D7, tasa de reintento, checkpoints y reanimaciones por jugador-partida, raptos, conversión de Piñas y Robux, ratio sumidero/fuente. Lo revisan el diseñador de juego y el responsable técnico.
3. **Mensual:** D30, ARPDAU/ARPPU, cohortes, decisiones de contenido y precios. Lo revisa el creador con el coordinador.
4. **Antes de cada publicación:** smoke de QA, `View Events` de las últimas 24 h y una captura del panel de economía/embudo. Si no hay datos por falta de volumen, se anota como «sin señal», no como cero.

## 4. Decisiones que dispara cada métrica

| Señal | Lectura probable | Primera decisión | Segunda decisión |
| --- | --- | --- | --- |
| D1 bajo | La primera sesión no engancha o el lobby/primera etapa frustra | Medir embudo 1→2 y tiempo hasta la primera partida; revisar tutorial/avisos | Suavizar la primera etapa o acortar el lobby |
| D7 bajo | El bucle no da razones para volver | Revisar rondas rápidas, progresión de Piñas y cosméticos | Añadir contenido/recompensas o eventos |
| Tasa de cierre baja | Abandonos, desconexiones o partidas que no terminan | Revisar consola, crashes, duración y condición de fin | Corregir estabilidad o acortar la partida |
| Reintento bajo | El FinScreen no invita a repetir o la dificultad castiga | Revisar tiempo hasta REINTENTAR, stats y balance | Ajustar peligros, reanimación o checkpoints |
| Finalización de embudo baja | Pocos usuarios llegan a cerrar una partida | Revisar paso 2→4 y estabilidad | Revisar onboarding y duración |
| Checkpoints bajo | Los jugadores caen antes del primer checkpoint | Revisar separación de checkpoints y avisos de peligro | Bajar dificultad inicial o mover el checkpoint |
| Reanimaciones bajas | El prompt no se descubre o el grupo no coopera | Revisar visibilidad del prompt, subtítulos y HUD | Reforzar la señal de cooperación o acortar la distancia |
| Raptos en 0 | El Doble no aparece, la partida dura menos de 45 s o las fases se abortan | Revisar logs `[Doble]` y duración de partida | Ajustar `RetardoAparicion` o el modo/bioma |
| Raptos altos | El Doble frustra o el grupo se separa demasiado | Revisar rescates, `MaxRaptos` y `EnfriamientoRetirada` | Ajustar avisos/contramedidas |
| Compras de Piñas bajas | La tienda no se ve, los precios no convencen o el saldo no alcanza | Revisar visibilidad, precios y saldo medio | Ajustar economía o catálogo |
| Conversión Robux baja | La oferta no se percibe valiosa | Revisar datos de Monetization y la propuesta de valor | Ajustar precio/contenido o retirar una oferta |
| Ratio sumidero/fuente bajo | Inflación de Piñas; no hay nada que comprar | Añadir cosméticos/sumideros o subir precios | Revisar la fuente de Piñas |
| Ratio sumidero/fuente alto | Drenaje; los jugadores no pueden permitirse el catálogo | Bajar precios o aumentar fuentes | Revisar bonos de récord |
| Sesiones por jugador bajas | Fricción de entrada o sesiones muy cortas | Revisar tiempo hasta la primera partida y errores de arranque | Revisar tutorial/lobby |
| Tiempo de partida bajo | Dificultad excesiva o bugs de muerte | Revisar peligros y reanimación | Ajustar avisos, daño o checkpoints |

## 5. Qué falta instrumentar y por qué no está ahora

La v1 prioriza el bucle, el dinero y la estabilidad. Añadir eventos tiene coste de mantenimiento y límites de cardinalidad; estos son los huecos conscientes:

| Hueco | Estado actual | Por qué no está | Propuesta |
| --- | --- | --- | --- |
| Tutorial completado | No hay tutorial implementado; solo el aviso de imitador en el chat | El tutorial no forma parte del slice actual | Evento `TutorialPaso` con paso y versión, o paso 0 del embudo |
| Abandono en lobby | Se aproxima con embudo 1→2 | No hay evento de salida ni motivo | `LobbySalida` con motivo bucket (salió, timeout, lleno) |
| Desconexiones | No hay evento; `[Match] partida abandonada` es un log | El servidor no distingue crash, cierre de cliente o pérdida de red | `Desconexion` con fase bucket y duración bucket |
| Victoria / motivo de fin | `PartidaFin` no lleva motivo; hoy no hay condición de victoria | La v1 cierra por caída de todos | `PartidaFin` con `motivo` bucket (`todosCaidos`, `victoria` futuro, `abandono`) |
| Rescate de El Doble | `Rapto` se emite al agarrar; no hay evento de rescate exitoso | El rescate se resolvió como reanimación cooperativa | `Rescate` o `RaptoCompletado` con resultado bucket |
| Compra de Robux | No hay `CompraRobux`; solo el recibo y Monetization | `ProcessReceipt` se implementó después de la telemetría y no se instrumentó | Evento tras entrega, con producto y precio bucket; o depender del panel de Monetization |
| Duración, modo y roster | `PartidaFin` no lleva campos | Los eventos se diseñaron como contadores; añadir campos exige cambiar el contrato | Campos personalizados: `modo` (2 valores), `duracion` bucket, `roster` bucket |
| Rendimiento y FPS | No hay telemetría de cliente | Privacidad y coste; el spike S4 midió en Studio | Muestreo de FPS bucket y errores de cliente, sin datos personales |
| Impresiones de tienda | No hay evento de apertura ni de item visto | La tienda se instrumentó solo al comprar | `TiendaAbierta` y `ItemVisto` con id de catálogo, si el volumen lo justifica |
| Compradores únicos | `Compra` cuenta compras, no personas | El evento no lleva un flag de primera compra | Campo `primeraCompra` booleano o evento `PrimeraCompra` |
| Ajustes persistidos | `Settings` no se guarda en DataStore | No estaba en el contrato de fase 5 | Clave `ajustes` en DataService; no es telemetría, es producto |
| Idioma/modo en retención | El panel filtra por idioma/plataforma, no por modo | No hay campo de modo en los eventos | Campo `modo` en `PartidaInicio` y `PartidaFin` |

Antes de añadir un evento se comprueba que no se pueda responder con los existentes, que el nombre sea estable y que no se superen los 100 eventos ni la cardinalidad de campos. Un evento que no cambia una decisión no se instrumenta.

## 6. Privacidad y moderación

Reglas de diseño, alineadas con el código y con las políticas de Roblox:

- **Solo servidor.** Los eventos se envían desde `TelemetriaService`; el cliente no llama a Analytics. La documentación exige servidor y place publicado.
- **Sin datos personales en el payload.** No se envían nombres, `DisplayName`, UserId, texto de chat, IP, país, edad ni identificadores de dispositivo. El `Player` que recibe la API es la asociación que Roblox necesita para agregar; no se convierte en un campo de texto.
- **Sin texto libre.** Los nombres de evento se validan contra `TelemetriaConfig.Eventos`; la economía valida `transactionType` e `itemSku` contra valores del catálogo o constantes. Nunca se envía el mensaje de un jugador.
- **Identificador de sesión sin PII.** `JobId + tiempo + random`; en Studio, `"studio"`. No se usa el UserId.
- **Campos personalizados futuros.** Máximo 3 por evento; usar buckets (modo, duración, roster, motivo) y nunca valores de alta cardinalidad. El panel agrupa como «Other» después de 8.000 valores únicos.
- **Moderación.** El chat falso pasa por `TextService:FilterStringAsync` por receptor; la telemetría no se usa para moderar ni para identificar jugadores. Los reportes y la moderación siguen los canales de Roblox.
- **Acceso y retención.** Los datos se consultan en Creator Dashboard con los permisos de la cuenta o del grupo; Roblox conserva los eventos 90 días desde la última recepción. No se exportan a servicios externos.
- **Cumplimiento.** Se aplican la Política de Privacidad y las Normas de la Comunidad de Roblox; si se añade un campo nuevo, se revisa antes de publicarlo.

Enlaces de privacidad y moderación:

- Política de Privacidad y Cookies: https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy
- Normas de la Comunidad: https://about.roblox.com/community-standards

## 7. Estado actual y bloqueos

La telemetría está implementada y el `skill-log` registra que en Studio se vio `[Telemetria] activa: embudo PrimeraPartida con 4 pasos` y `AnalyticsService: LogFunnelStepEvent event fired.` No hay datos agregados de producción en el repo y no se presentan cifras reales. Para que estas métricas existan de verdad faltan acciones del creador: publicar el place con API Services, crear pases/productos y poner sus IDs, activar `MonetizacionConfig.Activo`, subir los audios, conseguir una audiencia de soft launch y ejecutar las compras reales con una cuenta de prueba. Hasta entonces, los KPIs son un plan de medición, no un resultado.

## 8. Enlaces oficiales

- AnalyticsService: https://create.roblox.com/docs/reference/engine/classes/AnalyticsService
- AnalyticsService:LogEconomyEvent: https://create.roblox.com/docs/reference/engine/classes/AnalyticsService/LogEconomyEvent
- AnalyticsService:LogFunnelStepEvent: https://create.roblox.com/docs/reference/engine/classes/AnalyticsService/LogFunnelStepEvent
- Tipos de evento: https://create.roblox.com/docs/production/analytics/event-types
- Eventos personalizados: https://create.roblox.com/docs/production/analytics/custom-events
- Eventos de embudo: https://create.roblox.com/docs/production/analytics/funnel-events
- Eventos de economía: https://create.roblox.com/docs/production/analytics/economy-events
- Retención: https://create.roblox.com/docs/production/analytics/retention
- Engagement: https://create.roblox.com/docs/production/analytics/engagement
- Monetización: https://create.roblox.com/docs/production/analytics/monetization
- Dashboard de Analytics: https://create.roblox.com/docs/production/analytics/analytics-dashboard
- Data stores: https://create.roblox.com/docs/cloud-services/data-stores
- Límites de DataStore: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- PolicyService: https://create.roblox.com/docs/reference/engine/classes/PolicyService
- TextService:FilterStringAsync: https://create.roblox.com/docs/reference/engine/classes/TextService/FilterStringAsync
- MarketplaceService.ProcessReceipt: https://create.roblox.com/docs/reference/engine/classes/MarketplaceService/ProcessReceipt
