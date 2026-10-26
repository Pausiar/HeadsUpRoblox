# Registro de decisiones

Formato: número · fecha · decisión · por qué · alternativa descartada. Solo decisiones que condicionan trabajo futuro.

| # | Fecha | Decisión | Por qué | Alternativa descartada |
| --- | --- | --- | --- | --- |
| D1 | 2026-10-26 | `docs/PLAN.md` es la fuente de verdad: se copia el original de Downloads al repo y a partir de ahora se edita la copia del repo | El plan debe versionarse junto al código | Mantener el plan fuera del repo |
| D2 | 2026-10-26 | Mapa Rojo: `src/server` → ServerScriptService, `src/client` → StarterPlayerScripts, `src/shared` → ReplicatedStorage/Shared | Config, Types, Remotes, Util y Localization deben replicarse a cliente y servidor | `src/shared` en ServerStorage (el cliente no lo vería) |
| D3 | 2026-10-26 | `graphify-out/` queda fuera de Git | El grafo se regenera con `/graphify .` y envejece rápido | Commitear el grafo |
| D4 | 2026-10-26 | Herramientas Roblox gestionadas con rokit (`rokit.toml` fija versiones por repo) | El plan §3.2 incluye `rokit.toml`; garantiza la misma versión de Rojo en todas las máquinas | Rojo instalado suelto (derivas de versión) |
| D5 | 2026-10-26 | Publicación desde la **cuenta personal** de Pausiar | Decisión del creador (26-10-26); los servidores privados de pago también funcionan en cuenta personal | Grupo de Roblox (revisar si cambian ingresos/funciones) |
| D6 | 2026-10-26 | Los .glb de `3DModels/` van por **Git LFS** (108 MB en total; el mayor 90 MB) | El usuario lo pidió; evita repos lentos y rozar el límite duro de 100 MB de GitHub | Mantenerlos como blobs normales |
| D7 | 2026-10-26 | El spike S1 (EditableImage) queda **bloqueado hasta verificar la ID** de la cuenta (cuenta 13+, pendiente hoy 26-10-26). Mientras, todo trabajo de camisetas usa el plan B | EditableImage falla por defecto en experiencias publicadas sin verificación (plan §2.1) | Intentar S1 igual y asumir el fallo |
| D8 | 2026-10-26 | Ante conflicto doc de diseño vs PLAN.md: **gana PLAN.md** (2–8 jugadores; sin fotos en camisetas; El Doble se añade en fase 3) | El plan es la fuente de verdad cerrada; el doc de diseño es material de origen | Seguir el doc de diseño original |
