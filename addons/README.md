# Addons (Godot)

Reusable pieces of the framework. Copy them to `res://addons/<name>/` in **each** game. Zero match rules, product copy, or scenes.

| Addon | Role |
|-------|------|
| `mp_kit` | Listen-server: ENet, slots, handshake, opaque snapshots |

New addons belong here when a second game (or a second feature) needs them. No per-title forks.

Install into a project:

```bash
./install.sh --addon /path/to/godot-project
```
