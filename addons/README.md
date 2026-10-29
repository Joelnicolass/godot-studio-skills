# Addons (Godot)

Piezas reutilizables del framework. Se copian a `res://addons/<nombre>/` de **cada** juego. Cero reglas de partida, copy de producto o escenas.

| Addon | Rol |
|-------|-----|
| `mp_kit` | Multijugador con nodos y sin RPCs a mano: el juego en un `.tres` (`MpGame`), el mundo en un nodo (`MpWorld`), `MpActor` / `MpInput` / `MpState`, predicción y compensación de lag; solo, LAN, dedicado, salas online con un dedicado por partida, partida privada, web y relay; asistente *Setup game*. Cero gameplay |
| `fsm_kit` | `FsmMachine` + `FsmState` (sin autoload) |
| `plat_kit` | Motor 2D: coyote, jump buffer, apex, corner, lift (sin niveles) |
| `rts_kit` | La capa de mando de un RTS, 2D y 3D: unidades, selección y grupos, órdenes en formación, entrada de comandos (panel de comandos / menú radial opcionales), cámaras de RTS. Sin red, sin movimiento ni combate |
| `prop_kit` | Props, 2D y 3D: scatter sobre cualquier suelo (grupos, zonas prohibidas, máscaras, variantes), dibujo en lotes (3D), el navmesh por zonas con los props como obstrucciones baratas y rehorneados parciales en hilos de trabajo. Sin red, sin el comportamiento del prop |
| `grass_kit` | Pasto, 3D: hojas dibujadas en la GPU alrededor de la cámara en celdas que se mueven con ella, pintado a mano con pinceles en la vista 3D, un suelo leído de los colliders (alturas, normales, pendiente), claros, pisoteo, un look que cambia en el juego. Sin red, sin reglas del juego |

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
```
