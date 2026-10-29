# Heads Up! Mountain Mayhem · Plan de desarrollo para Roblox

*Versión 1.0 · 26 de octubre de 2026 · Preparado para Z.Code con GLM-5.3 y GLM-5.3-Flash*

## 1. Resumen y decisiones cerradas

Heads Up! Mountain Mayhem es un friendslop cooperativo de 2 a 8 jugadores. El grupo recorre un bosque lleno de rocas, árboles y objetos absurdos que caen, intenta llegar al final y se ríe del caos por el camino. Encima de eso vive El Doble: un monstruo que copia la skin de un jugador, imita su chat e intenta raptarlo.

| Tema | Decisión |
| --- | --- |
| Herramientas | Z.Code + GLM-5.3 (sistemas complejos) y GLM-5.3-Flash (tareas rápidas y visuales) |
| Conexión con Roblox | MCP integrado de Studio + Rojo (código en disco) |
| Cámara | Tercera persona por defecto, con opción de primera persona |
| Jugadores | Lobby flexible de 2 a 8 |
| Modos | Historia por etapas y Rondas rápidas |
| Monetización | Cosméticos + comodidad + ventajas ligeras con límites |
| Personalización | Proporciones del cuerpo + camisetas con editor de pintura y pegatinas |
| Monstruo | Solo de noche, en biomas oscuros o tras cierto progreso; copia skin y simula chat |
| Assets | Tus .obj de Sketchfab si pasan la prueba; si no, construcción con código y primitivas |
| Idioma | Español e inglés desde el principio |

## 2. Lo que Roblox cambia respecto al concepto

Conviene conocer estos puntos antes de escribir una línea, porque cambian el diseño.

1. **La foto en la camiseta no es viable tal cual.** Un jugador no puede subir una imagen de su dispositivo dentro de la experiencia. La alternativa es un editor de pintura con EditableImage (pincel, cubo, pegatinas, texto filtrado). Ojo: EditableImage falla por defecto en experiencias publicadas; hace falta que la cuenta creadora tenga 13+ y verificación de identidad, y activarlo en Studio. Sin eso, el plan B son diseños prefabricados con color y pegatinas como decals.
2. **El chat falso no puede ser un jugador falso.** Roblox no permite crear jugadores que no existen. El servidor decide el texto y los clientes lo muestran con TextChatService (mensaje con formato de chat y burbuja sobre el personaje). Todo texto reciclado de jugadores reales pasa por TextService:FilterStringAsync, filtrado para cada receptor.
3. **Los .obj de Sketchfab tienen dos filtros: técnico y legal.** Técnico: se importan con el 3D Importer y hay límites de triángulos y texturas. Legal: las licencias NC (no comercial) no sirven para un juego que vende con Robux, CC-BY exige atribución y SA/ND pueden dar problemas. Cada modelo entra en un registro de licencias antes de importarse.
4. **Compras aleatorias de pago.** Si algún día hay cofres o ruletas, Roblox exige mostrar todos los resultados posibles y las probabilidades numéricas, también en compras indirectas (llaves, gemas), y comprobar PolicyService. La v1 evita el problema: solo compras directas.
5. **MCP: usa el integrado, no el antiguo.** El servidor Rust de Roblox ya no se desarrolla y lo recomendado es el MCP incluido en Studio.
6. **Rojo y MCP no deben editar el mismo script.** Rojo sincroniza del disco a Studio; si el MCP edita un script sincronizado, Rojo lo sobrescribe. Regla: scripts en disco; MCP para escena, playtest, capturas y consola.

## 3. Arquitectura técnica

### 3.1 Flujo de trabajo

- **Rojo:** fuente de verdad del código Luau y de Git. Además permite que graphify y ponytail lean los archivos; sin Rojo el código viviría dentro del .rbxl y las skills no lo verían.
- **MCP de Studio:** explorar el DataModel, insertar assets, execute\_luau, play/stop, consola, capturas de pantalla, simulación de teclado y ratón, y subagente de playtest.
- **Verificación visual:** Flash compara screen\_capture con las capturas del concepto.

### 3.2 Estructura del repositorio

