# Addons (Godot)

Reusable pieces of the framework. Copy them to `res://addons/<name>/` in **each** game. Zero match rules, product copy, or scenes.

| Addon | Role |
|-------|------|
| `mp_kit` | Listen-server / dedicated: ENet, slots, handshake, opaque snapshots |
| `agent_kit` | CLI for agents: capture, JSON flow (`try_click` / `repeat`), HTTP, inspect, PNG diff |
| `fsm_kit` | `FsmMachine` + `FsmState` (no autoload) |
| `plat_kit` | 2D motor: coyote, jump buffer, apex, corner, lift (no levels) |

New addons belong here when a second game (or a second feature) needs them. No per-title forks.

Install into a project:

```bash
./install.sh --addon /path/to/godot-project
./install.sh --addon /path/to/godot-project agent_kit
./install.sh --addon /path/to/godot-project fsm_kit
./install.sh --addon /path/to/godot-project plat_kit
```
