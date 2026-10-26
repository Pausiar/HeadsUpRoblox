# Design DNA (ADN visual) — extraído de docs/concept/

Fuentes: `concepto-ui-pantallas.png` y `concepto-design-doc.png` (2026-10-26). Este archivo es insumo obligatorio de las revisiones de **apple-design** en cada pantalla, HUD, tienda o editor. Los hex son aproximados a ojo: calibrar con el gotero sobre las imágenes antes de crear tokens definitivos.

## Tema y material

Madera y carteles del bosque. Todo panel es una tabla de madera con bordes redondeados, vetas, clavos y cuerdas; los botones son tablones o carteles colgantes; los títulos se sienten tallados o pintados a mano. Estilo cartoon con bordes suaves. Taglines del concepto: «No mires solo al frente…» / «Un bosque. Mil desastres. Tus amigos.» / «¡Porque en el bosque… la realidad es opcional!»

## Paleta (8 swatches del concepto, roles propuestos)

| Color | Hex aprox. | Rol reservado |
| --- | --- | --- |
| Verde bosque | `#4C8C4A` | Acción primaria (JUGAR, CONTINUAR, APLICAR, GUARDAR) |
| Verde lima | `#8BC34A` | Barras de estado/estamina, positivos |
| Amarillo | `#FFC93C` | Destacados, récord/corona, Piñas (moneda) |
| Naranja | `#F28C28` | Advertencias, peligro medio, acentos cálidos |
| Rojo | `#E0453A` | Peligro, daño, salida |
| Azul | `#3F7FBF` | Información, toggles, selección secundaria |
| Crema | `#F5EBD8` | Superficies de texto y fondos de panel |
| Marrón | `#5C3A21` (oscuro `#3E2A18`) | Contenedores, madera, texto sobre crema |

Regla: texto crema sobre madera oscura, o marrón oscuro sobre crema. Verde solo para la acción primaria; nada más compite con él.

## Tipografía

- **Display / logo:** lettering tipo pincel-marcador, inclinado, con borde grueso («HEADS UP!»). En Roblox, buscar fuente cartoon gruesa equivalente; a validar en Studio (spike de UI, fase 1).
- **Titulares:** sans chunky redondeada, mayúsculas, siempre del mismo peso y color por pantalla (principio hallmark: una idea por pantalla, un tipo de titular).
- **Cuerpo y etiquetas:** sans legible, tamaño grande, sin versalitas ni tracking; etiquetas en minúscula u oración, nunca en mayúsculas espaciadas.

## Iconografía

Iconos simples con contorno: corazón (vida), corona (récord/ranking), estrella (puntos), reloj (tiempo), regla/flecha (distancia), zapato (acciones rápidas). Nunca emoji como icono.

## Pantallas del concepto (una idea por pantalla)

Inicio/Lobby (grupo mirando al bosque + menú vertical) · HUD (ranking de amigos arriba-izq, panel de distancia/tiempo/puntos arriba-der, estamina abajo, controles mapeados, brazos en 1ª persona) · Pausa · ¡Has Caído! · Personalización (pestañas Cuerpo/Ropa/Accesorios con sliders de proporciones y editor de camiseta) · Resultados (métricas + clasificación de amigos) · Ajustes (pestañas Juego/Gráficos/Sonido/Controles, con toggle de «Chat de proximidad»).

## Movimiento

Animaciones sutiles al aparecer/desaparecer; sin sacudidas ni destellos fuertes (accesibilidad §8 del plan). Transiciones de paneles con deslizamiento corto, nunca `transition: all`.

## Diferencias concepto vs. PLAN.md (gana el plan)

- El doc de diseño habla de **2–4 jugadores**; el plan cierra **2–8**.
- El doc propone fotos propias en camisetas; el plan lo sustituye por editor de pintura con EditableImage (§2.1) — correcto para Roblox.
- El doc no incluye El Doble: se añade en fase 3 según plan §5.
