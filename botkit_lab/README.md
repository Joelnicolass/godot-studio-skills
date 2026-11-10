# botkit_lab

- **Qué es**: un proyecto Godot chico que corre los ejemplos y los tests de BotKit sin ningún juego.
- **Qué no es**: un juego. `addons/bot_kit` es un symlink a la copia del propio kit.
- **Con qué habla**: con nada más. Los tests arman sus propios pisos, muros y navmesh, con personajes que leen las teclas de su bot como un juego lee `Input`; `test_examples` juega los dos ejemplos (`minimal_3d`, `arena_3d`).
- **Cómo se chequea**: `godot --headless --path botkit_lab --script res://addons/bot_kit/tests/bot_test_runner.gd` da `BOTKIT TESTS PASS (n)`.
  - Un solo archivo: `-- --only=test_fight`.
  - Después de agregar un script con un `class_name` nuevo, importá una vez primero: `godot --headless --path botkit_lab --import`.
- **Chequeo del editor**: `BOTKIT_EDITOR_CHECK=1 godot --headless --editor --path botkit_lab` maneja un editor real como lo hace una persona e imprime `EDITOR CHECK PASS`:
  - el bot del robot tiene el gizmo del kit; sus manijas de ojos y puntería arrastradas desde la cámara de la vista 3D, cada una deshecha y rehecha; un arrastre cancelado; los avisos; en el editor no aprieta nada; la escena guardada conserva los valores, sin `body` ni dibujos;
  - la meta de un pickup de la arena: su manija de alcance, deshecha y rehecha; el aviso sin alcance.

  Trabaja sobre copias de los ejemplos en `scratch/editor_check/` (los archivos del addon quedan como están). Lo hace el plugin propio del lab, `addons/botkit_editor_check`; sin esa variable no hace nada.
- **Capas**: `project.godot` nombra la capa 1 «world» (los muros, lo que tapa la vista) y la 2 «characters».
- **Cómo se juega**: abrí el proyecto. F5 corre `arena_3d`; F6 sobre `minimal_3d`.
