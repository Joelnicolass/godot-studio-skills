# gridkit_lab

- **Qué es:** un proyecto Godot chico que corre el ejemplo y los tests de GridKit sin ningún juego.
- **Qué no es:** un juego. `addons/grid_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles, y `test_examples` juega `minimal_3d` con eventos de mouse.
- **Verificar:** `godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd` → `GRIDKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path gridkit_lab --import`).
- **Jugar:** abrí el proyecto. F5 corre `minimal_3d`.
