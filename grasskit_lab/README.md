# grasskit_lab

- **Qué es**: un proyecto Godot chico que corre los ejemplos y los tests de GrassKit sin ningún juego.
- **Qué no es**: un juego. `addons/grass_kit` es un symlink a la copia del propio kit.
- **Con qué habla**: con nada más. Los tests arman sus propias escenas; `test_examples` juega los dos ejemplos (`minimal_3d`, `grass_3d`) con sus propias teclas y métodos.
- **Cómo se chequea**: `godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd` da `GRASSKIT TESTS PASS (n)`.
  - Un solo archivo: `-- --only=test_field`.
  - Después de agregar un script con un `class_name` nuevo, importá una vez primero: `godot --headless --path grasskit_lab --import`.
- **Chequeo del editor**: `GRASSKIT_EDITOR_CHECK=1 godot --headless --editor --path grasskit_lab` maneja un editor real como lo hace una persona e imprime `EDITOR CHECK PASS`:
  - el pasto alrededor de la vista 3D, el aviso de suelo plano, Bake ground y su deshacer;
  - seleccionar el campo, pintar con el mouse (Ctrl borra), deshacer y rehacer, las teclas, guardar la escena;
  - el pincel Kind, Fill y Clear del menú;
  - las asas del área y de un claro;
  - un campo nuevo que se arma solo, un botón de preset de calidad.

  Trabaja sobre una copia del ejemplo en `scratch/editor_check/` (los archivos del addon quedan como están). Lo hace el plugin propio del lab, `addons/grasskit_editor_check`; sin esa variable no hace nada.
  - `GRASSKIT_EDITOR_SHOTS=<carpeta> godot --editor --path grasskit_lab` (con ventana) guarda lo que muestra la vista 3D, y el editor entero con un pincel en la mano.
- **Horneado del color del suelo** (renderiza, así que necesita una ventana): `godot --path grasskit_lab --script res://checks/bake_color_check.gd` (y con `--rendering-method gl_compatibility`) imprime `BAKE COLOR CHECK PASS`; `BAKE_COLOR_PNG=<archivo>` guarda la imagen.
- **Globales de shader**: `project.godot` declara los de GrassKit (como hace el plugin), así el shader del suelo del ejemplo compila desde el principio.
- **Cómo se juega**: abrí el proyecto. F5 corre `grass_3d`; `godot --rendering-method gl_compatibility --path grasskit_lab` lo corre en Compatibility.
