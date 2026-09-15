# Addons (Godot)

Piezas reutilizables del framework. Se copian a `res://addons/<nombre>/` de **cada** juego. Cero reglas de partida, copy de producto o escenas.

| Addon | Rol |
|-------|-----|
| `mp_kit` | Listen-server / dedicated: ENet, slots, handshake, snapshots opacos |
| `agent_kit` | CLI para agentes: captura, flow JSON (`try_click` / `repeat`), HTTP, inspect, diff de PNG |

Nuevos addons nacen acá cuando un segundo juego (o un segundo feature) los necesita. No forks por título.

Instalar en un proyecto:

```bash
./install.sh --addon /path/to/godot-project
./install.sh --addon /path/to/godot-project agent_kit
```