```
heads-up-roblox/
├─ default.project.json  rokit.toml  AGENTS.md
├─ docs/  PLAN.md  skill-log.md  decisions.md  asset-log.md  concept/
├─ assets-source/        (.obj originales y licencias)
└─ src/
   ├─ server/  MatchService, StageService, HazardService, RevivalService,
   │           MonsterService, ChatMimicService, CustomizationService,
   │           DataService, MonetizationService
   ├─ client/  CameraController, InputController, HUD, Menus,
   │           CustomizationUI, ChatMimicView, FX
   └─ shared/  Config/ (datos), Types, Remotes, Util, Localization
```

### 3.3 Principios

- Servidor autoritativo: distancia, daño, estado de caída, compras y recompensas.
- Remotes tipados y validados, con limitación de frecuencia en todos.
- Todo configurable por datos (peligros, etapas, frases, precios) en ModuleScripts de Config.
- Presupuestos de rendimiento desde el día uno: máximo de objetos físicos activos, pooling y StreamingEnabled en el mapa grande. Los valores concretos se miden en el spike S4.
- Persistencia con DataStore (UpdateAsync, reintentos, guardado al salir y periódico): monedas, cosméticos, ajustes, camisetas y récords. El ranking de amigos usa OrderedDataStore.

### 3.4 Estados del jugador

Sano → Golpeado (ragdoll breve) → Caído (cuenta atrás; los compañeros lo reaniman con ProximityPrompt) → Eliminado (espectador) o Reanimado. Si cae todo el grupo, la partida termina con la pantalla «¡Has caído!».

### 3.5 Cámara y controles

Tercera persona por defecto y atajo a primera persona (con brazos visibles, como en el HUD del concepto). Acciones: correr, saltar, agacharse, esquivar e interactuar. Desde el principio hay mapeo táctil y de mando, porque gran parte del público de Roblox juega en móvil.

## 4. Diseño de juego

### 4.1 Bucle principal

Lobby → equipo listo → etapa → peligros y cooperación → refugio o checkpoint → siguiente etapa → resultados (distancia, tiempo, puntos, récord personal y ranking de amigos) → reintentar.

### 4.2 Modos

- **Historia:** etapas con checkpoints y refugios entre etapas. La v1 incluye tres: Bosque verde (aprender las físicas), Bosque oscuro (poca visibilidad, caminos que se bifurcan, aparece El Doble) y Bosque gigante (árboles enormes, puentes precarios).
- **Rondas rápidas:** 5–8 minutos. El camino se arma con segmentos modulares combinados con una semilla aleatoria y la dificultad sube con la distancia. Da rejugabilidad y sirve de banco de pruebas.
- **Biomas futuros** del documento de diseño: nevado, pantano, bosque en llamas y ruinas antiguas.

### 4.3 Peligros

Todos siguen el patrón Aviso → Impacto → Secuela. El aviso dura entre 1,5 y 2,5 s (sombra en el suelo, sonido, cartel de peligro) para que cada golpe sea justo y gracioso.

| Peligro | Comportamiento | Cooperación |
| --- | --- | --- |
| Rocas | Caen o ruedan por pendientes | Empujar o esquivar juntos |
| Árboles | Se caen y bloquean el sendero | Levantar o apartar entre varios |
| Troncos rodantes | Barren el camino | Saltar en equipo |
| Lluvia de objetos | Eventos aleatorios, patos de goma gigantes incluidos | Cubrirse |
| Barrancos y puentes | Caída a zona mortal o desvío | Cuerdas y palancas |
| Niebla y noche | Menos visibilidad | Linternas y mantenerse juntos |

### 4.4 Cooperación o fastidio

Arrastrar y levantar compañeros, cuerdas, palancas, cargas que piden varias manos, reanimar, y empujar a un amigo por diversión. Hay que cuidar que el trolleo sea divertido y no griefing: colisión suave entre jugadores, opción de modo amistoso y reportes.

### 4.5 Puntuación

Distancia (m), tiempo y puntos. Los puntos premian ayudar (reanimar, rescatar del Doble) más que la velocidad. Las Piñas (moneda blanda) se ganan jugando y compran cosméticos.

## 5. El Doble

### 5.1 Reglas de aparición

Solo de noche, en biomas oscuros o tras un progreso mínimo de la etapa (valor en Config, a ajustar). Al principio hay una sola aparición activa por partida; con 6–8 jugadores puede haber dos.

