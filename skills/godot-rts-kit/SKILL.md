---
name: godot-rts-kit
description: >-
  Adds RTS controls to a Godot 4 game, 2D or 3D, with the RtsKit addon: units
  (RtsUnit), selection and groups, typed orders in formations, right click by
  context, armed orders, a command panel or radial menu (optional), cursor cues,
  RTS cameras with touch (drag, pinch, twist). Use when the user wants an RTS,
  unit selection, box select, control groups, formations, attack-move, a command
  card, a strategy-map or touch camera, or /add-rts-controls.
  Not pathfinding or combat (the game's). No network inside: MpKit is connected
  by the game.
---

# Godot — RTS controls (RtsKit)

Addon `addons/rts_kit/` in the **game** project. Step by step (a unit, the rig, making it the game's own, MpKit): `addons/rts_kit/GUIDE.md`. Reference: `addons/rts_kit/README.md`; API by piece: [api.md](api.md).

If the addon is missing:

```bash
# Copies the addon into the game's project.
./install.sh --addon /path/to/godot-project rts_kit
```

Enable plugin **RtsKit**. Bounded request: `/add-rts-controls`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **The rig is one node.** Instance `addons/rts_kit/rig/rts_command_rig_3d.tscn` (2D: `rts_command_rig_2d.tscn`) and assign `camera` and `ground`; do not build `Command` and `View` by hand or copy them from an example. A piece's value changes with Editable Children; code reaches it with `rig.selection`, `rig.orders`, `rig.command`… The game's HUD goes after the rig in the tree.
- **The kit commands, the game acts.** RtsKit decides who obeys, the formation and each unit's slot; the game moves the body and fights (listen to `RtsUnit.order_started`, call `complete()` / `fail()`). Do not put movement, damage or AI inside the kit's nodes.
- **No kit depends on another.** RtsKit has no network and never names MpKit or FsmKit. Multiplayer is game code in the game: `orders.send` sends `order.to_array()`; the server calls `orders.apply(RtsOrder.from_array(data, self), sender_slot)`. With MpKit: its custom channel, units named by node name (GUIDE › 6). A unit's behavior may be an FsmKit machine the game wires to `order_started`.
- **One ground for 2D and 3D.** Kit points are 3D (`Vector3`, ground XZ). A 2D point `(x, y)` is `(x, 0, y)`: `RtsSpace.from_2d` / `to_2d`, `order.spot_2d()`. In 2D, world units are pixels and the inspector shows it (`px`; `m` in 3D): the 2D rig already has the distances of `Orders` and `Selection` in pixels; `RtsUnit.size` goes in pixels on each unit.
- **Data, not code, for kinds of order and formations.** A new order = an `RtsCommandType` in a catalog `.tres`; a new shape = a script that `extends RtsFormation`. A rule of a unit (pacifist, a foe that is not "another team") = a script that `extends RtsUnit` and overrides `accepts` / `is_foe`.
- **Menus are optional.** The right button (`RtsOrderButton`) works with no menu. Command UIs show `RtsMenuEntry` and call `RtsOrderInput.run_entry(entry, screen)`: `RtsCommandCard` (buttons), `RtsRadialMenu` (rings), or the game's own (`extends RtsOrderMenu`).
- **Modals block the world**: a pause / options UI joins `RtsWorldInput.modal_group` while open.

## Tree

```
Game
├── Units/…                 # bodies, each with an RtsUnit child (+ the game's unit logic)
├── Camera                  # RtsCamera3D / RtsCamera2D
├── Rig                     # rts_command_rig_3d.tscn / rts_command_rig_2d.tscn: camera, ground, menu
│   ├── Command             # RtsCommandInput
│   │   ├── Selection, Orders, Pointer, State, Armed
│   │   ├── OrderInput, SelectInput, GroupKeys, OrderButton
│   │   └── Probe           # cursor and cue
│   └── ViewLayer/View/Box  # full-rect Control: the world's clicks; the selection box
└── Hud                     # the game's HUD, after the rig
    ├── CommandCard         # optional
    ├── RadialMenu          # optional: goes in the rig's menu socket
    └── Cue                 # optional
```

The battle's script reaches the pieces through the rig's root:

```gdscript
# The battle says who this screen's player is and listens to the selection.
@export var rig: RtsCommandRig


func _ready() -> void:
	rig.command.local_slot = 1
	rig.selection.changed.connect(_on_selection_changed)
```

See `addons/rts_kit/examples/minimal_2d/minimal_2d.tscn` (the minimum: the rig with its camera and six soldiers whose `soldier.gd` is the unit script of GUIDE › 2 in 2D), `skirmish_3d/skirmish_3d.tscn` (radial menu, cursor, pings) or `skirmish_2d/skirmish_2d.tscn` (no menu, command panel).

## What belongs where

| Kit | Game |
|---|---|
| Who may be selected and ordered, groups, the formation, each slot | Walking to `order.spot()`, pathfinding, avoidance |
| The command a right click means here (`context_orders`, `classify`) | Damage, death (`selectable = false`, `orderable = false`), AI |
| Armed orders, the cursor, refusals | Spells and buildings (arm them with `armed.arm(&"mode", payload)`, answer `armed_clicked`) |
| `request` / `apply` / `to_array` | The transport (RPC, MpKit), who is server |

## Done when

- F6: a box selects own units only; a right click on the ground moves them into the line; on a foe they attack it; Ctrl/Cmd+1 then 1 recalls the group; Alt+N keeps a formation.
- Removing the menu / command panel nodes leaves a plain right click working.
- `godot --headless --path rtskit_lab --script res://addons/rts_kit/tests/rts_test_runner.gd` → `RTSKIT TESTS PASS` (in the kit repo).

## Anti-patterns

- Moving units from inside `RtsOrders` or an `RtsUnit` subclass that also pathfinds and fights.
- An RPC or `MpKit` call inside a node of `addons/rts_kit`.
- Copying a kit script into the game "to tweak it" instead of `extends` or a catalog `.tres`.
- Building `Command` and `Hud/View` by hand, or copying them from an example, instead of instancing the rig.
- A `$Rig/Command/…` path in a script instead of `rig.selection` / `rig.orders`.
- The game's HUD before the rig in the tree (the `View` takes its clicks).
- Distances in meters in a 2D game (units pile up on one pixel): look at the inspector's `px`.
