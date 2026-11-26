# Addons (Godot)

Piezas reutilizables del framework. Se copian a `res://addons/<nombre>/` de **cada** juego. Cero reglas de partida, copy de producto o escenas.

| Addon | Rol |
|-------|-----|
| `mp_kit` | Multijugador con nodos y sin RPCs a mano: el juego en un `.tres` (`MpGame`), el mundo en un nodo (`MpWorld`), `MpActor` / `MpInput` / `MpState`, predicción y compensación de lag; solo, LAN, dedicado, salas online con un dedicado por partida, partida privada, web y relay; asistente *Setup game*. Cero gameplay |
| `fsm_kit` | `FsmMachine` + `FsmState` (sin autoload) |
| `plat_kit` | Motor 2D: coyote, jump buffer, apex, corner, lift (sin niveles) |
| `rts_kit` | La capa de mando de un RTS, 2D y 3D: unidades, selección y grupos, órdenes en formación, entrada de comandos (panel de comandos / menú radial opcionales), cámaras de RTS con táctil. Sin red, sin movimiento ni combate |
| `prop_kit` | Props, 2D y 3D: scatter sobre cualquier suelo (grupos, zonas prohibidas, máscaras, variantes), dibujo en lotes (3D), el navmesh por zonas con los props como obstrucciones baratas y rehorneados parciales en hilos de trabajo. Sin red, sin el comportamiento del prop |
| `grass_kit` | Pasto, 3D: hojas dibujadas en la GPU alrededor de la cámara en celdas que se mueven con ella, pintado a mano con pinceles en la vista 3D, un suelo leído de los colliders (alturas, normales, pendiente), claros, pisoteo, un look que cambia en el juego. Sin red, sin reglas del juego |
| `perception_kit` | Percepción, 2D y 3D: un cono de vista con un radio de pérdida más lejano, conciencia de lo cercano, muros que tapan, ruidos, cualquier sentido propio del juego, una memoria que olvida, bandos como capas de física, manijas para arrastrar la vista en el editor. Sin red, sin estados ni combate |
| `spill_kit` | Lo que derrama un cuerpo, 3D: sangre, icor, aceite, baba, tinta. Cada golpe salpica gotas y deja manchas en el piso que quedan; al morir crece un charco que sigue la pendiente. Cada sustancia es un tipo con el aspecto húmedo del kit, texturas PBR propias (albedo, normal, ORM) o el shader del juego. Reglas como valores, una sola propiedad para la red, Compatibility y WebGL 2, nada en un servidor dedicado. Sin vida, daño ni red |
| `grid_kit` | Tableros de hexágonos o de cuadrados con la misma API: `CellGrid` (`HexGrid` y `SquareGrid`; datos puros: valores por casilla, vecinos, distancia, rango, caminos, flood, `to_dict`), el mapa como un `GridLayout` (un `.tres`) y nodos para verlo y elegir casillas en 3D (`GridBoard`, `GridView3D`, `GridCursor`), niebla de guerra por jugador (`CellFog` y `GridFog`: oculta, explorada, visible), con un pincel en la vista 3D del editor. Sin reglas de juego, sin red |
| `turn_kit` | Turnos, rondas y ciclos: `TurnCycle` (datos puros: acciones por turno, rondas, ciclos y fin configurables, asientos inactivos y, opcionales, jugador inicial que rota, fases dentro del turno, tiempo por turno e iniciativa, `to_dict`) y un reloj con un hijo por jugador (`TurnClock`, `TurnSeat`). Sin reglas de juego, sin red |
| `wallet_kit` | Recursos y monedas: `Purse` (datos puros: montos por clave, topes que devuelven lo perdido, pagar todo o nada, sustitutos con tasa que cubren lo que falta (`WalletSubstitute`), `payment_for` para mostrar el costo, `to_dict`) y el nodo `Wallet`. Sin precios ni UI, sin red |
| `command_kit` | Jugadas validadas con historial: cada jugada es una función de tu juego (`do_<nombre>(seat, args…)`, con `can_<nombre>` que da el motivo de rechazo y `undo_<nombre>` opcional); `CommandLog` (datos puros: corre solo las válidas, guarda `{name, seat, args}`, deshace la última, repite un historial) y el nodo `GameCommands`. Sin reglas de juego, sin azar, sin red |
| `unlock_kit` | Árboles de desbloqueo: `UnlockGraph` (datos puros: qué se puede desbloquear ahora, requisitos que se piden todos (`requires`) o alcanza con uno (`requires_any`), un costo que el kit no cobra: `buy(id, pay)` recibe la función que cobra; `why_not`, `lock` para deshacer, `to_dict`), el nodo `UnlockTree` armado con hijos `UnlockEntry` (una adentro de otra la requiere; `new_graph()` da un grafo por jugador) y un `UnlockTreeView` que dibuja el árbol, también en el editor y con una escena propia por entrada. Sin efectos ni red |
| `stat_kit` | Estadísticas con bonus: `StatSheet` (datos puros: una base por estadística y modificadores `StatModifier` que suman, suman porcentajes, multiplican o fijan, en orden ADD → PERCENT → MUL → SET; límites por estadística; la fuente se da al agregar y `remove_source` saca todo lo de una; `stat_changed` solo si cambia, `to_dict`) y el nodo `StatBlock`, que muestra los valores finales en el inspector. Sin ítems, inventario, duración de buffs ni UI, sin red |
| `deck_kit` | Cartas: `CardStack` (datos puros: una pila en orden con el índice 0 arriba, copias por índice, robar, mover entre pilas, mezclar con tu `RandomNumberGenerator`, rellenar con el descarte, `to_dict`), el recurso `CardData`, los nodos `CardPile` y `Deck` (con `rng_seed` o el rng de la partida) y un `HandView` que muestra una mano en abanico, dibujada o con una escena por carta, también en el editor. Sin reglas de cartas, costos ni turnos, sin red |
| `dice_kit` | Dados: `DieData` (caras con valor, etiquetas e ícono; d4 a d20 listos) y `DiceRoll` (datos puros: `sum()`, `count(tag)`, los más altos o bajos, volver a tirar algunos, dados mezclados, `to_dict`), tirados con tu `RandomNumberGenerator` (la misma semilla, las mismas tiradas), el nodo `DiceRoller` (botón Roll en el inspector, dados extra) y `DiceTray3D` (los dados giran y caen en 3D, con tu malla). Sin reglas de juego, sin física, sin red |
| `bot_kit` | Bots que juegan a tu personaje como una persona, 3D: aprietan las teclas de un jugador (un `Input` propio), ven al enemigo más cercano sin muros en el medio, apuntan con límites humanos, eligen el arma por la distancia, recorren el navmesh hacia metas y salen de donde se traban; conductas propias como nodos hijos, presets de dificultad. Sin red, sin armas ni vida |

