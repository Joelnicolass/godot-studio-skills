# unlockkit_lab

- **Qué es:** un proyecto Godot chico que corre el ejemplo y los tests de UnlockKit sin ningún juego.
- **Qué no es:** un juego. `addons/unlock_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles, y `test_examples` juega `minimal` con clics en las cajas de la vista y con sus botones.
- **Verificar:** `godot --headless --path unlockkit_lab --script res://addons/unlock_kit/tests/unlock_test_runner.gd` → `UNLOCKKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path unlockkit_lab --import`). El proyecto tiene encendidos los avisos de tipado estricto (`[debug]` en `project.godot`).
- **Chequeo del editor:** `godot --headless --editor --path unlockkit_lab -- --unlockkit-editor-check` → `UNLOCKKIT EDITOR CHECK PASS (n)`. El plugin `editor_check` solo actúa con ese argumento (sin él, abrir el lab es normal). Abre una copia temporal de `minimal.tscn` en el editor, mira que la vista dibuje una caja por entrada, cambia valores de las entradas como el inspector (`view_position`, `cost`, `start_unlocked`, un `requires` que cierra un círculo) y renombra una como el panel Escena, deshace con Ctrl+Z, guarda con el guardado del editor y al terminar borra la copia. Es el único chequeo que pasa por el editor real y **no reemplaza** mirar la vista con los ojos.
- **Jugar:** abrí el proyecto. F5 corre `minimal`; abrí `minimal.tscn` para ver el árbol dibujado en el editor.
