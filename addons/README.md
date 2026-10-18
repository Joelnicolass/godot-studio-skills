# Addons (Godot)

Reusable pieces of the framework. Copy them to `res://addons/<name>/` in **each** game. Zero match rules, product copy, or scenes.

| Addon | Role |
|-------|------|
| `mp_kit` | Listen-server / dedicated: ENet or WebSocket, slots, handshake, opaque snapshots, ticket admission, room server with one dedicated per match |
| `fsm_kit` | `FsmMachine` + `FsmState` (no autoload) |
| `plat_kit` | 2D motor: coyote, jump buffer, apex, corner, lift (no levels) |

**AgentKit** does not live here: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest). `./install.sh --addon … agent_kit` fetches it from that repo (AgentKit 0.2.0 with the `determinism` module on `rc/v0.10.0`). `example/addons/agent_kit/` here is a reference copy of that module.

New addons belong here when a second game (or a second feature) needs them. No per-title forks.

Install into a project:

```bash
./install.sh --addon /path/to/godot-project
./install.sh --addon /path/to/godot-project agent_kit
./install.sh --addon /path/to/godot-project fsm_kit
./install.sh --addon /path/to/godot-project plat_kit
```
