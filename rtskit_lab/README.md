# rtskit_lab

Qué es: un proyecto Godot chico que corre los ejemplos y los tests de RtsKit sin ningún juego.
Qué no es: un juego. `addons/rts_kit` es un symlink a la copia canónica del kit.
Quién habla con quién: nadie más; los tests arman sus propias escenas, y `test_examples` juega los tres ejemplos (`minimal_2d`, `skirmish_3d`, `skirmish_2d`) con eventos de mouse y de teclado.
Verificar: `godot --headless --path rtskit_lab --script res://addons/rts_kit/tests/rts_test_runner.gd` → `RTSKIT TESTS PASS (n)`. Un solo archivo: `-- --only=test_orders`. Después de sumar un script con un `class_name` nuevo, importá una vez antes (`godot --headless --path rtskit_lab --import`).
Jugar: abrí el proyecto (F5 corre `skirmish_3d`; `skirmish_2d` es la versión sin menú radial).
