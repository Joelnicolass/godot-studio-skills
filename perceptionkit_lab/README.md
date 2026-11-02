# perceptionkit_lab

- **Qué es**: un proyecto Godot chico que corre los ejemplos y los tests de PerceptionKit sin ningún juego.
- **Qué no es**: un juego. `addons/perception_kit` es un symlink a la copia del propio kit.
- **Con qué habla**: con nada más. Los tests arman sus propias escenas; `test_examples` juega los tres ejemplos (`minimal_3d`, `minimal_2d`, `guards_3d`) con sus propias teclas y métodos.
- **Cómo se chequea**: `godot --headless --path perceptionkit_lab --script res://addons/perception_kit/tests/perception_test_runner.gd` da `PERCEPTIONKIT TESTS PASS (n)`.
  - Un solo archivo: `-- --only=test_sensor_3d`.
  - Después de agregar un script con un `class_name` nuevo, importá una vez primero: `godot --headless --path perceptionkit_lab --import`.
- **Chequeo del editor**: `PERCEPTIONKIT_EDITOR_CHECK=1 godot --headless --editor --path perceptionkit_lab` maneja un editor real como lo hace una persona e imprime `EDITOR CHECK PASS`:
  - el sensor del guardia tiene el gizmo del kit; sus manijas de vista, ángulo y ojos arrastradas desde la cámara de la vista 3D, cada una deshecha y rehecha; un arrastre cancelado; el aviso de pérdida debajo de vista; la escena guardada conserva los valores y ninguna forma interna;
  - las manijas del sensor 2D: un clic sobre una la agarra, el arrastre y el soltar la cambian en un paso que se deshace, un clic lejos queda para el editor.

  Trabaja sobre copias de los ejemplos en `scratch/editor_check/` (los archivos del addon quedan como están). Lo hace el plugin propio del lab, `addons/perceptionkit_editor_check`; sin esa variable no hace nada.
- **Capas**: `project.godot` nombra la capa 1 «world», en 2D y 3D. Los sensores y objetivos de los ejemplos quedan en ella, como vienen de entrada.
- **Cómo se juega**: abrí el proyecto. F5 corre `guards_3d`; F6 sobre `minimal_3d` o `minimal_2d`.
