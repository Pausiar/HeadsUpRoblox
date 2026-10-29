# Pendiente del usuario · qué falta y cómo hacerlo

Fecha: 2026-10-29 · Fase 10 (QA multijugador y rendimiento).
Esto es lo que **solo se puede hacer con tu cuenta, tus dispositivos o tus amigos**. El resto ya quedó hecho y verificado en Studio; ver `docs/HANDOFF.md` y `docs/skill-log.md`.

Orden recomendado: **A → B → C → D → E → F → G**. A desbloquea B, C y E. D, F y G no dependen de publicar.

---

## A. Publicar el juego y activar API Services

1. Abre `build/HeadsUp.rbxlx` en Studio (o el proyecto con Rojo).
2. Revisa `Game Settings > Security` y activa **Enable Studio Access to API Services**. Sin esto, DataStore y OrderedDataStore siguen en modo memoria.
3. `Archivo > Publicar en Roblox…` (File > Publish to Roblox). Publica como experiencia nueva o actualiza la existente.
4. En el Creator Dashboard, abre la experiencia > **Settings > Permissions**: deja el juego público (o al menos jugable por tus amigos) mientras dure el QA.
5. Si vas a usar el ranking de amigos, comprueba que la experiencia no tiene **"Playable Devices"** restringido al dispositivo donde no jugarás (móvil/consola).

**Cómo saber que funcionó:** en la consola del servidor (F9 > Server) debe desaparecer `[Datos] servicio listo (modo memoria)` y salir `[Datos] servicio listo`; al entrar debe aparecer `[Datos] carga OK para TU_NOMBRE` y `[AmigosRanking] activo: … (top N)`.

---

## B. Crear los IDs de monetización y activarlos

Todo está en `src/shared/Config/MonetizacionConfig.lua`. Hoy `Activo = false` y todos los IDs valen `0`, así que la tienda muestra «Disponible al publicar el juego».

### B.1 Crear en el Creator Dashboard

En la experiencia publicada: **Monetization > Passes** y **Monetization > Developer Products**.

| Tipo | `id` en config | Nombre sugerido | Precio configurado |
| --- | --- | --- | --- |
| Pase | `ranuras_ropa` | Ranuras de camiseta (3 → 9) | 149 R$ |
| Pase | `linterna_pro` | Linterna Pro (+15% de cono) | 149 R$ |
| Pase | `mochila_pro` | Mochila Pro (+1 bebida) | 199 R$ |
| Producto | `pinas_x2` | Doble de Piñas (30 min) | 49 R$ |
| Producto | `reanimacion_personal` | Reanimación personal | 25 R$ |
| Producto | `pack_sombreros` | Pack de sombreros | 199 R$ |

No crees todavía `botas_agarre` ni `club_montanero`: siguen `disponible = false` a propósito (la v1 no tiene sistema de adherencia y la API de suscripciones no está validada). Si algún día los implementas, crea el pase, rellena `paseId` y pon `disponible = true` y `Activo = true`.

### B.2 Rellenar el config

Para cada fila de la tabla, copia el ID numérico del Dashboard en `paseId` (pases) o `productoId` (productos) y pon `MonetizacionConfig.Activo = true`.

- Los IDs de **pases** son números (`paseId`); los de **productos** también (`productoId`).
- No cambies `id`, `efecto`, `precioRobux` ni `nombreClave`: son las claves internas y la localización.
- El precio del Dashboard manda sobre `precioRobux`; mantén ambos iguales para que la UI no mienta.

### B.3 Verificar antes de comprar

1. Recompila y publica (`rojo build default.project.json -o build/HeadsUp.rbxlx` y vuelve a subir el place).
2. En la tienda debe aparecer la pestaña Robux con precios reales y sin el aviso de «Disponible al publicar».
3. En consola: `[Monetizacion] activo: 5 pases, 3 productos, Activo=true` (los no disponibles se listan pero no se venden).

---

## C. Compra real de prueba (una sola vez)

Hazlo con una cuenta que tenga Robux y desde el **cliente**, no desde Studio.

1. Entra a la experiencia publicada y abre **TIENDA > ROBUX**.
2. Compra un producto barato (`reanimacion_personal`, 25 R$) y un pase (`linterna_pro`, 149 R$).
3. Comprueba en consola del servidor: `[Monetizacion] recibo … (reanimacion_personal)` y `[Monetizacion] entregado reanimacion_personal a TU_NOMBRE`; para el pase, `reclamado`.
4. Verifica el efecto: la reanimación queda en stock y se puede usar; la linterna Pro se nota en el cono.
5. **Rejoin** y comprueba que el pase sigue concedido (DataStore). Si no, revisa API Services y `[Datos] guardado OK`.
6. Repite con `pinas_x2` y `pack_sombreros`. Para `pinas_x2`, gana Piñas caminando y verifica el x2 durante 30 min.
7. Anota el `purchaseId` de los recibos; si algo falla, el rollback deja reintentar la entrega.

**Ojo:** no hay entorno de pruebas de compras en Roblox. Usa precios bajos y tu propia cuenta; reembolsa manualmente si quieres recuperar los Robux.

---

## D. Música, iconos y ficha (sin bloquear el código)

