# Addons (Godot)

Piezas reutilizables del framework. Se copian a `res://addons/<nombre>/` de **cada** juego. Cero reglas de partida, copy de producto o escenas.

| Addon | Rol |
|-------|-----|
| `mp_kit` | Listen-server / dedicated: ENet o WebSocket, slots, handshake, snapshots opacos, admisión por ticket, servidor de salas con un dedicado por partida |
| `fsm_kit` | `FsmMachine` + `FsmState` (sin autoload) |
| `plat_kit` | Motor 2D: coyote, jump buffer, apex, corner, lift (sin niveles) |
| `rts_kit` | La capa de mando de un RTS, 2D y 3D: unidades, selección y grupos, órdenes en formación, entrada de comandos (panel de comandos / menú radial opcionales), cámaras de RTS. Sin red, sin movimiento ni combate |
| `prop_kit` | Props, 2D y 3D: scatter sobre cualquier suelo (grupos, zonas prohibidas, máscaras, variantes), dibujo en lotes (3D), el navmesh por zonas con los props como obstrucciones baratas y rehorneados parciales en hilos de trabajo. Sin red, sin el comportamiento del prop |
| `grass_kit` | Pasto, 3D: hojas dibujadas en la GPU alrededor de la cámara en celdas que se mueven con ella, pintado a mano con pinceles en la vista 3D, un suelo leído de los colliders (alturas, normales, pendiente), claros, pisoteo, un look que cambia en el juego. Sin red, sin reglas del juego |

**AgentKit** no vive acá: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest). `./install.sh --addon … agent_kit` lo trae de ese repo (AgentKit 0.2.0 con el módulo `determinism` en `rc/v0.10.0`). `example/addons/agent_kit/` de acá es una copia de referencia de ese módulo.

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
