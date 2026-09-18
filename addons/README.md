# Addons (Godot)

Piezas reutilizables del framework. Se copian a `res://addons/<nombre>/` de **cada** juego. Cero reglas de partida, copy de producto o escenas.

| Addon | Rol |
|-------|-----|
| `mp_kit` | Listen-server / dedicated: ENet, slots, handshake, snapshots opacos |
| `fsm_kit` | `FsmMachine` + `FsmState` (sin autoload) |
| `plat_kit` | Motor 2D: coyote, jump buffer, apex, corner, lift (sin niveles) |

**AgentKit** no vive acá: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest). `./install.sh --addon … agent_kit` lo trae de ese repo.

Nuevos addons nacen acá cuando un segundo juego (o un segundo feature) los necesita. No forks por título.

Instalar en un proyecto:

```bash
./install.sh --addon /path/to/godot-project
./install.sh --addon /path/to/godot-project agent_kit
./install.sh --addon /path/to/godot-project fsm_kit
./install.sh --addon /path/to/godot-project plat_kit
```
