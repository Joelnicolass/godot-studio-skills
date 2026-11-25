# commandkit_lab

- **Qué es:** un proyecto Godot chico que corre el ejemplo y los tests de CommandKit sin ningún juego.
- **Qué no es:** un juego. `addons/command_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles, y `test_examples` juega `minimal` con sus botones (clic, casilla ocupada, Undo, Replay).
- **Verificar:** `godot --headless --path commandkit_lab --script res://addons/command_kit/tests/command_test_runner.gd` → `COMMANDKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path commandkit_lab --import`).
- **Jugar:** abrí el proyecto. F5 corre `minimal`.
