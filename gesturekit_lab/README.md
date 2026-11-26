# gesturekit_lab

- **Qué es:** un proyecto Godot chico que corre el ejemplo y los tests de GestureKit sin ningún juego.
- **Qué no es:** un juego. `addons/gesture_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles y mandan los dedos por la entrada de Godot (`Input.parse_input_event`). `test_examples` juega `minimal` con dedos al ritmo de una pantalla.
- **Verificar:** `godot --headless --path gesturekit_lab --script res://addons/gesture_kit/tests/gesture_test_runner.gd` → `GESTUREKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path gesturekit_lab --import`). El proyecto tiene encendidos los avisos estrictos de GDScript (`untyped_declaration` y `unsafe_*`).
- **Instalar en un proyecto vacío:** creá una carpeta con un `project.godot` mínimo, corré `./install.sh --addon-only <carpeta> gesture_kit` desde la raíz del repo, importá (`godot --headless --path <carpeta> --import`) y corré los tests del kit ahí (`--script res://addons/gesture_kit/tests/gesture_test_runner.gd`). Tiene que dar el mismo `PASS`.
- **Jugar:** abrí el proyecto y apretá F5 para correr `minimal`. Con el mouse, un clic es un dedo, Alt + arrastrar son dos y Alt + Shift + arrastrar los mueve juntos. En un teléfono, exportalo o usá el deploy remoto de Godot.
- **Chequeo del editor:** `godot --headless --editor --path gesturekit_lab -- --gesturekit-editor-check` → `GESTUREKIT EDITOR CHECK PASS (n)`.
  - El plugin `editor_check` solo actúa con ese argumento; sin él, el lab abre normal.
  - Mira que `GestureArea` esté registrado con su ícono y abre `minimal.tscn` en la vista 2D.
  - Mira que el inspector muestre `units` y los umbrales.
  - Edita el área desde el inspector: un umbral que llega al reader y se deshace con el atajo, una acción que no existe (aviso), una que sí, y `mouse_filter` en `Ignore` (aviso, y se deshace).
  - Nunca guarda el ejemplo: guarda una copia en `editor_check/tmp`, la revisa y la borra. Al final comprueba que el ejemplo en disco no cambió.
  - Es el único chequeo que pasa por el editor real y **no reemplaza** probar los gestos con los dedos.
