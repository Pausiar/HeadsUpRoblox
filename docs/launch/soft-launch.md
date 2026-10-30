# Soft launch · Heads Up! Mountain Mayhem

**Fecha:** 2026-10-28 · **Fase:** 7 · **Alcance:** lanzamiento y operación en vivo.
**Fuente de verdad:** `docs/PLAN.md` §3.3, §7, §8, §9 y §12. Si este documento contradice el plan o la documentación oficial de Roblox, gana la fuente original y se corrige aquí.
**Documento hermano:** `docs/launch/creator-dashboard.md` (paso a paso de Creator Dashboard). **Métricas:** `docs/launch/metrics.md` (lo escribe el agente M; este documento no fija umbrales numéricos).

---

## 0. Estado de partida y bloqueos

### 0.1 Lo que ya está cerrado

| Área | Estado verificado | Evidencia |
| --- | --- | --- |
| Código | Fases 0–6 cerradas; lobby 2–8, Historia, Ronda rápida, El Doble, ropa plan B, tienda de Piñas, monetización Robux, audio/subtítulos, telemetría y ES/EN | `docs/skill-log.md`, `docs/team-fleet.md` |
| Build | `build/HeadsUp.rbxlx`, 364 KB; muy por debajo del límite de 100 MB por place | `build/HeadsUp.rbxlx`; [Place files](https://create.roblox.com/docs/projects/place-files) |
| Monetización simulada | 5 pases y 3 productos en config, IDs 0 y `Activo = false`; seams `_Probar*` solo en Studio | `src/shared/Config/MonetizacionConfig.lua`, `src/server/MonetizacionService.lua` |
| Tienda de Piñas | Catálogo de 8 cosméticos; compras y saldo validados en servidor | `src/shared/Config/TiendaConfig.lua`, `src/server/TiendaService.lua` |
| Telemetría | `TelemetriaConfig.Activo = true`; embudo `PrimeraPartida` de 4 pasos; eventos y economía definidos | `src/shared/Config/TelemetriaConfig.lua`, `src/server/TelemetriaService.lua` |
| Audio | Efectos con sonidos `rbxasset://` provisionales; `Musica.id = 0` = silencio intencional | `src/shared/Config/AudioConfig.lua` |
| Assets externos | 9 modelos CC-BY 4.0 registrados; el build actual usa primitivas y no referencia los `.glb` | `docs/asset-log.md`, `assets-source/CREDITS.md`; búsqueda de `MeshId`/`InsertService` en `src/` |

### 0.2 Lo que no está probado en producción

Según `docs/skill-log.md`, siguen sin prueba real: **DataStore en producción**, **ranking de amigos con amigos reales**, **8 jugadores simultáneos**, **móvil físico** y **telemetría en producción**. La fase 6 cerró con esos huecos declarados; por eso existen las olas de este documento.

### 0.3 Bloqueado por el usuario

| Bloqueo | Qué falta exactamente | Dónde se resuelve |
| --- | --- | --- |
| Publicar el place | Experiencia publicada y accesible; sin eso no se pueden crear pases ni productos | Creator Dashboard / Studio |
| Requisitos de release | Cuenta en regla, verificación de edad/ID, 2FA y elegibilidad de publicación | Creator Dashboard; ver `creator-dashboard.md` §0 |
| Pases y productos reales | Crear 2 pases vendibles y 3 productos; copiar sus IDs; `Activo = true` | Dashboard + `MonetizacionConfig.lua` |
| Compra real de prueba | Una cuenta de prueba con Robux y una experiencia publicada de prueba | Dashboard + cliente Roblox |
| Audio definitivo | Subir SFX/música con licencia y sustituir IDs; decidir si `Musica.id` sigue en 0 | Dashboard > Audio + `AudioConfig.lua` |
| Ficha del place | Icono 512×512, thumbnails 1920×1080, descripción ES/EN, género y madurez | Creator Dashboard |
| Móvil real | Una sesión en teléfono/tableta; no solo Device Simulator | Cliente Roblox |
| Créditos CC-BY en el juego | Pantalla de créditos si se importa cualquiera de los 9 modelos; hoy no existe en `src/` | Código/UI (fuera de este documento) |
| Umbrales de salida | Números de retención, embudo, crashes y conversión | `docs/launch/metrics.md` (agente M) |
| Soporte y calendario | Persona de guardia, canal de feedback y fechas objetivo | Decisión del creador |
| Servidores privados y Club | Precio de privados y validación de la suscripción | Dashboard + código (Club no implementado) |

**Regla de oro:** ninguna ola avanza con un P0/P1 abierto. Un umbral que no esté en `metrics.md` no se inventa aquí: se acuerda con el usuario y se añade a ese archivo.

---

## 1. Estrategia por olas

Una ola es una hipótesis, no una fecha. No se saltan puertas y no se compensa un criterio fallido con otro aprobado.

| Ola | Entorno | Audiencia | Objetivo | Duración propuesta | Evidencia de salida |
| --- | --- | --- | --- | --- | --- |
| 0. Interno | Studio, 1–8 jugadores locales | Creador y agentes | Build estable y flujo completo sin APIs reales | 1–2 sesiones | Playtest MCP, consola, capturas |
| 1. Beta cerrada | Place publicado de prueba, APIs reales | Amigos, 2–8 | DataStore, red, móvil y compras reales controladas | 3–5 sesiones en 1–2 semanas | Informe de beta y lista de bugs |
| 2. Acceso público limitado | Place público sin promoción | Público pequeño | Validar retención, economía, soporte y estabilidad | 7 días | Analytics, errores, tickets |
| 3. Lanzamiento | Place público | Todos | Abrir con operación y rollback listos | Continuo | Revisión de lanzamiento y postmortem |

### 1.1 Ola 0 · Interno / Studio

**Entrada**

- [ ] `rojo build` genera el place sin errores y el build abre en Studio.
- [ ] Fases 0–6 cerradas; no hay P0/P1 de código abiertos.
- [ ] `MonetizacionConfig.Activo = false`; las compras se prueban con `_ProbarConceder` y `_ProbarRecibo`, nunca con IDs reales.

**Criterios de avance (go)**

- [ ] Lobby de 2–8, Historia y Ronda rápida completas; reanimación, El Doble, tienda de Piñas, ropa, audio/subtítulos, ES/EN y Modo Puro verificados en el mismo build.
- [ ] Consola sin errores del juego. Se aceptan solo los avisos esperados de Studio sin API: DataStore en memoria, Analytics no disponible y ranking sin API. Cualquier otro error es no-go.
- [ ] Seams de monetización: pase concedido, producto entregado y recibo repetido sin duplicar.
- [ ] 8 jugadores locales sin caídas ni desincronización visible.

**Criterios de parada (no-go)**

- Error de script, crash, pérdida de datos o compra simulada que no entrega.
- 8 jugadores inestables o peligros que rompen la partida.
- Cualquier P0 visual o de accesibilidad abierto.

**Salida:** build congelado, capturas, consola y entrada en `docs/skill-log.md` (la escribe el coordinador).

### 1.2 Ola 1 · Beta cerrada con amigos (2–8)

**Entorno:** place publicado de prueba con APIs reales, DataStore real y pases/productos de prueba. No se usa la experiencia live para probar IDs falsos.

**Entrada**

- [ ] Ola 0 aprobada.
- [ ] Place publicado y accesible; requisitos de release resueltos.
- [ ] Copia de respaldo del place y del build.
- [ ] 2 pases y 3 productos de prueba creados; IDs puestos en una copia de prueba de `MonetizacionConfig`; `Activo = true`.
- [ ] Audio con licencia o decisión explícita de mantener `Musica.id = 0`.
- [ ] Canal de feedback y responsable de soporte definidos.

**Criterios de avance (go)**

- [ ] Al menos 3 sesiones con 2–8 jugadores, una de ellas con 8; Historia y Ronda rápida completas.
- [ ] Persistencia real: Piñas, cosméticos, ropa, récord y ajustes sobreviven a salir y volver a entrar. La consola **no** debe decir “modo memoria”.
- [ ] Ranking de amigos con al menos 2 amigos reales; si no hay amigos, el fallback global funciona sin error.
- [ ] Una sesión en móvil físico: controles táctiles, HUD, tienda y reanimación utilizables; sin recortes que impidan jugar.
- [ ] Compra de prueba de cada pase y producto vendible; recibo entregado una sola vez; el reporte de ProcessReceipt queda limpio.
- [ ] Chat falso filtrado por receptor; sin texto libre ni fuga de mensajes entre jugadores.
- [ ] Sin P0/P1 abiertos; umbrales de `metrics.md` cumplidos.

**Criterios de parada (no-go)**

- Pérdida o corrupción de datos; Piñas o compras que desaparecen.
- Compra cobrada y no entregada, o entregada dos veces.
- Crash loop al entrar o al iniciar partida.
- Filtro de chat eludido, mensaje ofensivo no moderado o incidente de moderación.
- 8 jugadores inestables o móvil injugable.
- Duda legal o de licencia sin resolver (audio, modelos, créditos).

**Salida:** informe de beta, bugs priorizados, decisión go/no-go firmada por el creador.

### 1.3 Ola 2 · Acceso público limitado

**Entorno:** place público sin campaña de promoción. Se abre a un grupo pequeño y se organizan sesiones con invitados; no se usa `paid access` salvo decisión explícita del usuario.

**Entrada**

- [ ] Ola 1 aprobada.
- [ ] IDs de producción y `Activo = true`; audio definitivo o silencio aceptado; créditos resueltos.
- [ ] Cuestionario de madurez enviado y aprobado; requisitos de release cumplidos.
- [ ] `TelemetriaConfig.Activo = true` y eventos visibles en producción.
- [ ] Respaldo, versión anterior identificada y runbook de rollback probado.
- [ ] Responsable de soporte y canal de feedback activos.

**Criterios de avance (go)**

- [ ] Embudo `PrimeraPartida` con datos: Lobby → PrimeraEtapa → PrimerCheckpoint → PartidaCompletada.
- [ ] Economía de Piñas visible: fuentes por partida y sumideros por tienda.
- [ ] Compras reales de los 5 ítems vendibles sin incidencias; reporte de recibos limpio.
- [ ] Sin aumento de errores nuevos respecto a la versión anterior; rendimiento dentro del presupuesto acordado.
- [ ] Sin incidentes de moderación, seguridad ni licencias.
- [ ] Retención, reintento y conversión por encima de los umbrales de `metrics.md`.
- [ ] Tickets de soporte cerrados o con mitigación; sin P0/P1.

**Criterios de parada (rollback o cierre temporal)**

- Pérdida de datos, compra fallida repetida, exploit de economía o duplicación de entregas.
- Aumento sostenido de crashes, errores nuevos o caída de FPS por debajo del presupuesto.
- Incidente de moderación, contenido no declarado o reclamación legal.
- Retención o conversión por debajo del umbral de parada de `metrics.md` durante la ventana acordada.

**Salida:** revisión de lanzamiento con métricas, errores, rendimiento, tickets y decisión.

### 1.4 Ola 3 · Lanzamiento público

**Entrada**

- [ ] Ola 2 aprobada y sin bloqueos.
- [ ] Ficha del place completa y revisada en ES/EN.
- [ ] Guardia de lanzamiento durante las primeras 24 h y revisión a 72 h.
- [ ] Respaldo, rollback y canal de soporte listos.
- [ ] Anuncio y materiales con el ADN visual aprobados (si hay marketing).

**Criterios de avance**

- [ ] Abrir el acceso público y mantener la misma versión durante la ventana de observación.
- [ ] Revisar errores, rendimiento, compras y tickets a T+1 h, T+24 h y T+72 h.
- [ ] Cerrar el lanzamiento solo con métricas de `metrics.md` y sin incidentes abiertos.

**Criterios de parada**

- Cualquiera de los disparadores de rollback de la ola 2.
- Imposibilidad de atender soporte o de revertir la versión.
- Caída de retención/valoración por debajo del umbral de parada acordado.

---

## 2. Checklist de publicación del place

### 2.1 Ficha, arte y metadatos

| Elemento | Requisito | Estado actual | Dónde |
| --- | --- | --- | --- |
| Nombre | `Heads Up! Mountain Mayhem`, consistente en dashboard, icono y créditos | Definido en `README.md` y `default.project.json` | Publish settings > Game details |
| Descripción ES | Borrador: “Cooperativo para 2–8: sube la montaña, esquiva rocas y árboles, reanima a tus amigos y desconfía. El Doble copia su skin y su chat.” | Pendiente de aprobar | Publish settings > Game details |
| Descripción EN | Borrador: “Co-op for 2–8: climb the mountain, dodge rocks and trees, revive your friends, and don't trust everyone. The Double copies skins and chat.” | Pendiente de aprobar | Publish settings > Game details |
| Icono | Cuadrado, al menos 512×512; debe leerse a ~150×150; pasa moderación | No hay icono de publicación en el repo | Configurations > Places > Basic Settings > Icon; [Icons](https://create.roblox.com/docs/production/publishing/experience-icons) |
| Thumbnails | 16:9, 1920×1080, menos de 3 MB; hasta 10 imágenes o vídeos | No hay thumbnails de publicación en el repo | Configurations > Places > Thumbnails; [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) |
| Género | Elegir el más cercano; el género solo se puede cambiar una vez cada 3 meses | Recomendación: Adventure > Story; alternativa Party & casual | Publish settings > Game details; [Genres](https://create.roblox.com/docs/production/publishing/experience-genres) |
| Madurez | Cuestionario de madurez y cumplimiento completo; etiqueta generada por Roblox | Pendiente | Publish settings > Content rating; [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) |
| Idiomas | ES/EN en el juego; metadatos traducidos | `Localization.Soportados = { "es", "en" }`; selector propio en Ajustes | Audience > Localization; [Localization](https://create.roblox.com/docs/production/localization) |
| Dispositivos | PC, teléfono y tableta primero; consola solo tras probar mando | Móvil físico y consola no probados | Audience > Access Settings > Devices |
| Privacidad | Público; descarga del place desactivada; sin paid access; servidores privados solo si el usuario fija precio | Pendiente de revisión | Audience > Access Settings |
| Créditos CC-BY | `assets-source/CREDITS.md` completo; créditos dentro del juego si se usan modelos | `CREDITS.md` existe; pantalla in-game no implementada; build actual sin modelos | `assets-source/CREDITS.md` |
| Compras no aleatorias | Solo compras directas; sin cofres, ruletas ni llaves | Catálogo de Piñas y config de Robux sin aleatorios | `TiendaConfig.lua`, `MonetizacionConfig.lua` |
| Tamaño | Menos de 100 MB por place | 364 KB | [Place files](https://create.roblox.com/docs/projects/place-files) |

**Nota de género:** la limitación de cambio cada 3 meses está en la doc de géneros. No cambiar el género a mitad de beta.

### 2.2 Edad y madurez

El cuestionario debe reflejar el contenido más intenso que puede encontrar el jugador, no el promedio. Para este juego:

- Violencia de dibujos animados: rocas, troncos y árboles golpean o derriban; no hay sangre realista ni gore.
- Miedo: El Doble acecha, imita la skin y el chat; es la parte más intensa y debe declararse.
- Humor crudo: el plan permite objetos absurdos; declarar solo lo que exista en la versión publicada.
- Lenguaje fuerte: no hay; no activar “Allow Strong Language”.
- Compras aleatorias de pago: no en la v1; responder “No”.
- Creación libre de usuario: la ropa usa colores, patrones y pegatinas prefabricadas; no hay texto libre ni subida de imágenes. Si se añade texto, pasa por filtro y cambia la declaración.
- Juego/apuestas, contenido adulto, romance, alcohol: no.

La etiqueta final la decide Roblox. No prometer “9+” ni “para toda la familia” hasta verla. Si cambia el contenido, reenviar el cuestionario; la doc advierte que una declaración inexacta puede acarrear moderación.

### 2.3 Idiomas

- El juego tiene tabla propia ES/EN con 31 claves y fallback `es → clave` (`src/shared/Localization/Strings.lua`); el idioma por defecto es `es` y se cambia en Ajustes.
- En Creator Dashboard, `Audience > Localization`: elegir **un** idioma de origen y añadir el otro como soportado. Recomendación: origen español (es el fallback del juego) y soportado inglés; si el usuario prefiere marketing internacional, origen inglés y soportado español. Es una decisión de producto, no de código.
- Traducir nombre y descripción manualmente o dejar la traducción automática; las traducciones manuales tienen prioridad. La traducción automática de Roblox no sustituye al selector propio del juego.
- Verificar la ficha en ambos idiomas antes de publicar.

### 2.4 Dispositivos y rendimiento

El plan exige móvil y mando desde el principio (§3.5, §8). El código tiene controles táctiles de 56×56, safe area y `Device Simulator` disponible, pero **no hay prueba en dispositivo físico**.

- Activar primero PC, teléfono y tableta. No activar consola hasta pasar una sesión con mando y revisar [Console development guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines).
- Probar con [Device Simulator](https://create.roblox.com/docs/studio/device-simulator) y después en un teléfono real; el simulador no detecta calor, memoria real ni notch físico.
- Revisar FPS, memoria y crashes en [Performance](https://create.roblox.com/docs/production/analytics/performance). La doc usa como referencia 60 FPS con CPU <16 ms y memoria de servidor <50 % (guía de 3 GB); son referencias, no promesas.
- La beta debe incluir al menos una partida de 8 jugadores en móvil si se va a abrir móvil al público.

### 2.5 Privacidad y cumplimiento

- No hay `HttpService` ni servicios externos en `src/`: los datos viven en Roblox (DataStore, OrderedDataStore) y la telemetría usa `AnalyticsService` sin nombres de jugador ni texto libre.
- El chat falso guarda frases en memoria de sesión, no en DataStore, y filtra cada mensaje por receptor con `TextService:FilterStringAsync` (`src/server/ChatMimicService.lua`).
- La tienda consulta `PolicyService:GetPolicyInfoForPlayerAsync` y registra `ArePaidRandomItemsRestricted`; el catálogo no tiene aleatorios (`src/server/TiendaService.lua`). Si en el futuro se añaden, hay que mostrar todos los resultados y probabilidades y bloquear a quienes tengan la restricción ([Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items), [PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService)).
- En Access Settings: desactivar “Allow users to download a copy of this Place”; no activar paid access; servidores privados solo si el usuario decide precio.
- No activar “Allow Strong Language”. El chat de Roblox ya tiene sus propios ajustes y moderación.
- Enviar el cuestionario de madurez antes de la ola 2; sin etiqueta, Roblox restringe la jugabilidad.

### 2.6 Créditos de assets CC-BY

`assets-source/CREDITS.md` registra 9 modelos CC-BY 4.0 con autor y enlace. La licencia exige atribución. El build actual no usa esos modelos: StageService y AccesoriosService construyen con primitivas y no hay `MeshId` ni `InsertService` que los referencien.

- [ ] Si se importa cualquier modelo antes del lanzamiento, añadir su atribución a una pantalla de créditos dentro del juego **antes** de publicar. Hoy esa pantalla no existe en `src/`.
- [ ] No usar el pack de rocas hasta aclarar la sublicencia “Stylized stones minipack” de Sereda (`docs/asset-log.md`).
- [ ] Mantener el registro de licencias de audio junto a los archivos; no subir audio sin derechos.
- [ ] Si no se importa ningún modelo, dejar constancia en el informe de lanzamiento de que el place no contiene assets CC-BY.

---

## 3. Monetización en vivo

El código está listo para el dashboard; lo que falta son los IDs y la decisión del usuario. La tienda ya tiene pestañas PIÑAS/ROBUX y botones de compra; no hay que añadir botones, solo datos reales.

### 3.1 Catálogo que espera el servidor

| Config id | Nombre en config | Tipo | Qué desbloquea | Precio hipótesis | ID actual | ¿Vender en v1? | Dónde se crea |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ranuras_ropa` | Ranuras de camiseta (3 → 9) | Pase | 9 ranuras de ropa en vez de 3 | 149 Robux | 0 | Sí | Monetization > Passes |
| `linterna_pro` | Linterna Pro (+15 % de cono) | Pase | Cono 40,25° y color propio; se apaga en Modo Puro | 149 Robux | 0 | Sí | Monetization > Passes |
| `botas_agarre` | Botas de agarre (+8 % de adherencia) | Pase | Nada en v1: no hay sistema de adherencia | 149 Robux | 0 | **No** (`disponible = false`) | No crear hasta implementar el efecto |
| `mochila_pro` | Mochila Pro (+1 espacio de inventario) | Pase | Nada en v1: no hay inventario | 199 Robux | 0 | **No** (`disponible = false`) | No crear hasta implementar el efecto |
| `club_montanero` | Club Montañero (suscripción) | Suscripción | Cosméticos mensuales y etiqueta VIP; no implementado | 0 (sin precio) | 0 | **No** | Monetization > Subscriptions, solo si se implementa |
| `pinas_x2` | Doble de Piñas (30 min) | Producto | Multiplicador x2 durante 30 min; la recompra extiende desde el vencimiento | 49 Robux | 0 | Sí | Monetization > Developer Products |
| `reanimacion_personal` | Reanimación personal | Producto | +1 reanimación de stock; 1 por partida; alternativa de 100 Piñas | 25 Robux | 0 | Sí | Monetization > Developer Products |
| `pack_sombreros` | Pack de sombreros | Producto | Sombrero de copa, cuernos vikingos y gorro de chef | 199 Robux | 0 | Sí | Monetization > Developer Products |

**Advertencia importante:** `MonetizacionConfig` declara 5 pases, pero solo 2 son pases vendibles. Los otros 2 no tienen efecto en la v1 y el club es una suscripción, no un pase. No crear productos sin efecto para “cumplir” con la lista: sería vender algo que no existe y el propio config los bloquea con `disponible = false`. Si el usuario quiere reservar IDs, se pueden crear fuera de venta y dejar `disponible = false`, pero el servidor no los consulta; es mejor crearlos cuando exista el efecto.

### 3.2 Pasos para activar

1. Publicar el place y confirmar que es accesible ([Create and publish](https://create.roblox.com/docs/production/publishing/publish-games-and-places)).
2. Crear los 2 pases vendibles y copiar sus Asset IDs ([Passes](https://create.roblox.com/docs/production/monetization/passes)).
3. Crear los 3 productos y copiar sus Asset IDs ([Developer Products](https://create.roblox.com/docs/production/monetization/developer-products)).
4. Editar en disco `src/shared/Config/MonetizacionConfig.lua`: poner los IDs reales en `paseId`/`productoId` y `Activo = true`. No editar el script sincronizado desde Studio; Rojo lo sobrescribiría.
5. `rojo build`, abrir el build y publicar. La consola debe mostrar `[Monetizacion] activo: 5 pases, 3 productos, Activo=true`.
6. Probar con una cuenta de prueba en una experiencia publicada de prueba; ver `creator-dashboard.md` §8.
7. Solo después, repetir con la experiencia live y una compra real controlada.
8. Vigilar el reporte de ProcessReceipt y los tickets durante 72 h.

### 3.3 Qué valida el servidor

- `ComprarRobux` valida id, `disponible`, que `Activo = true` y que el ID sea mayor que 0; si algo falla, responde `RobuxResult` con la clave `aviso_no_publicado` o `no_disponible_version` (el cliente las traduce) y no abre prompt.
- Los pases se comprueban con `UserOwnsGamePassAsync` al entrar y tras `ReclamarPase`; el cliente solo avisa. Un pase comprado no se entrega por el evento del prompt.
- Los productos pasan por `ProcessReceipt`, con deduplicación por `PurchaseId` en DataService (`recibos`, máximo 100). Solo hay un handler, en `MonetizacionService`; no añadir otro.
- `Activo = false` bloquea los prompts, pero **no** bloquea `ProcessReceipt`: si un producto listado se vende fuera del juego, el recibo se procesa igual. No usar `Activo = false` como interruptor de emergencia de recibos.
- La entrega de productos no fuerza un guardado síncrono: `DataService.Guardar` marca sucio y el autoguardado corre cada 60 s. Un crash dentro de esa ventana puede perder el recibo/entrega aunque Roblox ya lo marcó como concedido. Es un riesgo residual de la v1; mitigar con monitorización y valorar un guardado síncrono antes de `PurchaseGranted` en una fase posterior.

### 3.4 Precios, reembolsos y errores

- Los `precioRobux` del config son hipótesis del plan, no precios definitivos. El precio real se fija en el dashboard y debe coincidir con el que muestra la UI; si no, se corrige uno de los dos.
- Roblox puede aplicar precio regional y optimización de precios; el importe mostrado al jugador puede variar. No prometer un precio único mundial.
- No hay flujo de reembolso dentro del juego ni código que revierta entregas. Los reembolsos se gestionan fuera del juego, por el soporte de Roblox; no prometer reembolsos en la descripción.
- Errores típicos: ID 0 → no hay prompt; `Activo = false` → “Disponible al publicar el juego”; `disponible = false` → “PRÓXIMAMENTE”; pase comprado pero no activo → reclamar/reentrar y revisar que el ID pertenece a la misma experiencia.
- Desde el 30 de mayo de 2026 las ventas cruzadas de pases y productos entre experiencias están desactivadas: un ID de otra experiencia no sirve ([Passes](https://create.roblox.com/docs/production/monetization/passes), [Developer Products](https://create.roblox.com/docs/production/monetization/developer-products)).

### 3.5 Suscripción y servidores privados

- **Club Montañero:** el config lo declara como `tipo = "suscripcion"`, `disponible = false`, y `MonetizacionService` solo procesa `tipo == "pase"` o `"producto"`. No está implementado. La API de suscripciones existe, pero integrarla requiere código y una prueba aparte; no crear la suscripción para la v1 ([Subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions)).
- **Servidores privados:** se activan en `Audience > Access Settings > Allow private servers`; si se cobran, activar `Requires Robux` y fijar precio. Cambiar el precio cancela las suscripciones activas; no se combinan con paid access. El precio queda a decisión del usuario ([Private servers](https://create.roblox.com/docs/production/monetization/private-servers)).
- **Cuenta:** D5 eligió cuenta personal; los servidores privados de pago funcionan en cuenta personal. Si se migra a grupo, los ingresos van al grupo y requieren roles y payouts ([Groups](https://create.roblox.com/docs/projects/groups)).

---

## 4. Audio

### 4.1 Estado actual

| Sonido | ID actual | Estado |
| --- | --- | --- |
| Aviso, Impacto, Reanimar, Checkpoint, Monstruo, Compra, Fin, UI | `rbxasset://sounds/...` | Provisional, incluido en Roblox; sirve para probar |
| Música | `0` | Silencio intencional; `AudioService` no crea sonido si es 0 |

`AudioConfig` y `AudioService` respetan `volumenEfectos`, `volumenMusica` y `reducirEfectos`; los subtítulos muestran el texto de cada efecto. No hay ningún audio subido por el creador.

### 4.2 Sustitución

1. Subir cada audio con derechos de uso (propio o licencia compatible) desde Asset Manager o Creator Dashboard > Development Items > Audio. Formatos: MP3, OGG, WAV o FLAC; menos de 20 MB y 7 minutos; hasta 48 kHz ([Audio assets](https://create.roblox.com/docs/audio/assets)).
2. Recordar que el audio subido empieza privado: hay que dar permiso a la experiencia o al grupo; sin permiso, el sonido no se oye ([Asset privacy](https://create.roblox.com/docs/projects/assets/privacy)).
3. Copiar el ID y ponerlo en `AudioConfig.Efectos.<nombre>.id` o `AudioConfig.Musica.id`; para música, usar `rbxassetid://<id>` o el número.
4. `rojo build`, publicar y probar en la experiencia publicada: volumen, subtítulos, “Reducir efectos” y cambio ES/EN.
5. Mantener un registro de licencia por archivo (autor, fuente, licencia, fecha). No subir música comercial ni “free” sin comprobar la licencia.

**Bloqueado por el usuario:** los archivos y la decisión de música. `Musica.id = 0` es aceptable para la beta y el soft launch; no es un error. Si se mantiene, la experiencia se juega en silencio musical, con SFX provisionales o definitivos.

---

## 5. Operación

### 5.1 Versión y respaldo

- **Fuente de código:** `src/` + Rojo. El place publicado se genera con `rojo build`; no se edita el script sincronizado con el MCP.
- **Artefacto:** conservar `build/HeadsUp.rbxlx` de la versión que se publica; nombrar la versión (`v0.x-beta.N`) en las notas de publicación.
- **Respaldo en Roblox:** guardar una copia del place como place separado (`File > Save to Roblox As`) antes de cada ola. No usar el place de respaldo para jugar.
- **Respaldo histórico:** etiquetar el commit de la versión publicada (lo hace el coordinador; este documento no ejecuta Git) y conservar el `.rbxlx`.
- **Version History:** el dashboard guarda versiones; restaurar no publica automáticamente. Hay que abrir la versión restaurada en Studio, publicar y reiniciar servidores ([Version History](https://create.roblox.com/docs/projects/version-history)).

### 5.2 Rollback

**Disparadores inmediatos**

- Pérdida o corrupción de datos.
- Compra cobrada sin entrega o entregada dos veces.
- Crash loop o error nuevo que impide jugar.
- Exploit de economía, duplicación de Piñas o bypass de pases.
- Incidente de moderación, contenido no declarado o reclamación legal.
- Rendimiento por debajo del presupuesto durante la ventana de observación.

**Procedimiento**

1. Decidir rollback con el responsable de guardia; no esperar a que termine la ventana si hay pérdida de datos o compras.
2. Restaurar la versión anterior desde Version History o publicar el `.rbxlx` de respaldo.
3. Publicar la versión restaurada y reiniciar servidores; confirmar que los servidores nuevos usan la versión anterior.
4. Si el fallo es de monetización, poner `Activo = false` y republicar **solo** si se acepta que los recibos de productos listados pueden seguir procesándose; para detener recibos habría que retirar el producto de la venta o cambiar el handler, no basta `Activo`.
5. Comunicar en el canal de soporte: qué pasó, qué se revirtió, qué datos se conservaron y qué se perdió.
6. Registrar el incidente y la causa; no reabrir la ola hasta tener una prueba.

### 5.3 Soporte y feedback

| Rol | Responsabilidad | Persona |
| --- | --- | --- |
| Owner | Decide go/no-go, rollback y precios; responde ante Roblox | Cuenta creadora (D5, Pausiar) |
| Guardia de lanzamiento | Revisa errores, compras y tickets en las primeras 24 h | El usuario designa |
| Soporte de primera línea | Responde comentarios, tickets y reportes; escala P0 | El usuario designa |
| Moderación de comunidad | Revisa reportes de chat y conducta | El usuario designa |

**Canales mínimos**

- Comentarios y valoraciones de la experiencia en Roblox.
- Issues del repositorio público `github.com/Pausiar/HeadsUpRoblox` para bugs reproducibles (sin datos personales).
- Un canal de contacto directo (Discord, formulario o correo) que el usuario debe crear y publicar en la descripción; no inventar uno.
- Para incidentes de compra: pedir nombre de usuario, fecha aproximada, producto y captura del recibo de Roblox; no pedir contraseñas ni datos de pago.

**Propuesta de respuesta:** P0 en menos de 2 h durante la ventana de lanzamiento; P1 en 24 h; resto en 72 h. Es una propuesta operativa, no una promesa pública hasta que el usuario la apruebe.

### 5.4 Calendario de beta (fechas relativas)

Las fechas exactas las fija el usuario. Esta tabla es una plantilla; no se inventa una fecha de lanzamiento.

| Momento | Hito | Criterio de salida |
| --- | --- | --- |
| T-14 días | Congelar build, backup, revisar bloqueos | Ola 0 aprobada |
| T-10 días | Crear pases/productos de prueba, audio, ficha | Ola 1 lista para empezar |
| T-7 días | Beta cerrada con amigos (3–5 sesiones) | Ola 1 aprobada |
| T-3 días | Corregir bugs, congelar versión, revisar Analytics | Sin P0/P1 |
| T-1 día | Backup, rollback ensayado, guardia y canales listos | Ola 2 lista |
| Día 0 | Acceso público limitado sin promoción | Primeras 24 h monitorizadas |
| D+7 | Revisión de métricas y decisión | Ola 2 aprobada o rollback |
| D+8 | Lanzamiento público | Ola 3 |

### 5.5 Métricas de salida

Los umbrales numéricos viven en **`docs/launch/metrics.md`**. Este documento solo define qué se mira y cuándo se para.

| Dimensión | Qué se mira | Fuente |
| --- | --- | --- |
| Embudo | Lobby → PrimeraEtapa → PrimerCheckpoint → PartidaCompletada | Analytics > Funnel |
| Retención y reintento | D1/D7, partidas por jugador, tiempo de sesión | Analytics > Retention/Engagement |
| Economía | Piñas ganadas por partida, gastadas en tienda, saldo medio | Analytics > Economy |
| Monetización | Conversión de pases/productos, ingresos, reembolsos/tickets | Analytics > Monetization; Finances |
| Calidad | Errores nuevos, crashes, FPS, memoria, CPU de servidor | Analytics > Errors/Performance |
| Soporte | Tickets por 100 jugadores, tiempo de primera respuesta, P0 abiertos | Canal de soporte |
| Comunidad | Valoración, comentarios, reportes de conducta | Ficha de Roblox |

**Regla:** si `metrics.md` no existe o no tiene un umbral para una dimensión, la ola no se cierra por esa dimensión; se acuerda el umbral con el usuario y se añade al archivo.

### 5.6 Runbook del día de lanzamiento

- **T-24 h:** build congelado; backup; IDs y `Activo` verificados; audio y créditos; contenido de la ficha; guardia confirmada; rollback ensayado.
- **T-1 h:** publicar la versión; revisar consola de una partida propia; confirmar que Analytics recibe eventos; abrir el canal de soporte.
- **T+0:** abrir acceso; observar errores, compras y tickets cada 30 min durante 4 h.
- **T+24 h:** revisar retención, embudo, economía, crashes y rendimiento; decidir continuar, corregir o revertir.
- **T+72 h:** postmortem corto; bugs a la lista; siguiente ola (biomas/eventos) solo si la base está estable.

---

## 6. Riesgos residuales y mitigaciones

| Riesgo | Impacto | Mitigación | Estado |
| --- | --- | --- | --- |
| DataStore real sin probar | Pérdida de Piñas, ropa, récords o recibos | Ola 1 con cuentas reales; verificar persistencia tras rejoin; revisar `[Datos]` y no usar “modo memoria” | Abierto hasta Ola 1 |
| Recibo concedido antes de guardar | Compra perdida si el servidor cae en la ventana de autoguardado (60 s) | Monitorizar tickets y reporte de recibos; valorar guardado síncrono antes de `PurchaseGranted`; no prometer entrega instantánea | Residual v1 |
| Lista de recibos acotada a 100 | Un reintento muy antiguo podría duplicar una entrega | Vigilar volumen; ampliar el límite si crece; no borrar recibos a mano | Residual v1 |
| `Activo = false` no detiene recibos | Un producto listado se seguiría entregando | Retirar el producto de la venta o cambiar el handler; no usar `Activo` como apagado de recibos | Documentado |
| Ranking de amigos | Falla si no hay amigos o API; ranking vacío | Fallback global ya implementado; probar con 2+ amigos; explicar en la UI | Abierto hasta Ola 1 |
| Móvil real | UI recortada, controles incómodos, crashes por memoria | Device Simulator + teléfono real; safe area; objetivos 44–56 px; revisar Performance | Abierto hasta Ola 1 |
| 8 jugadores simultáneos | Físicas, red o servidor inestables | Sesión dedicada de 8; presupuesto de objetos del spike S4; StreamingEnabled | Abierto hasta Ola 1 |
| Física del personaje en el cliente | Un exploit puede fijar su propia `WalkSpeed` y correr de más | La estamina y la velocidad las fija `EstaminaService`; `MatchService` limita el progreso de ruta a 32 studs/s (sprint real 24), así que el exceso no cobra checkpoints ni meta. Vigilar reportes de velocidad anómala | Mitigado parcial (E43) |
| PolicyService por región | Compras bloqueadas o restricciones no previstas | No hay aleatorios; revisar logs de `[Tienda]`; si se añaden, mostrar odds y bloquear | Bajo en v1 |
| Chat moderado | Fuga de texto, insultos o falso positivo | Filtro por receptor ya implementado; banco curado; aviso en tutorial; reportes | Abierto si hay incidente |
| Audio sin licencia | Retirada de audio o reclamación | Registro de licencias; no subir material comercial; mantener `Musica.id = 0` hasta tener pista | Bloqueado por usuario |
| Créditos CC-BY | Reclamación por falta de atribución | `CREDITS.md`; pantalla in-game si se importan modelos; no usar el pack de rocas hasta aclarar sublicencia | Bloqueado si se usan modelos |
| Requisitos de release 2026 | No poder publicar a todos los públicos | Verificar edad/ID, 2FA, Plus/Premium o tasa y evaluación antes de la Ola 1 | Bloqueado por usuario |
| Ventas cruzadas desactivadas | IDs de otra experiencia no funcionan | Crear pases/productos en la misma experiencia; verificar IDs | Documentado |
| Suscripción Club | No está implementada; venderla sería incumplir | Mantener `disponible = false`; no crear la suscripción | Bloqueado por código |
| Pases sin efecto | Producto engañoso | No crear botas/mochila hasta implementar el efecto; `disponible = false` | Documentado |
| Place >100 MB | Falla la publicación | Build actual 364 KB; medir si se importan modelos; dividir places si hace falta | Bajo |
| Ficha sin icono/thumbnails | Baja conversión y aspecto inacabado | Producir arte 512×512 y 1920×1080; revisar en móvil | Bloqueado por usuario |

---

## 7. Enlaces oficiales verificados

Verificados el 2026-10-28. Si una ruta cambia, usar la raíz [create.roblox.com/docs](https://create.roblox.com/docs) y buscar por título; no inventar rutas.

| Tema | URL |
| --- | --- |
| Publicar experiencias y places | https://create.roblox.com/docs/production/publishing/publish-games-and-places |
| Configurar juegos y places | https://create.roblox.com/docs/projects/configure-games |
| Iconos de experiencia | https://create.roblox.com/docs/production/publishing/experience-icons |
| Thumbnails | https://create.roblox.com/docs/production/publishing/thumbnails |
| Géneros | https://create.roblox.com/docs/production/publishing/experience-genres |
| Madurez y cumplimiento | https://create.roblox.com/docs/production/promotion/content-maturity |
| Verificación de cuenta | https://create.roblox.com/docs/production/publishing/account-verification |
| Localización | https://create.roblox.com/docs/production/localization |
| Tamaño de place | https://create.roblox.com/docs/projects/place-files |
| Historial de versiones | https://create.roblox.com/docs/projects/version-history |
| Pases (Game Passes) | https://create.roblox.com/docs/production/monetization/passes |
| Productos de desarrollador | https://create.roblox.com/docs/production/monetization/developer-products |
| Suscripciones | https://create.roblox.com/docs/production/monetization/subscriptions |
| Servidores privados | https://create.roblox.com/docs/production/monetization/private-servers |
| Compras aleatorias de pago | https://create.roblox.com/docs/production/monetization/paid-random-items |
| PolicyService | https://create.roblox.com/docs/reference/engine/classes/PolicyService |
| MarketplaceService | https://create.roblox.com/docs/reference/engine/classes/MarketplaceService |
| DataStore | https://create.roblox.com/docs/cloud-services/data-stores |
| Compras y datos de jugador | https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing |
| Audio | https://create.roblox.com/docs/audio/assets |
| Privacidad de assets | https://create.roblox.com/docs/projects/assets/privacy |
| Analytics dashboard | https://create.roblox.com/docs/production/analytics/analytics-dashboard |
| Embudo | https://create.roblox.com/docs/production/analytics/funnel-events |
| Economía | https://create.roblox.com/docs/production/analytics/economy-events |
| Errores | https://create.roblox.com/docs/production/analytics/error-report |
| Rendimiento | https://create.roblox.com/docs/production/analytics/performance |
| Grupos | https://create.roblox.com/docs/projects/groups |
| DevEx | https://create.roblox.com/docs/production/monetization/developer-exchange |
| Device Simulator | https://create.roblox.com/docs/studio/device-simulator |
| Guías de consola | https://create.roblox.com/docs/production/publishing/console-guidelines |
| Playable Devices (soporte) | https://en.help.roblox.com/hc/en-us/articles/205091994-Can-I-create-a-Roblox-experience-and-play-it-on-Xbox |
