# propkit_lab

- **Qué es**: un proyecto Godot chico que corre los ejemplos y los tests de PropKit sin ningún juego.
- **Qué no es**: un juego. `addons/prop_kit` es un symlink a la copia del propio kit.
- **Con qué habla**: con nada más. Los tests arman sus propias escenas; `test_examples` juega los dos ejemplos a través de sus propios métodos (talar, bosque nuevo).
- **Cómo se chequea**: `godot --headless --path propkit_lab --script res://addons/prop_kit/tests/prop_test_runner.gd` da `PROPKIT TESTS PASS (n)`.
  - Un solo archivo: `-- --only=test_nav_zones_3d`.
  - Después de agregar un script con un `class_name` nuevo, importá una vez primero: `godot --headless --path propkit_lab --import`.
- **Cómo se juega**: abrí el proyecto. F5 corre `forest_3d`; `grove_2d` es la versión 2D.