### 5.2 Fases

| Fase | Qué ocurre | Pistas para el grupo |
| --- | --- | --- |
| 0. Latente | No existe | — |
| 1. Observación | Elige a una víctima (nunca la misma dos veces seguidas) y copia su aspecto | Una figura quieta entre los árboles |
| 2. Infiltración | Camina con el grupo y escribe como la víctima | Fallos sutiles: tiempos de escritura raros, sin sonido de pasos, no reacciona a los peligros |
| 3. Acecho | Separa a la víctima del grupo con mensajes («estoy aquí, ven») | El chat dice cosas que el jugador real no dijo |
| 4. Rapto | Revela su forma, agarra a la víctima y la arrastra a su madriguera | Alarma sonora y música |
| 5. Retirada | Enfriamiento largo antes de otro intento | — |

### 5.3 Contrajuego

La linterna delata al Doble (ojos y sombra). El grupo puede acordar una palabra clave por chat. Las bengalas lo aturden. Los compañeros pueden liberar a la víctima durante una ventana de rescate. Quien va solo es presa fácil, y eso empuja a jugar en equipo.

### 5.4 Ataques a los compañeros

Empujones, lanzarlos contra un peligro y tirones fuera del sendero. Causan estado (golpeado o caído), no eliminación instantánea. Hay un máximo de raptos por partida y la víctima siempre tiene opción de rescate.

### 5.5 Chat falso

- **Memoria de chat:** guarda en memoria, solo durante la sesión y sin DataStore, las últimas \~30 frases filtradas de cada jugador.
- **Generación:** \~60% frases reales de la víctima y \~40% de un banco curado por categorías (saludo, queja, pánico, pregunta, broma, pedir ayuda) en español e inglés.
- **Contexto:** si alguien pregunta «¿dónde estás?», responde «aquí, ven»; cuando la víctima se aleja, pide ayuda; cerca de un barranco, invita a acercarse.
- **Realismo:** simula que escribe con un retardo proporcional a la longitud, y a veces con erratas.
- **Seguridad:** cero texto libre, banco sin insultos, todo pasa por TextService:FilterStringAsync por receptor, frecuencia limitada y un ajuste «Modo cómico» que lo suaviza.
- **Aviso previo:** el tutorial explica que El Doble puede imitar el chat, para que sea un reto y no un engaño.

### 5.6 Copia de skin

A partir de la HumanoidDescription y del personalizador del jugador, con diferencias sutiles (por ejemplo, accesorios reflejados o una cara ligeramente distinta).

## 6. Personalización de personaje

- **Cuerpo:** altura, ancho (el «peso») y tamaño de cabeza con las escalas de Humanoid de R15. La longitud independiente de brazos y piernas no existe como escala estándar: se evalúa en el spike S5 y, si es costosa, pasa a la versión 2.
- **Camisetas:** editor de pintura sobre una plantilla (pincel, cubo, pegatinas, texto filtrado, paleta) con EditableImage sobre una malla superpuesta al torso. Se guarda como imagen indexada por paleta y comprimida (los DataStores tienen límite de tamaño) y se replica a los demás clientes como búfer.
- **Fotos:** no desde el dispositivo. Opción futura: estampar imágenes por ID de asset, sujeto a permisos y moderación.
- **Plan B sin EditableImage:** camisetas prefabricadas, tinte de color y pegatinas como Decals.
- **Ranuras:** 3 gratis; más con monetización.
- Todo contenido de texto pasa por el filtro de Roblox.

## 7. Monetización

### 7.1 Principios

Cosméticos primero. La comodidad es ayuda para disfrutar, no para saltarse el juego. Las ventajas ligeras tienen techo. Nada de compras aleatorias de pago en la v1. Nada que salte etapas.

### 7.2 Catálogo (precios en Robux, hipótesis inicial para probar)

