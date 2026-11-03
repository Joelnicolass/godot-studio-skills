# spillkit_lab

- **Qué es**: un proyecto Godot chico que corre los ejemplos y los tests de SpillKit sin ningún juego.
- **Qué no es**: un juego. `addons/spill_kit` es un symlink a la copia del propio kit.
- **Renderer**: Compatibility, el de la web, porque el kit tiene que andar ahí. Los ejemplos se ven igual con Forward+.
- **Con qué habla**: con nada más. Los tests arman sus propias escenas; `test_examples` juega los dos ejemplos (`minimal_3d`, `substances_3d`) con sus propios métodos.
- **Cómo se chequea**: `godot --headless --path spillkit_lab --script res://addons/spill_kit/tests/spill_test_runner.gd` da `SPILLKIT TESTS PASS (n)`.
  - Un solo archivo: `-- --only=test_source`.
  - Después de agregar un script con un `class_name` nuevo, importá una vez primero: `godot --headless --path spillkit_lab --import`.
- **Chequeo del editor**: `SPILLKIT_EDITOR_CHECK=1 godot --headless --editor --path spillkit_lab` usa un editor real como lo usa una persona e imprime `EDITOR CHECK PASS`:
  - en `minimal_3d`, aprieta en el inspector los botones Spray, Heavy spray, Die (puddle) y Clear the floor; las gotas, las manchas y el charco aparecen sobre el piso, que encuentra la física del editor, y se limpian;
  - las líneas de costo del componente y del pool, y el aviso de un componente sin tipo;
  - la escena guardada conserva sus valores y nada de lo dibujado;
  - en la escena de un cuerpo sola, Spray arma un pool que no se guarda.

  Trabaja sobre copias en `scratch/editor_check/` (los archivos del addon quedan como están). Lo hace el plugin propio del lab, `addons/spillkit_editor_check`; sin esa variable no hace nada.
- **Capas**: `project.godot` nombra la capa 1 «floor» y la 2 «bodies». Los pisos de los ejemplos están en la 1 (la `floor_mask` del pool) y los muñecos en la 2.
- **Texturas de la pintura**: `examples/substances_3d/textures/make_paint_textures.gd` las dibuja de nuevo, con semilla fija: `godot --headless --path spillkit_lab --script res://addons/spill_kit/examples/substances_3d/textures/make_paint_textures.gd`.
- **Cómo se juega**: abrí el proyecto. F5 corre `substances_3d`; F6 sobre `minimal_3d`.