Cada addon trae un **ejemplo mínimo** (`examples/minimal_2d/` o `examples/minimal_3d/`: la integración más chica que anda, F6) y, en su README, ese código explicado con **tips y recomendaciones**. La tabla con todos está en el [README del repo](../README.md#ejemplos-de-cada-kit).

**AgentKit** no vive acá: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest). `./install.sh --addon … agent_kit` lo trae de la rama `main` de ese repo (AgentKit 0.1.6, con el módulo `determinism`; otra rama con `GODOT_STUDIO_PLAYTEST_REF`). `example/addons/agent_kit/` de acá es una copia de referencia.

Nuevos addons nacen acá cuando un segundo juego (o un segundo feature) los necesita. No forks por título.

Instalar en un proyecto:

```bash
./install.sh --addon /path/to/godot-project
./install.sh --addon /path/to/godot-project agent_kit
./install.sh --addon /path/to/godot-project fsm_kit
./install.sh --addon /path/to/godot-project plat_kit
./install.sh --addon /path/to/godot-project rts_kit
./install.sh --addon /path/to/godot-project prop_kit
./install.sh --addon /path/to/godot-project grass_kit
./install.sh --addon /path/to/godot-project perception_kit
./install.sh --addon /path/to/godot-project spill_kit
./install.sh --addon /path/to/godot-project bot_kit
./install.sh --addon /path/to/godot-project grid_kit
./install.sh --addon /path/to/godot-project turn_kit
./install.sh --addon /path/to/godot-project wallet_kit
./install.sh --addon /path/to/godot-project command_kit
./install.sh --addon /path/to/godot-project unlock_kit
./install.sh --addon /path/to/godot-project stat_kit
./install.sh --addon /path/to/godot-project deck_kit
./install.sh --addon /path/to/godot-project dice_kit
```
