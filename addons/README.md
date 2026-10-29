# Addons (Godot)

Reusable pieces of the framework. Copy them to `res://addons/<name>/` in **each** game. Zero match rules, product copy, or scenes.

| Addon | Role |
|-------|------|
| `mp_kit` | Multiplayer with nodes and no hand-written RPCs: the game in one `.tres` (`MpGame`), the world in one node (`MpWorld`), `MpActor` / `MpInput` / `MpState`, prediction and lag compensation; solo, LAN, dedicated, online rooms with one dedicated per match, private match, web and relay; the *Setup game* wizard. No gameplay |
| `fsm_kit` | `FsmMachine` + `FsmState` (no autoload) |
| `plat_kit` | 2D motor: coyote, jump buffer, apex, corner, lift (no levels) |
| `rts_kit` | RTS command layer, 2D and 3D: units, selection and groups, orders in formations, command input (optional command panel / radial menu), RTS cameras. No network, no movement or combat |
| `prop_kit` | Props, 2D and 3D: scatter over any ground (clusters, keep-outs, masks, variants), batch drawing (3D), the navmesh in zones with props as cheap obstructions and partial re-bakes on worker threads. No network, no prop behavior |
| `grass_kit` | Grass, 3D: blades drawn on the GPU around the camera in cells that move with it, painted by hand with brushes in the 3D view, a ground read from the colliders (heights, normals, slope), clearings, trampling, a look that changes in play. No network, no game rules |

Every addon ships a **minimal example** (`examples/minimal_2d/` or `examples/minimal_3d/`: the smallest integration that works, F6) and, in its README, that code explained with **tips and recommendations**. The table with all of them is in the [repo README](../README.md#each-kits-examples).

**AgentKit** does not live here: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest). `./install.sh --addon … agent_kit` fetches it from that repo's `main` branch (AgentKit 0.1.6, with the `determinism` module; another branch with `GODOT_STUDIO_PLAYTEST_REF`). `example/addons/agent_kit/` here is a reference copy.

New addons belong here when a second game (or a second feature) needs them. No per-title forks.

Install into a project:

```bash
./install.sh --addon /path/to/godot-project
./install.sh --addon /path/to/godot-project agent_kit
./install.sh --addon /path/to/godot-project fsm_kit
./install.sh --addon /path/to/godot-project plat_kit
./install.sh --addon /path/to/godot-project rts_kit
./install.sh --addon /path/to/godot-project prop_kit
./install.sh --addon /path/to/godot-project grass_kit
```
