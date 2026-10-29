# platkit_lab

Qué es: un proyecto Godot chico que corre el ejemplo y los tests de PlatKit sin ningún juego.
Qué no es: un juego. `addons/plat_kit` es un symlink a la copia canónica del kit.
Quién habla con quién: nadie más; los tests arman sus propios mundos de física, y `test_examples` juega `minimal_2d` con input.
Verificar: `godot --headless --path platkit_lab --script res://addons/plat_kit/tests/plat_test_runner.gd` → `PLATKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path platkit_lab --import`).
Jugar: abrí el proyecto; F5 corre `minimal_2d`.