| Categoría | Producto | Tipo | Precio inicial |
| --- | --- | --- | --- |
| Cosmético | Packs de skins, sombreros, mochilas, emotes y estelas | Pase o producto | 49–399 |
| Cosmético | Pack de pegatinas premium y ranuras de camiseta extra (3→9) | Pase | 99–199 |
| Comodidad | Reanimación personal (1 por partida) | Producto de desarrollador, consumible | 25 / pack de 5 a 99 |
| Comodidad | Baliza personal de checkpoint en Historia | Pase | 149 |
| Comodidad | Doble de Piñas durante 30 min | Producto | 49 |
| Ventaja ligera | Mochila Pro: +1 espacio de inventario (4→5) | Pase | 199 |
| Ventaja ligera | Botas de agarre: +8% de adherencia en pendientes | Pase | 149 |
| Ventaja ligera | Linterna Pro: cono hasta +15% y color propio | Pase | 149 |
| Social | Servidores privados de pago (ideal para grupos de amigos) | Función de Roblox | A decidir |
| Recurrente | Club Montañero (suscripción): cosméticos mensuales y etiqueta VIP | Suscripción | A validar |

### 7.3 Guardarraíles de equilibrio

- Las ventajas tienen techo y no hacen inmune a nada.
- El ranking «Puro» desactiva las ventajas y las reanimaciones de pago, y es el que cuenta para récords.
- La reanimación de pago está limitada por partida y también se puede ganar con Piñas.
- Tiendas sin presión agresiva y con precios honestos. Roblox lo recomienda con claridad, sobre todo con menores.

### 7.4 Implementación

Compras y entrega siempre en el servidor (ProcessReceipt para productos; comprobación de pases al entrar y tras comprar). Comprobar PolicyService aunque la v1 no tenga aleatorios. Precios a validar con pruebas A/B y la herramienta de optimización de precios del panel de creador.

## 8. UI/UX

- **Identidad:** la del concepto (madera, carteles, cartoon, paleta verde, amarillo, naranja y marrón), con tipografías claras y manuales.
- **Pantallas:** Inicio/Lobby, HUD, Ajustes (en multijugador no se pausa el juego: es un menú superpuesto), ¡Has caído!, Resultados, Personalización y Tienda.
- **Móvil y mando:** zonas seguras, botones táctiles, objetivos de toque amplios, UIScale, contraste y texto legible.
- **Accesibilidad:** opción de reducir efectos, sacudidas y destellos; subtítulos para los avisos sonoros; señales críticas aptas para daltonismo.
- **Localización** ES/EN desde el primer texto (tabla de traducción).
- **Skills de diseño como revisores:** apple-design como lente de accesibilidad, flujos y compras; hallmark para extraer el ADN visual del concepto y para cualquier página web del juego.

## 9. Hoja de ruta

| Fase | Contenido | Hecho cuando |
| --- | --- | --- |
| 0. Preparación y spikes | Skills, MCP, Rojo, Git, graphify base y spikes S1–S6 | Todo verificado y riesgos medidos |
| 1. Vertical slice | 1 etapa corta, 2 peligros, 2–4 jugadores, cámara 3ª/1ª, HUD básico, caído y reanimar | Se juega de principio a fin con amigos |
| 2. Núcleo | Lobby 2–8, Historia (etapas 1–2), Rondas rápidas, checkpoints, resultados, guardado y ranking de amigos | Partida completa en cada modo, 8 jugadores estables |
| 3. El Doble | Fases, copia de skin, chat falso, contrajuego y equilibrio | Pruebas con grupos reales: da miedo y risa, no frustra |
| 4. Personalización | Editor de cuerpo y camisetas, guardado y réplica | Se ve igual en todos los clientes y se guarda |
| 5. Monetización | Tienda, pases, productos, cosméticos, privados y ranking Puro | Compras probadas en entorno de prueba, entrega desde servidor |
| 6. Pulido | Rendimiento, móvil y mando, accesibilidad, localización, audio, VFX, revisión de moderación y telemetría | Presupuestos cumplidos y beta cerrada sin bloqueantes |
| 7. Lanzamiento y vivo | Soft launch, métricas, nuevos biomas y eventos | Retención y tasa de reintento medidas |
| 8. Terreno y rutas | Terreno voxel determinista, rutas Catmull-Rom, etapas y ronda rápida sobre rutas, progreso por altura | Ruta completa jugable con spawn y checkpoints estables |
| 9. Mundo largo y economía | Ruta de 4846 studs por teselas con streaming, meta con victoria, tienda del campamento, peligros diegéticos y Piñas en vivo | Partida completa hasta la meta con compras y economía funcionando |
| 10. QA multijugador y rendimiento | Partidas de 2–8 en servidor real, móvil real, mando + 1.ª persona, perfilado del streaming de teselas con 8 jugadores y Modo Puro sin ventajas | 8 jugadores completan Historia sin errores; el streaming se mantiene ≥30 FPS en móvil de gama media y el tirón por tesela ≤0,15 s o sale del hilo principal; móvil y mando jugables; récords solo en Puro |

