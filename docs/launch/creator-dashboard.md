# Creator Dashboard · guía operativa de publicación y monetización

**Fecha:** 2026-10-28 · **Fase:** 7 · **Alcance:** publicar el place, crear pases y productos, activar la monetización, probar compras y leer Analytics/errores.
**Fuente de verdad:** `docs/PLAN.md` §3.3, §7 y §9; documentación oficial de Roblox citada en cada sección. Si una ruta del dashboard cambia, usar la raíz [create.roblox.com/docs](https://create.roblox.com/docs) y buscar por título.
**Documento hermano:** `docs/launch/soft-launch.md` (olas, checklist de lanzamiento y operación).

> Regla del proyecto: el código vive en `src/` y se sincroniza con Rojo. El MCP de Studio **no** edita scripts sincronizados. Los IDs y `Activo` se cambian en disco, se construyen con `rojo build` y se publican; no se parchean en Studio.

---

## 0. Antes de empezar: cuenta y bloqueos

### 0.1 Decisión de cuenta

**D5 (2026-10-26): cuenta personal de Pausiar.** No hace falta grupo para la v1; los servidores privados de pago funcionan en cuenta personal. Si en el futuro se migra a grupo, cambian los ingresos, los roles y los payouts.

| Tema | Cuenta personal (D5) | Grupo |
| --- | --- | --- |
| Dueño de la experiencia | La cuenta | El grupo |
| Ingresos | Robux en la cuenta personal | Balance del grupo; payouts y splits |
| Servidores privados | Funcionan; ingresos al dueño | Funcionan; reparto según configuración del grupo |
| Roles | No aplica | Roles con “Manage monetization”, “View group revenue” y “Manage and spend group revenue”; este último exige 2FA |
| DevEx | 13+, 30.000 Robux ganados, email verificado, datos fiscales | Los payouts de grupo cuentan si son ganancias legítimas; el owner del grupo gestiona impuestos |
| Soporte | Una sola cuenta | Varias personas; hace falta gobernanza |

Fuentes: [Groups](https://create.roblox.com/docs/projects/groups), [Private servers](https://create.roblox.com/docs/production/monetization/private-servers), [DevEx](https://create.roblox.com/docs/production/monetization/developer-exchange).

### 0.2 Requisitos de cuenta y release

La doc de publicación de 2026 es más estricta que la de años anteriores. Antes de la beta cerrada, verificar en el dashboard:

- Cuenta en regla y con al menos **2 días** de antigüedad.
- Verificación de edad por estimación facial o ID gubernamental; la verificación por ID requiere 13+ ([Account verification](https://create.roblox.com/docs/production/publishing/account-verification)).
- 2FA activo.
- Para publicar a todos los públicos, la doc lista además: suscripción Roblox Plus/Premium durante 2 meses consecutivos **o** una tasa reembolsable, y pasar la evaluación con cuestionario completo y rating Minimal/Mild/Moderate. Para 16+ hay un camino más corto con age check y la primera pregunta del cuestionario.
- Hasta 5 juegos nuevos por día; places de hasta 100 MB ([Create and publish](https://create.roblox.com/docs/production/publishing/publish-games-and-places), [Place files](https://create.roblox.com/docs/projects/place-files)).

**Bloqueo real:** si la cuenta no cumple edad/ID/2FA/elegibilidad, la ola 1 no empieza. Confirmar el camino exacto en el dashboard antes de crear pases; los requisitos pueden cambiar y el dashboard es la autoridad final.

### 0.3 Estado actual del repo

| Elemento | Estado | Archivo |
| --- | --- | --- |
| `MonetizacionConfig.Activo` | `false` | `src/shared/Config/MonetizacionConfig.lua` |
| 5 pases | IDs `0`; 2 vendibles, 2 sin efecto, 1 suscripción | mismo archivo |
| 3 productos | IDs `0`; los 3 vendibles | mismo archivo |
| Tienda de Piñas | 8 cosméticos; funciona sin dashboard | `src/shared/Config/TiendaConfig.lua` |
| Telemetría | `Activo = true`; eventos y embudo definidos | `src/shared/Config/TelemetriaConfig.lua` |
| Audio | SFX `rbxasset://`; música `0` (silencio) | `src/shared/Config/AudioConfig.lua` |
| Datos | DataStore real no probado en producción; en Studio sin API degrada a memoria | `src/server/DataService.lua` |

---

## 1. Publicar o actualizar el place

1. Construir desde disco: `rojo build` (genera `build/HeadsUp.rbxlx`). Abrir ese build en Studio; no trabajar sobre una copia inyectada por el MCP.
2. En Studio: **File > Publish**. Se abre **Game details**.
3. Completar **Name**: `Heads Up! Mountain Mayhem`.
4. Subir **Icon** y **Thumbnail** (si ya existen); si no, se pueden añadir después en Configurations.
5. Elegir **Genre** y subgénero. Recomendación: Adventure > Story; alternativa Party & casual > Minigame. El género solo se puede cambiar una vez cada 3 meses ([Genres](https://create.roblox.com/docs/production/publishing/experience-genres)).
6. Pegar la descripción ES/EN. Borradores en `soft-launch.md` §2.1; el usuario los aprueba.
7. **Save**. Roblox asigna UniverseID y publica el place. La primera publicación crea la experiencia.
8. Para actualizar: editar en disco, `rojo build`, abrir, **File > Publish**, escribir notas de versión y publicar. El place anterior queda en Version History.
9. Guardar una copia de respaldo: **File > Save to Roblox As** en un place separado, y conservar el `.rbxlx` de la versión publicada. No usar el respaldo para jugar.
10. Confirmar que el place pesa menos de 100 MB y que abre en Studio sin errores. El build actual pesa 364 KB.

**Rutas de la ficha**

| Ajuste | Ruta |
| --- | --- |
| Nombre, descripción y género | Publish settings > Game details |
| Icono | Configurations > Places > Basic Settings > Icon |
| Thumbnails | Configurations > Places > Thumbnails |
| Madurez | Publish settings > Content rating |
| Idiomas | Audience > Localization |
| Acceso, dispositivos y servidores privados | Audience > Access Settings |
| Versiones | Configurations > Places > Version History |

**Especificaciones**

- Icono: cuadrado, al menos 512×512; debe leerse a ~150×150 y pasar moderación ([Icons](https://create.roblox.com/docs/production/publishing/experience-icons)).
- Thumbnails: 16:9, 1920×1080, menos de 3 MB; hasta 10 imágenes o vídeos; los vídeos deben ser gameplay real ([Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)).
- Descripción: la primera frase resume el juego; evitar spam de palabras clave. No prometer reembolsos, aleatorios ni funciones que no existan.

**Madurez, idiomas, dispositivos y privacidad:** completar el cuestionario (violencia de dibujos animados, miedo por El Doble, sin sangre realista, sin lenguaje fuerte, sin compras aleatorias), elegir origen/soportado ES/EN, activar solo dispositivos probados y desactivar la descarga del place. El detalle está en `soft-launch.md` §2.

---

## 2. Habilitar Studio Access to API Services

1. En Studio: **File > Experience Settings**.
2. Pestaña **Security**.
3. Activar **Enable Studio Access to API Services**.
4. **Save**.

**Para qué sirve:** permite que Studio use DataStore, OrderedDataStore y Analytics reales. Sin el toggle, el juego degrada a memoria (`[Datos] Studio sin acceso a API: modo memoria`), Analytics avisa y el ranking cae a fallback. Es el comportamiento esperado en desarrollo.

**Advertencia:** la doc de DataStore dice explícitamente que **no se active en juegos live**, porque Studio usa los mismos DataStores y puede sobrescribir datos reales. Activar solo en un place de prueba o en una copia; nunca en producción mientras se prueba ([Data stores](https://create.roblox.com/docs/cloud-services/data-stores)).

En producción no hace falta este toggle para que DataStore funcione; el toggle es solo para Studio. Si se activa por error en live, desactivarlo y no guardar datos de prueba.

---

## 3. Crear los pases (Game Passes)

**Requisito:** la experiencia debe estar publicada y accesible. Sin publicar, el dashboard no deja crear pases ([Passes](https://create.roblox.com/docs/production/monetization/passes)).

1. Ir a [Creations](https://create.roblox.com/dashboard/creations) y abrir la experiencia.
2. En la navegación izquierda: **Monetization > Passes**.
3. **Create pass**.
4. Subir icono (recomendado; si no se sube, Roblox muestra uno por defecto): máximo 512×512, JPG/PNG/BMP; mantener el detalle importante dentro del recorte circular.
5. Escribir nombre y descripción; elegir categoría (sirve para organizar la tienda de Roblox; la UI propia lee `MonetizacionConfig`, no la categoría).
6. Fijar el precio en Robux. Usar el precio hipotético del config o el que apruebe el usuario; deben coincidir.
7. **Create pass**.
8. Copiar el ID: hover sobre el pase > **⋯** > **Copy Asset ID**.
9. Pegar el ID en `paseId` del config correspondiente. No usar IDs de otra experiencia: las ventas cruzadas están desactivadas desde el 30 de mayo de 2026.
10. Si se quiere vender fuera del juego, marcar **Listed** en **Monetization > Shop**; para el prompt dentro del juego no es obligatorio. El pase puede mostrar el icono por defecto de Roblox; se recomienda subir uno propio y cumplir las reglas de la tienda.

**Qué crear exactamente**

| Config id | Nombre recomendado en dashboard | Precio hipotético | ID | ¿Crear ahora? |
| --- | --- | --- | --- | --- |
| `ranuras_ropa` | Ranuras de camiseta (3 → 9) | 149 Robux | 0 | Sí |
| `linterna_pro` | Linterna Pro (+15 % de cono) | 149 Robux | 0 | Sí |
| `botas_agarre` | Botas de agarre (+8 % de adherencia) | 149 Robux | 0 | No: no hay efecto en v1 (`disponible = false`) |
| `mochila_pro` | Mochila Pro (+1 espacio de inventario) | 199 Robux | 0 | No: no hay inventario en v1 (`disponible = false`) |
| `club_montanero` | Club Montañero | 0 | 0 | No: es suscripción, no pase; no está implementada |

**No crear los 3 pases no vendibles para “completar” la lista.** Un pase sin efecto es un producto engañoso. El servidor ya los bloquea con `disponible = false`; si se reservan IDs, dejarlos fuera de venta y documentarlo, pero la recomendación es crearlos cuando exista el efecto.

**Pases y recibos:** los pases no usan `ProcessReceipt`; la propiedad se consulta con `UserOwnsGamePassAsync` al entrar y después del prompt. El cliente no concede nada. Si un jugador compra y no ve el efecto, reentrar o usar el botón de reclamar; el servidor revalida.

---

## 4. Crear los Developer Products

**Requisito:** experiencia publicada y accesible ([Developer Products](https://create.roblox.com/docs/production/monetization/developer-products)).

1. Abrir la experiencia en [Creations](https://create.roblox.com/dashboard/creations).
2. **Monetization > Developer Products**.
3. **Create developer product**.
4. Subir icono: máximo 512×512, JPG/PNG/BMP.
5. Nombre, descripción y categoría.
6. Precio en Robux: mínimo 1, máximo 1.000.000.000.
7. **Save Changes**.
8. Copiar el ID: hover > **⋯** > **Copy Asset ID**.
9. Pegar en `productoId` del config.
10. Opcional: **Listed** si se quiere vender fuera del juego. Si se lista, el reporte de ProcessReceipt debe estar limpio antes de abrir.

**Qué crear exactamente**

| Config id | Nombre recomendado en dashboard | Precio hipotético | ID | ¿Crear ahora? |
| --- | --- | --- | --- | --- |
| `pinas_x2` | Doble de Piñas (30 min) | 49 Robux | 0 | Sí |
| `reanimacion_personal` | Reanimación personal | 25 Robux | 0 | Sí |
| `pack_sombreros` | Pack de sombreros | 199 Robux | 0 | Sí |

**Productos y recibos:** los productos sí requieren `ProcessReceipt`. El handler ya existe en `src/server/MonetizacionService.lua` y se registra una sola vez; no añadir otro script que asigne `MarketplaceService.ProcessReceipt`. El reporte del dashboard aparece si un producto listado no tiene un handler que conceda; se corrige publicando y marcando **Mark as fixed**.

---

## 5. Copiar IDs y activar la monetización

1. Abrir en disco `src/shared/Config/MonetizacionConfig.lua`.
2. Rellenar los IDs de los 2 pases vendibles y los 3 productos. Ejemplo de forma, no de valor:
   ```lua
   paseId = <ID_DEL_PASE>,
   productoId = <ID_DEL_PRODUCTO>,
   ```
3. Dejar `disponible = false` en `botas_agarre`, `mochila_pro` y `club_montanero`. No ponerles IDs reales si no se van a vender.
4. Cambiar `MonetizacionConfig.Activo = true` **solo** cuando los 5 IDs vendibles estén puestos y probados.
5. `rojo build`, abrir el build y publicar. No editar el script en Studio.
6. Revisar la consola del servidor: debe aparecer `[Monetizacion] activo: 5 pases, 3 productos, Activo=true` (el número de pases es el total del config, incluidos los no vendibles).
7. Entrar a la experiencia y abrir la pestaña ROBUX: los 2 pases y 3 productos deben mostrar precio y botón; los no vendibles deben decir “PRÓXIMAMENTE” y estar deshabilitados.
8. Si algo falla, volver a `Activo = false`, publicar y revisar IDs/precios antes de reintentar.

**Comportamiento esperado**

- `Activo = false`: `ComprarRobux` responde “Disponible al publicar el juego” y no abre prompt.
- `Activo = true` con ID 0: tampoco abre prompt; el servidor exige ID > 0.
- `disponible = false`: “No disponible en esta versión” / “PRÓXIMAMENTE”.
- Pase comprado: el efecto se aplica tras revalidar; si no aparece, reentrar o reclamar.
- Producto comprado: la entrega ocurre en `ProcessReceipt`; el prompt no entrega nada por sí solo.
- `ProcessReceipt` no comprueba `Activo`: un producto listado se sigue entregando aunque `Activo = false`. Para detener ventas externas, retirar el producto de la venta o cambiar el handler; `Activo` solo frena los prompts dentro del juego.

**Precios**

- `precioRobux` del config es una hipótesis del plan (`PLAN.md` §7.2), no un precio definitivo. El precio real se fija en el dashboard; si no coinciden, la UI miente. Actualizar ambos o cambiar el config.
- Roblox puede aplicar precio regional y optimización de precios; el jugador puede ver un importe distinto. No prometer un precio único.
- Los pases nuevos pueden tener precio regional por defecto; revisar el importe antes de anunciarlo.

---

## 6. Nombre, precio, descripción e icono de cada ítem

| Campo | Dónde | Regla |
| --- | --- | --- |
| Nombre | Create pass / Create developer product | Claro y honesto; debe coincidir con el nombre del config o la UI confundirá |
| Descripción | mismo formulario | Decir qué desbloquea y si es permanente (pase) o consumible (producto); no prometer ventajas que no existen |
| Icono | mismo formulario | 512×512 máximo, JPG/PNG/BMP; recorte circular en pases |
| Categoría | mismo formulario | Organiza la tienda de Roblox; no cambia la UI propia |
| Precio | mismo formulario | Pases: el que apruebe el usuario; productos: 1–1.000.000.000 Robux |
| Listed | Monetization > Shop | Solo si se vende fuera del juego; exige reporte de recibos limpio |
| Localización | Audience > Localization | Nombre/descripción por idioma si se quiere ficha ES/EN; el texto dentro del juego ya es ES/EN |

**Coherencia:** si el dashboard dice “Ranuras de camiseta (3 → 9)” y el config dice lo mismo, la UI y la ficha no se contradicen. Si se cambia el nombre en el dashboard, cambiarlo también en `MonetizacionConfig` y en `Strings.lua` si aparece en la UI.

---

## 7. Ventas, Robux y servidores privados

### 7.1 Dónde ver las ventas

- **Pases:** Monetization > Passes > Analytics. Permite ver los más vendidos y hasta 8 series; también ventas y ingresos netos ([Passes](https://create.roblox.com/docs/production/monetization/passes)).
- **Productos:** Monetization > Developer Products y Monetization > Shop; el detalle de ingresos está en Finances/Revenue.
- **Experiencia:** Analytics > Monetization para KPIs de negocio y datos de ventas descargables ([Monetization analytics](https://create.roblox.com/docs/production/analytics/monetization)).
- **Finances:** balance, payouts y obligaciones fiscales. La cuenta personal recibe Robux; el grupo recibe en su balance y reparte según roles ([Groups](https://create.roblox.com/docs/projects/groups)).

No hay una cifra de reparto que este documento pueda prometer: Roblox aplica su comisión y sus plazos vigentes; el desglose aparece en Finances.

### 7.2 Servidores privados

1. La experiencia debe ser pública.
2. **Audience > Access Settings**.
3. Activar **Allow private servers**.
4. Si se cobran, activar **Requires Robux** y fijar precio.
5. **Save Changes**.

Cambiar el precio cancela las suscripciones activas y avisa a los afectados. Los servidores privados no se combinan con paid access. El precio queda a decisión del usuario; el plan lo deja “a decidir” (`PLAN.md` §7.2) ([Private servers](https://create.roblox.com/docs/production/monetization/private-servers)).

### 7.3 Suscripción Club Montañero

No crear la suscripción en la v1. El config la marca `disponible = false`, `MonetizacionService` solo procesa pases y productos, y no hay código que consulte el estado de suscripción. La API existe y las suscripciones en Robux no son reembolsables, pero integrarla es una tarea aparte ([Subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions)).

---

## 8. Verificar compras con una cuenta de prueba

### 8.1 Preparar el entorno de prueba

1. Crear una experiencia de prueba separada (o un place de prueba) publicada y accesible solo para el equipo.
2. Crear en esa experiencia 2 pases y 3 productos de prueba, con precios bajos.
3. En una copia de prueba del proyecto, poner los IDs de prueba en `MonetizacionConfig` y `Activo = true`; `rojo build` y publicar **solo** la experiencia de prueba.
4. Usar una segunda cuenta Roblox con saldo. La cuenta del dueño no siempre sirve para simular a un comprador; una cuenta aparte es más realista.
5. Confirmar que la experiencia de prueba tiene DataStore real y que la consola no dice “modo memoria”.
6. No poner IDs de prueba en la experiencia live. No activar Studio API access en live.

**Sobre el coste:** no hay un sandbox documentado para todo el flujo de compra con Robux. Una compra de prueba en una experiencia publicada es real y consume Robux; usar precios bajos y asumir el coste. Los seams `_ProbarConceder` y `_ProbarRecibo` solo existen en Studio y validan la lógica de entrega/dedupe, pero no el prompt ni el recibo real de Roblox.

### 8.2 Casos de prueba

| # | Caso | Resultado esperado | Evidencia |
| --- | --- | --- | --- |
| 1 | Comprar `ranuras_ropa` y reentrar | `PaseEstado` muestra el pase; la ropa permite 9 ranuras; persiste tras rejoin | Captura + consola |
| 2 | Comprar `linterna_pro` | Cono 40,25° y color propio; en Modo Puro vuelve a 35° | Captura del cono |
| 3 | Comprar `pinas_x2` | 30 min de x2; la recompra extiende desde el vencimiento, no reinicia | `PinasService`/HUD + timestamp |
| 4 | Comprar `reanimacion_personal` | +1 stock; se usa una vez por partida; sin stock se puede pagar 100 Piñas; en Puro se rechaza | Panel de reanimación |
| 5 | Comprar `pack_sombreros` | Se conceden los 3 sombreros y se aplican | Inventario/ropa + captura |
| 6 | Repetir el mismo `PurchaseId` con `_ProbarRecibo` en Studio | No duplica la entrega; el segundo intento devuelve “Recibo repetido” | Consola |
| 7 | `Activo = false` | “Disponible al publicar el juego”; no hay prompt | Captura |
| 8 | ID 0 con `Activo = true` | No hay prompt; aviso del servidor | Consola |
| 9 | Ítem `disponible = false` | “PRÓXIMAMENTE”, deshabilitado | Captura |
| 10 | Salir y volver tras comprar | Piñas, stock, pase y cosméticos persisten | Rejoin |
| 11 | Reporte de ProcessReceipt | Sin productos listados pendientes de fix | Dashboard > Monetization > Shop |
| 12 | Compra con cuenta sin saldo | Roblox rechaza; el juego no entrega; no hay error de servidor | Captura del prompt |

### 8.3 Qué revisar en la consola

- `[Monetizacion] activo: 5 pases, 3 productos, Activo=true`.
- `[Monetizacion] entregado <id> a <jugador>` tras un producto.
- `[Monetizacion] recibo <PurchaseId> de <jugador> (<id>)`.
- `[Monetizacion] pase <id> reclamado por <jugador>`.
- `[Datos] servicio listo` y **no** “modo memoria”.
- Cualquier `[Monetizacion] recibo de producto desconocido` es un fallo de ID/config.

### 8.4 Después de la prueba

1. Volver a los IDs live y `Activo = true`; `rojo build` y publicar.
2. Hacer una compra real controlada con una cuenta de prueba en la experiencia live; verificar entrega y rejoin.
3. Vigilar el reporte de ProcessReceipt y los tickets durante 72 h.
4. Si algo falla, `Activo = false` frena los prompts, pero no los recibos externos; retirar el producto de la venta si hace falta.

---

## 9. Analytics: eventos, embudo y economía

### 9.1 Dónde está

Creator Dashboard > Creations > experiencia > **Analytics**. Secciones: Overview, Retention, Engagement, Acquisition, Demographics, Feedback, Monetization y Explore ([Analytics dashboard](https://create.roblox.com/docs/production/analytics/analytics-dashboard)).

- **Explore** permite construir gráficos con eventos personalizados y métricas estándar.
- **Funnel** se desbloquea cuando el juego publicado envía pasos de embudo.
- **Economy** se desbloquea cuando envía eventos de economía.
- **Performance** exige al menos 100 usuarios activos diarios para mostrar gráficos.

### 9.2 Qué envía el juego

`src/shared/Config/TelemetriaConfig.lua` define:

| Tipo | Nombres |
| --- | --- |
| Eventos personalizados | `PartidaInicio`, `PartidaFin`, `Reanimacion`, `Checkpoint`, `Rapto`, `Compra`, `ReanimacionPersonal` |
| Embudo | `PrimeraPartida`: `Lobby` → `PrimeraEtapa` → `PrimerCheckpoint` → `PartidaCompletada` |
| Economía | Moneda `Pinas`; fuente `Partida`; sumidero `Tienda` |

`src/server/TelemetriaService.lua` los envía con `AnalyticsService` desde el servidor, en `pcall`, sin nombres de jugador ni texto libre. `PartidaInicio`, `PartidaFin`, `Checkpoint`, `Reanimacion`, `Rapto`, `Compra` y `ReanimacionPersonal` se emiten desde los servicios correspondientes.

### 9.3 Reglas de la plataforma

- Los eventos de embudo y economía solo se aceptan desde el **servidor** y en juegos **publicados**; no desde el cliente ni desde Studio ([Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events), [Economy events](https://create.roblox.com/docs/production/analytics/economy-events)).
- Hasta 10 embudos por experiencia; hasta 5 monedas en Economía.
- Los pasos repetidos se ignoran; los pasos saltados auto-completan los anteriores. Los cambios de nombre de evento rompen la continuidad histórica: no renombrar `PrimeraPartida` ni los pasos sin una migración.
- Analytics puede tardar en poblar; no interpretar una hora sin datos como fallo.
- El código ya emite el embudo desde el servidor; si en Studio se ve `[Telemetria] AnalyticsService no disponible`, es el comportamiento esperado sin API.

### 9.4 Cómo comprobar que llega

1. Publicar con `TelemetriaConfig.Activo = true` y API/telemetría habilitadas en producción.
2. Entrar con una cuenta de prueba, jugar una partida completa y llegar a un checkpoint.
3. Revisar la consola: `[Telemetria] activa: embudo PrimeraPartida con 4 pasos`.
4. En el dashboard, abrir Analytics > Funnel y Economy; el embudo y la economía deben empezar a poblarse.
5. Revisar Monetization para pases/productos y Explore para eventos personalizados.
6. Cruzar los datos con `docs/launch/metrics.md`; no fijar umbrales en este documento.

---

## 10. Monitoreo de errores y rendimiento

### 10.1 Error Report

1. Creator Dashboard > experiencia > **Analytics > Errors** (la doc lo llama Error Report).
2. Filtrar por rango (última hora, día, 7 días o 30 días), place, plataforma, SO, severidad y “New errors since” una versión.
3. Expandir una fila para ver el stack trace; usar “Show version” para comparar antes/después de publicar.
4. Revisar servidor y cliente por separado; el cliente se puede filtrar por Desktop/Mobile/Console.
5. Recordar los límites: se rastrean hasta 500 errores y 500 warnings únicos; los conteos se reinician cada 6 h; los rangos llegan a 30 días. Las reglas de ignore/group se aplican a errores nuevos, no a los históricos ([Error Report](https://create.roblox.com/docs/production/analytics/error-report)).

**Rutina:** revisar después de cada publicación y a diario durante la beta. Un error nuevo en la versión recién publicada es un posible rollback si afecta a la partida, las compras o los datos.

### 10.2 Performance

1. Analytics > **Performance**.
2. Pestaña Client: usuarios concurrentes, tiempo de sesión, FPS, crash rate, memoria, CPU. Pestaña Server: CPU, FPS, memoria, cores y eficiencia.
3. Filtrar por versión del place para comparar la publicación nueva con la anterior.
4. Referencias de la doc: 60 FPS exige CPU <16 ms; memoria de servidor por debajo del 50 % (guía de 3 GB); el dashboard exige 100 DAU para mostrar gráficos ([Performance](https://create.roblox.com/docs/production/analytics/performance)).
5. En la beta temprana, complementar con la consola del MCP y el Device Simulator; el dashboard puede no tener muestra suficiente.

### 10.3 Reporte de ProcessReceipt

1. Creator Hub > **Monetization > Shop**.
2. Buscar el banner del reporte de ProcessReceipt.
3. El reporte lista cada producto listado que necesita un fix, con nombre e ID.
4. Corregir el handler en `src/server/MonetizacionService.lua` (IDs, entrega, retorno `PurchaseGranted`), publicar y marcar **Mark as fixed**.
5. No usar `PromptProductPurchaseFinished` para conceder: que se dispare no significa que la compra se haya completado.

### 10.4 Rutina de monitoreo

| Momento | Qué mirar |
| --- | --- |
| Antes de publicar | Error Report de la versión actual; Performance; recibos pendientes; backup |
| T+1 h | Errores nuevos, crashes, compras, tickets, FPS |
| T+24 h | Retención, embudo, economía, conversión, memoria de servidor |
| Semanal | Tendencias, deuda de errores, tickets recurrentes, licencias/audio |

---

## 11. Recibos de Developer Products: cómo funcionan en este repo

`MonetizacionService.Iniciar()` asigna `MarketplaceService.ProcessReceipt = procesarReciboRoblox`. Es el **único** handler; no crear otro.

Flujo del código:

1. Comprueba que `receiptInfo` sea una tabla, que el jugador esté online y que sus datos hayan cargado. Si no, devuelve `NotProcessedYet` para que Roblox reintente al rejoin.
2. Valida `PurchaseId` no vacío y busca el producto por `receiptInfo.ProductId` en `MonetizacionConfig.Productos`, exigiendo `productoId > 0`.
3. Si el producto no existe o el efecto no está soportado, avisa y devuelve `NotProcessedYet`.
4. `procesarRecibo` comprueba la lista `recibos` del jugador en DataService; si el `PurchaseId` ya está, no entrega otra vez y devuelve `PurchaseGranted`.
5. Si es nuevo, registra el `PurchaseId` (máximo 100; descarta los más viejos), marca sucio y entrega: `pinas_x2`, `reanimacion_personal` o `pack_sombreros`.
6. Devuelve `PurchaseGranted`; si el jugador se va o los datos no están, `NotProcessedYet` y Roblox reintenta.

**Riesgo residual:** el guardado es asíncrono (autoguardado cada 60 s). Si el servidor cae después de devolver `PurchaseGranted` pero antes de persistir, el recibo y la entrega pueden perderse aunque Roblox ya lo considere concedido. La lista de 100 recibos también es un límite: un reintento muy antiguo podría duplicar. Monitorizar tickets y el reporte; valorar un guardado síncrono antes de `PurchaseGranted` en una fase posterior.

**Reembolsos:** el juego no tiene flujo de reembolso ni revierte entregas. Los casos se gestionan por el soporte de Roblox; no prometer reembolsos en la ficha. Las suscripciones en Robux no son reembolsables según la doc de suscripciones.

---

## 12. Notas de cuenta: personal vs grupo, ID, edad y FAQ

### 12.1 Personal vs grupo

- **D5: cuenta personal.** Es la vía más simple para la v1; los ingresos van a la cuenta y los servidores privados de pago funcionan.
- **Grupo:** los ingresos van al balance del grupo; se necesitan roles con permisos de monetización y payouts; el owner del grupo gestiona impuestos y DevEx. Los splits de servidores privados se fijan al comprar y no cambian retroactivamente ([Groups](https://create.roblox.com/docs/projects/groups)).
- **No migrar a grupo a mitad de beta** sin una razón fuerte: cambia el dueño de la experiencia, los ingresos y el soporte.

### 12.2 Verificación de ID y EditableImage

- **EditableImage no se usa.** D7 dejó el spike S1 bloqueado y la ropa usa el plan B (colores, patrones y pegatinas prefabricadas). La verificación de ID no bloquea la personalización actual.
- **Audio:** la verificación de ID sube el límite de importación a 2.000 audios por 30 días; sin verificar, 100. Para 9 audios no es un bloqueo, pero la licencia sí ([Audio assets](https://create.roblox.com/docs/audio/assets)).
- **Publicación:** la doc 2026 exige age check/ID para release; sin eso, el camino a todos los públicos puede no estar disponible. Verificar en el dashboard.
- **DevEx:** 13+ y 30.000 Robux ganados; la verificación de identidad y los datos fiscales forman parte del proceso.

### 12.3 Edad de la cuenta y publicación

- Cuenta en regla y al menos 2 días de antigüedad.
- 5 juegos nuevos por día; places de 100 MB.
- La edad de la cuenta no sustituye la verificación de edad; son cosas distintas.
- Si la cuenta es nueva, esperar los 2 días antes de la beta; no intentar publicar con prisa.

### 12.4 Preguntas frecuentes

**¿Hace falta un grupo?** No. D5 eligió cuenta personal. Un grupo cambia ingresos, roles y payouts; se puede migrar más adelante.

**¿Hace falta verificar ID?** Para EditableImage no, porque no se usa. Para publicar a todos los públicos y para ampliar límites de audio, la doc lo pide; confirmar el camino en el dashboard.

**¿Puedo probar compras en Studio?** No se valida el prompt/recibo real. En Studio se usan los seams `_Probar*`; la compra real se prueba en una experiencia publicada con una cuenta de prueba.

**¿Por qué la tienda dice “Disponible al publicar el juego”?** `MonetizacionConfig.Activo` es `false` o el ID es 0. Publicar no basta: hay que crear el ítem, poner el ID y activar.

**¿Por qué dice “PRÓXIMAMENTE”?** El ítem tiene `disponible = false`; es intencional en botas, mochila y Club.

**¿Por qué compré un pase y no se activó?** Reentrar o reclamar; el servidor revalida con `UserOwnsGamePassAsync`. Verificar que el ID pertenece a la misma experiencia y que el pase está creado.

**¿Por qué no hay datos en Analytics?** Los eventos de embudo/economía solo se aceptan desde servidor y juego publicado; Performance necesita 100 DAU. Revisar que `TelemetriaConfig.Activo = true` y que la experiencia está publicada.

**¿Por qué aparece “modo memoria”?** Studio no tiene API access o el place no está publicado con DataStore. Es esperado; no activar el toggle en live.

**¿Por qué no suena música?** `AudioConfig.Musica.id = 0`; es silencio intencional hasta subir una pista con licencia.

**¿Por qué no se entregó un producto?** Revisar el reporte de ProcessReceipt, el ID en config, que el jugador estuviera online al cargar datos y que el handler devuelva `PurchaseGranted`. No conceder a mano sin verificar el recibo.

**¿Por qué el precio no coincide?** El dashboard manda; el config es una hipótesis. Roblox puede aplicar precio regional; actualizar ambos.

**¿Puedo usar un ID de otra experiencia?** No. Las ventas cruzadas de pases y productos están desactivadas desde el 30 de mayo de 2026.

**¿Cómo hago rollback?** Version History > restaurar > abrir en Studio > publicar > reiniciar servidores. Restaurar no publica solo ([Version History](https://create.roblox.com/docs/projects/version-history)).

**¿Puedo parar las ventas con `Activo = false`?** Frena los prompts dentro del juego, pero no los recibos de productos listados fuera. Retirar el producto de la venta o cambiar el handler si hace falta.

---

## 13. Enlaces oficiales verificados

Verificados el 2026-10-28. Si una ruta cambia, usar la raíz [create.roblox.com/docs](https://create.roblox.com/docs).

| Tema | URL |
| --- | --- |
| Creations / dashboard | https://create.roblox.com/dashboard/creations |
| Publicar experiencias | https://create.roblox.com/docs/production/publishing/publish-games-and-places |
| Configurar juegos y places | https://create.roblox.com/docs/projects/configure-games |
| Iconos | https://create.roblox.com/docs/production/publishing/experience-icons |
| Thumbnails | https://create.roblox.com/docs/production/publishing/thumbnails |
| Géneros | https://create.roblox.com/docs/production/publishing/experience-genres |
| Madurez y cumplimiento | https://create.roblox.com/docs/production/promotion/content-maturity |
| Verificación de cuenta | https://create.roblox.com/docs/production/publishing/account-verification |
| Localización | https://create.roblox.com/docs/production/localization |
| Place files | https://create.roblox.com/docs/projects/place-files |
| Version History | https://create.roblox.com/docs/projects/version-history |
| Pases | https://create.roblox.com/docs/production/monetization/passes |
| Developer Products | https://create.roblox.com/docs/production/monetization/developer-products |
| Suscripciones | https://create.roblox.com/docs/production/monetization/subscriptions |
| Servidores privados | https://create.roblox.com/docs/production/monetization/private-servers |
| Paid random items | https://create.roblox.com/docs/production/monetization/paid-random-items |
| PolicyService | https://create.roblox.com/docs/reference/engine/classes/PolicyService |
| MarketplaceService | https://create.roblox.com/docs/reference/engine/classes/MarketplaceService |
| DataStore | https://create.roblox.com/docs/cloud-services/data-stores |
| Compras y datos de jugador | https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing |
| Audio | https://create.roblox.com/docs/audio/assets |
| Privacidad de assets | https://create.roblox.com/docs/projects/assets/privacy |
| Analytics dashboard | https://create.roblox.com/docs/production/analytics/analytics-dashboard |
| Embudo | https://create.roblox.com/docs/production/analytics/funnel-events |
| Economía | https://create.roblox.com/docs/production/analytics/economy-events |
| Monetización (analytics) | https://create.roblox.com/docs/production/analytics/monetization |
| Errores | https://create.roblox.com/docs/production/analytics/error-report |
| Rendimiento | https://create.roblox.com/docs/production/analytics/performance |
| Grupos | https://create.roblox.com/docs/projects/groups |
| DevEx | https://create.roblox.com/docs/production/monetization/developer-exchange |
| Device Simulator | https://create.roblox.com/docs/studio/device-simulator |
| Consolas | https://create.roblox.com/docs/production/publishing/console-guidelines |
| Playable Devices (soporte) | https://en.help.roblox.com/hc/en-us/articles/205091994-Can-I-create-a-Roblox-experience-and-play-it-on-Xbox |
