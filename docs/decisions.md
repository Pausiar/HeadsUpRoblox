# Registro de decisiones

Formato: número · fecha · decisión · por qué · alternativa descartada. Solo decisiones que condicionan trabajo futuro.

| # | Fecha | Decisión | Por qué | Alternativa descartada |
| --- | --- | --- | --- | --- |
| D1 | 2026-10-26 | `docs/PLAN.md` es la fuente de verdad: se copia el original de Downloads al repo y a partir de ahora se edita la copia del repo | El plan debe versionarse junto al código | Mantener el plan fuera del repo |
| D2 | 2026-10-26 | Mapa Rojo: `src/server` → ServerScriptService, `src/client` → StarterPlayerScripts, `src/shared` → ReplicatedStorage/Shared | Config, Types, Remotes, Util y Localization deben replicarse a cliente y servidor | `src/shared` en ServerStorage (el cliente no lo vería) |
| D3 | 2026-10-26 | `graphify-out/` queda fuera de Git | El grafo se regenera con `/graphify .` y envejece rápido | Commitear el grafo |
| D4 | 2026-10-26 | Herramientas Roblox gestionadas con rokit (`rokit.toml` fija versiones por repo) | El plan §3.2 incluye `rokit.toml`; garantiza la misma versión de Rojo en todas las máquinas | Rojo instalado suelto (derivas de versión) |