Estimación orientativa, a validar tras los spikes: la v1 jugable (fases 0–3) en unas 6–8 semanas a ritmo constante y el lanzamiento completo en 3–4 meses. A 2026-10-29 las fases 0–9 están cerradas en Studio; la 10 depende de hardware real y de una partida de 8.

### Spikes de la fase 0

- **S1:** EditableImage sobre el torso (rendimiento y réplica).
- **S2:** importar 2–3 .obj de Sketchfab con licencia válida (calidad, triángulos, texturas).
- **S3:** mensaje falso en el chat con TextChatService en los clientes.
- **S4:** físicas de rocas con 8 jugadores (red y rendimiento).
- **S5:** límites de escalado del cuerpo R15.
- **S6:** graphify leyendo Luau.

### Criterios de la fase 10

- **Multijugador:** 2, 4 y 8 jugadores en la misma partida; sin desincronización de checkpoints, Piñas, reanimaciones ni raptos de El Doble.
- **Móvil real:** gama media y gama baja; UI táctil sin solaparse con el thumbstick y texto legible al escalar.
- **Mando:** sprint, beber, linterna, cámara 1.ª/3.ª y reanimar sin teclado.
- **Rendimiento:** perfilar `TerrenoService` con 8 jugadores; una tesela por tick no puede bloquear el servidor más de 150 ms. Si lo supera, generar por presupuesto de tiempo o mover la construcción a un hilo aparte.
- **Modo Puro:** partida sin ventajas de pase; el ranking de amigos no registra marcas con ventajas.
- **Regresión:** la matriz `docs/launch/qa-matrix.md` se amplía con estos casos y se marca cada uno con evidencia.

## 10. Reparto de trabajo entre GLM-5.3 y Flash

- **GLM-5.3:** arquitectura, sistemas del servidor (MatchService, HazardService, MonsterService, ChatMimicService, DataService), networking, refactors y revisión final de cada fase.
- **GLM-5.3-Flash:** maquetación de UI, datos y Config, localización, boilerplate, pruebas rápidas y verificación visual. Es multimodal, así que puede comparar capturas de Studio con las del concepto.
- Los subagentes heredan las mismas reglas de skills (AGENTS.md).
- Aunque el contexto sea muy grande, se usa graphify para no releer el proyecto cada vez.

## 11. Calidad y riesgos

Playtests con el MCP (start\_stop\_play, get\_console\_output, screen\_capture, subagente playtest) más sesiones reales con 4–8 amigos.

| Riesgo | Mitigación |
| --- | --- |
| Desincronización de físicas | Peligros con aviso, autoridad del servidor y presupuesto de objetos |
| Rendimiento con 8 jugadores y en móvil | Spike S4, StreamingEnabled, pooling y perfiles en móvil |
| EditableImage no disponible | Plan B de camisetas prefabricadas |
| Licencias de Sketchfab | Registro por modelo y descarte de NC |
| Moderación del chat imitado | Filtro por receptor, sin texto libre, banco curado y aviso en el tutorial |
| El Doble frustrante | Máximos de raptos, rescate y Modo cómico |
| Pay-to-win | Techos de ventaja y ranking Puro |
| Cambios en las APIs de Roblox | Consultar la documentación antes de codificar |

## 12. Lo que necesito de ti

- Lista de tus .obj (nombre, enlace de Sketchfab y licencia).
- Las imágenes del concepto en `docs/concept/` (las tres que has compartido y cualquier otra).
- Confirmar si tu cuenta de Roblox está verificada con ID (afecta a EditableImage).
- Tu sistema operativo (Windows o macOS) para los comandos de instalación.
- Si el juego será de un grupo de Roblox o de tu cuenta personal (afecta a ingresos y a servidores privados).
