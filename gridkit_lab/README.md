# gridkit_lab

- **Qué es:** un proyecto Godot chico que corre los ejemplos y los tests de GridKit sin ningún juego.
- **Qué no es:** un juego. `addons/grid_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles, y `test_examples` juega `minimal_3d` (hexágonos, mapa desde `map.tres`) y `squares_3d` (cuadrados) con eventos de mouse.
- **Verificar:** `godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd` → `GRIDKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path gridkit_lab --import`).
- **Jugar:** abrí el proyecto. F5 corre `minimal_3d`; F6 sobre `squares_3d.tscn` corre el de cuadrados.
- **Chequeo del editor:** `godot --headless --editor --path gridkit_lab -- --gridkit-editor-check` → `GRIDKIT EDITOR CHECK PASS (n)`. El plugin `editor_check` solo actúa con ese argumento (sin él, abrir el lab es normal). Abre copias temporales de una escena con un layout `.tres` y otra sin layout, elige el tablero y la vista, aprieta los botones de la barra (losetas, casillas y alturas), manda el mouse a la vista 3D (también sobre una casilla alta) y mira el historial de deshacer y los archivos en disco; al terminar borra las copias. Es el único chequeo que pasa por el editor real y **no reemplaza** mirar la barra con los ojos.
- **Pintar:** abrí `minimal_3d.tscn`, seleccioná `Board` y usá la barra **GridKit** de la vista 3D (el plugin ya está habilitado en este proyecto). Es lo único que los tests no cubren: necesita el editor abierto.
