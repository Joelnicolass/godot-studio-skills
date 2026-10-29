# fsmkit_lab

Qué es: un proyecto Godot chico que corre el ejemplo y los tests de FsmKit sin ningún juego.
Qué no es: un juego. `addons/fsm_kit` es un symlink a la copia canónica del kit.
Quién habla con quién: nadie más; los tests arman sus propios árboles, y `test_examples` juega `minimal_2d` con input.
Verificar: `godot --headless --path fsmkit_lab --script res://addons/fsm_kit/tests/fsm_test_runner.gd` → `FSMKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path fsmkit_lab --import`).
Jugar: abrí el proyecto; F5 corre `minimal_2d`.
