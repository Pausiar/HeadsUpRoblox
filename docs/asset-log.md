# Registro de assets externos (spike S2)

Todo modelo externo se registra aquí ANTES de importarlo. Licencias NC (no comercial) quedan descartadas porque el juego vende con Robux. **Estado del lote: 9/9 APTOS — todos CC-BY 4.0** (uso comercial permitido; atribución obligatoria → ver `assets-source/CREDITS.md`).

| # | Archivo en `3DModels/` | Modelo | Autor | Licencia | Enlace | ¿Importable? | Notas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `free_low_poly_forest.glb` | Free Low Poly Forest | purepoly | CC-BY 4.0 | [sketchfab](https://sketchfab.com/3d-models/free-low-poly-forest-6dc8c85121234cb59dbd53a673fa2b8f) | pendiente S2 | 90 MB — en Git LFS; probar límites de tris |
| 2 | `low_poly_forest_pack_.free_3d_models.glb` | Low Poly Forest Pack .Free 3D Models | RenderHaven | CC-BY 4.0 | [sketchfab](https://sketchfab.com/3d-models/low-poly-forest-pack-free-3d-models-b17884c5fa7942fb97b48e1fb7d81ba5) | pendiente S2 | 0,2 MB |
| 3 | `free_pack_-_tree.glb` | Free Pack - Tree | PolyOne Studio | CC-BY 4.0 | [sketchfab](https://sketchfab.com/3d-models/free-pack-tree-196525a9936a40c1ba7e74ce5c071d59) | pendiente S2 | 4,6 MB |
| 4 | `free_pack_-_rocks_stylized.glb` | Free Pack - Rocks Stylized | PolyOne Studio | CC-BY 4.0 | [sketchfab](https://sketchfab.com/3d-models/free-pack-rocks-stylized-7c60b4d1b8ab4187965f30c5e0212fc0) | pendiente S2 | 7,9 MB — ⚠ la página indica que se basa en «Stylized stones minipack» de Sereda bajo *Sketchfab Free Standard License*: revisar esa sublicencia en S2 antes de usarlo en producción |
| 5 | `low-poly_toy_pack_teddy_bear__rubber_duck.glb` | Low-Poly Toy Pack (Teddy Bear & Rubber Duck) | Renend Studio | CC-BY 4.0 | [sketchfab](https://sketchfab.com/3d-models/low-poly-toy-pack-teddy-bear-rubber-duck-af885d4dd3514cc09ad6bdd446d2888c) | pendiente S2 | 5,4 MB — pato de goma gigante (peligro de lluvia de objetos) |
| 6 | `stylized_mushrooms_-_low_poly.glb` | Stylized Mushrooms - Low Poly | Camille Barral | CC-BY 4.0 | [sketchfab](https://sketchfab.com/3d-models/stylized-mushrooms-low-poly-33e4073b371a4fbd93e65bfb16473032) | pendiente S2 | 0,7 MB |
| 7 | `lowpoly_office_chair.glb` | Lowpoly Office Chair | sleepyjoshua | CC-BY 4.0 | [sketchfab](https://sketchfab.com/3d-models/lowpoly-office-chair-e5719afff2464e5e810115532e16cc05) | pendiente S2 | 0,4 MB |
| 8 | `backpack_low-poly.glb` | Backpack low-poly | dimaponomar2019 | CC-BY 4.0 | [sketchfab](https://sketchfab.com/3d-models/backpack-low-poly-d7225bdd1d6c42d992485d72438cab28) | pendiente S2 | 2,5 MB |
| 9 | `low_poly_character_rigged.glb` | Low poly character (rigged) | Sebastian Lague | CC-BY 4.0 | [sketchfab](https://sketchfab.com/3d-models/low-poly-character-rigged-b2ca55ab706c4b1ba1c6475d8b3c5bfd) | pendiente S2 | 0,4 MB — riggado |

Notas:
- Los archivos son **.glb** (GLTF binario), no .obj como decía el plan §1/§2 — el spike S2 verificará si el 3D Importer los acepta directamente o hay que convertir. Si la doc oficial de Roblox contradice al plan, gana la doc.
- Total ~108 MB; el mayor (90 MB) vive en Git LFS (decisión D6).
- CC-BY exige atribución: créditos en `assets-source/CREDITS.md` y, más adelante, pantalla de créditos dentro del juego (fase 6).

### Pre-chequeo técnico S2 (offline, 26-10-2026)

Los 9 archivos son GLB binarios válidos (glTF 2.0). Resultado por modelo (meshes · tris totales · tris del mayor mesh · texturas):

| Archivo | Meshes | Tris | Tris máx. | Texturas | Veredicto |
| --- | --- | --- | --- | --- | --- |
| backpack_low-poly.glb | 53 | 3.840 | 436 | 3 (2,2 MB) | ✓ importable |
| free_low_poly_forest.glb | **1.249** | **1.064.000** | 1.946 | 0 | ✗ tal cual NO — trocear/decimar en Blender o usar como referencia |
| free_pack_-_rocks_stylized.glb | 11 | 3.076 | 1.438 | 1 (7,8 MB) | ✓ importable (sublicencia Sereda pendiente) |
| free_pack_-_tree.glb | 8 | 7.253 | 1.365 | 1 (4,0 MB) | ✓ importable |
| low-poly_toy_pack_teddy_bear__rubber_duck.glb | 2 | 2.332 | 1.532 | 6 (5,2 MB) | ✓ importable |
| low_poly_character_rigged.glb | 1 | 1.648 | 1.648 | 1 (0,2 MB) | ✓ importable (1 skin) |
| low_poly_forest_pack_.free_3d_models.glb | 2 | 2.322 | 2.320 | 0 | ✓ importable |
| lowpoly_office_chair.glb | 2 | 5.040 | 3.040 | 0 | ✓ importable |
| stylized_mushrooms_-_low_poly.glb | 3 | 1.328 | 608 | 9 (0,7 MB) | ✓ importable |

Todo mesh individual está muy por debajo del límite práctico del 3D Importer (10k tris/mesh). El único bloqueante es el bosque de 90 MB (1,06 M tris en total). El límite exacto del importador se confirmará al importar de verdad: la doc accesible no lo detalla.

Incidente de proceso resuelto: tras `git lfs migrate`, el working tree quedó con punteros LFS sin *smudge* (los .glb eran texto `version https://git-lfs...`); restaurado con `git lfs checkout` (17/17 objetos locales).