| Qué | Dónde | Qué hacer |
| --- | --- | --- |
| Música | `src/shared/Config/AudioConfig.lua` (`Musica.id = 0`) | Sube un audio con licencia (Creator Dashboard > Audio), copia el ID y ponlo en `Musica.id`. Si no tienes licencia, déjalo en 0: los efectos ya suenan. |
| Icono | Creator Dashboard > Experience > Icon | PNG 512×512. Usa el arte de `docs/concept/` como referencia. |
| Thumbnails | Creator Dashboard > Thumbnails | 1920×1080; una de paisaje y otra de la tienda o del HUD. |
| Descripción | Creator Dashboard > Description | ES/EN; el juego ya localiza la UI, pero la ficha no. |
| Créditos CC-BY | Si importas algún `.glb` de `assets-source/` | Añade una pantalla o texto de créditos; hoy el build no usa esos modelos (`docs/asset-log.md`, `CREDITS.md`). |

---

## E. Pruebas que necesitan hardware o personas

### E.1 Partida completa de 8 jugadores (criterio de fase 10)

1. Publica el place y reúne 8 cuentas (amigos o cuentas de prueba) en **HISTORIA**.
2. Jugad de inicio a meta sin usar atajos ni comandos.
3. Comprueba: nadie se queda atrás por el streaming, las caídas se reaniman, El Doble aparece tras 45 s y rapta, la meta muestra `FinScreen` y el ranking final lista a los 8.
4. En consola del servidor vigila: `[Match] checkpoint`, `[Doble] retirada`, `[Match] meta alcanzada`; sin errores nuevos.
5. Anota FPS mínimos con la barra de rendimiento del cliente (`Ctrl+F3` en Windows) o el MicroProfiler (`F9 > MicroProfiler`) en el peor momento (8 jugadores, streaming activo).

### E.2 Móvil real

El Device Simulator ya se probó con **Samsung Galaxy A06** (705×338 lógicos) e **iPhone 17 Pro** (750×381): menú, lobby, personalización y ajustes caben o se desplazan, y el botón AMIGOS ya no tapa el salto. Falta el dispositivo físico:

1. Instala Roblox en un Android de gama baja (A06 o similar) y en un iPhone.
2. Juega una partida corta: comprueba joystick, salto, linterna, cámara, compra de Piñas y reanimar.
3. Verifica que el texto se lee a distancia de brazo y que ningún botón queda bajo el notch o la barra de gestos.
4. Mide FPS: objetivo ≥30 en gama media con el streaming cargando.

### E.3 Mando y primera persona

1. Conecta un mando (Xbox/PS) al cliente y prueba: mover, cámara, salto, linterna y reanimar. El plan exige que sea jugable, no que tenga iconos propios.
2. Activa primera persona (si tu build lo permite) y comprueba que la cámara no atraviesa la ropa ni el terreno.
3. Anota cualquier acción que no tenga binding.

### E.4 Récords solo en Modo Puro

El código ya lo impone: `AmigosRankingService` ignora las partidas con ventajas (`monetizacion.EsModoPuro(player)`); `MatchService` guarda el récord personal siempre, pero el ranking de amigos no. Para verificarlo en producción:

1. Juega una partida **con Modo Puro activado** y llega lejos; comprueba que tu marca sube en el ranking de amigos.
2. Juega otra **sin Modo Puro** (con pases o reanimación de pago) y comprueba que la marca del ranking **no** cambia.

### E.5 Telemetría en producción

Tras 24–48 h con sesiones reales, abre Creator Dashboard > Analytics y confirma el embudo `PrimeraPartida` (4 pasos), la economía y los eventos de `docs/launch/metrics.md`. En Studio no se agrega nada.

---

## F. Decisiones que solo puedes tomar tú

- **Cuenta personal o de grupo** para publicar (afecta a ingresos, colaboradores y servidores privados).
- **Precios definitivos** de pases y productos (los configurados son una propuesta).
- **Usar o no los 9 modelos CC-BY** de `assets-source/`: si se usan, hacen falta créditos visibles.
- **Idioma de la ficha** y política de moderación del chat (el chat imitado ya filtra y escapa RichText).
- **Umbrales de salida** (retención, crashes, conversión): `docs/launch/metrics.md`.

---

## G. Checklist de cierre de la fase 10

| Criterio del plan | Estado | Quién |
| --- | --- | --- |
| 8 jugadores completan Historia | Pendiente | Tú (E.1) |
| Streaming ≥30 FPS en móvil de gama media | Parcial: hitch máximo de tesela 115 ms en Studio (presupuesto 150 ms); falta FPS en dispositivo | Tú (E.2) |
| Bloque de tesela ≤150 ms o fuera del hilo principal | Hecho: 115 ms máx., 54–62 ms típico, 6–7 teselas/s | Agente |
| Móvil y mando jugables; UI táctil sin solaparse | Parcial: simulación A06/iPhone verificada y solape AMIGOS/salto corregido; falta dispositivo y mando | Tú (E.2, E.3) |
| Récords solo en Modo Puro | Hecho en código; falta prueba en producción | Tú (E.4) |

Cuando completes A–E, dilo y se cierra la fase 10 con `/ponytail-audit`, `/ponytail-debt` y `graphify . --update`.
