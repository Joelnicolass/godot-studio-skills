# propkit_lab

- **Qué es**: un proyecto Godot chico que corre los ejemplos y los tests de PropKit sin ningún juego.
- **Qué no es**: un juego. `addons/prop_kit` es un symlink a la copia del propio kit.
- **Con qué habla**: con nada más. Los tests arman sus propias escenas; `test_examples` juega los tres ejemplos (`minimal_3d`, `forest_3d`, `grove_2d`) a través de sus propios métodos (talar, bosque nuevo, otra semilla).
- **Cómo se chequea**: `godot --headless --path propkit_lab --script res://addons/prop_kit/tests/prop_test_runner.gd` da `PROPKIT TESTS PASS (n)`.
  - Un solo archivo: `-- --only=test_nav_zones_3d`.
  - Después de agregar un script con un `class_name` nuevo, importá una vez primero: `godot --headless --path propkit_lab --import`.
- **Chequeo del editor**: `PROPKIT_EDITOR_CHECK=1 godot --headless --editor --path propkit_lab` maneja un editor real (Scatter, Clear, deshacer y rehacer, Bake, el aviso de horneado vencido) e imprime `EDITOR CHECK PASS`. Lo hace el plugin propio del lab, `addons/propkit_editor_check`; sin esa variable no hace nada.
  - `PROPKIT_EDITOR_SHOTS=<carpeta> godot --editor --path propkit_lab` (con ventana, después del chequeo) guarda lo que dibujan las vistas 3D y 2D.
- **Chequeo de las herramientas**: `tool_check/` es un mapa cuyo script usa el autoload del lab (`PropLabGlobals`); `test_tools` lo hornea con `tools/bake_scene.tscn`.
- **Cómo se juega**: abrí el proyecto. F5 corre `forest_3d`; `grove_2d` es la versión 2D.
