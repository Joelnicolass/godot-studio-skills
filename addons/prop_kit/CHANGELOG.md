# Changelog de PropKit

## 0.1.0

- **Scatter** (`PropScatter3D`, `PropScatter2D`): props sobre cualquier suelo como hijos guardados y editables, desde el inspector («Scatter», «Clear»), desde código (`scatter()`), desde el menú Herramientas o headless (`tools/scatter_scene.gd`). Determinista. `PropScatterRules` compartibles: grupos según un ruido, un espacio que crece con la escala, tamaño del borde al corazón de un grupo, un tope que corta en los bordes, hundir e inclinar con la pendiente (3D).
- **Suelos** (`PropGround`): `PropFlatGround` (un rect o un contorno), `PropRayGround` (3D: rayos contra cualquier collider, una pendiente máxima), o el del juego (`extends PropGround`). **Zonas prohibidas** por grupo (`PropKeepOut`), una **máscara** pintada (`PropMask`: raleo parcial con `density_strength`, `density_invert`), **variantes** con peso (`PropVariant`).
- **Dibujo en lotes** (`PropBatch3D`): un MultiMesh por tipo de parte y por cuadrado, las partes ocultas, un cuadrado redibujado cuando se va un prop, `refresh()`, `rebuild_all()`, un gancho `mesh_of`. Nada en el editor, headless ni en un servidor dedicado.
- **Navmesh por zonas** (`PropNavZones3D`, `PropNavZones2D`):
  - zonas cuadradas que se tocan justo, una región por zona sin edge connections, horneado e índice en hilos de trabajo (tareas propias del kit: liberar el nodo o cerrar a mitad de un horneado las espera, nunca se cuelga);
  - `rebake(areas, reparse)`, con un índice de los nodos de obstrucción por zona, y pedidos que se juntan mientras hornea;
  - aplicar en AUTO o MANUAL (`bake_ready`, `has_result()`, `is_done()`, `apply()` en orden de zona), `applied` y `synced`;
  - un horneado guardado (`PropNavBake`, «Bake», `save_bake()`) que carga de una y queda `stale` cuando cambian los props o el `extra_fingerprint` del juego;
  - horneado headless para CI (`tools/bake_scene.gd`; `--check` imprime un hash reproducible del contenido);
  - `stats` (PropNavStats).
- **Obstrucciones** (`PropObstructions`): los props del grupo `prop_obstruction` cortan el navmesh como obstrucciones proyectadas a partir de sus formas:
  - 3D: Cylinder, Capsule, Sphere, Box, ConvexPolygon y CollisionPolygon3D;
  - 2D: Circle, Rectangle, Capsule, ConvexPolygon y CollisionPolygon2D;
  - `merge_gap` junta props cercanos con un cierre que nunca tapa un paso más ancho que el hueco;
  - el fingerprint detecta un horneado vencido.
- **Índice** (`PropNavIndex`): componentes conexas entre zonas, el polígono y la componente en un punto, el punto caminable más cercano, el navmesh cosido.
- **Esquiva un bug de Godot 4.7**: una navmesh que se le pone a una región durante su iteración asíncrona anterior se pierde, así que el nodo de zonas guarda la pieza hasta que la región está lista.
- **Ejemplos**: `forest_3d` y `grove_2d` (con el suelo propio del juego). **Tests**: `propkit_lab` (54).
