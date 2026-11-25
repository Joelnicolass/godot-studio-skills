# turnkit_lab

- **Qué es:** un proyecto Godot chico que corre el ejemplo y los tests de TurnKit sin ningún juego.
- **Qué no es:** un juego. `addons/turn_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles, y `test_examples` juega `minimal` con sus botones.
- **Verificar:** `godot --headless --path turnkit_lab --script res://addons/turn_kit/tests/turn_test_runner.gd` → `TURNKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path turnkit_lab --import`).
- **Jugar:** abrí el proyecto. F5 corre `minimal`.
