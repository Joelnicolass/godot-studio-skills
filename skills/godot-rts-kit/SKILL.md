---
name: godot-rts-kit
description: >-
  Adds RTS controls to a Godot 4 game, 2D or 3D, with the RtsKit addon: units
  (RtsUnit), selection and groups, typed orders in formations, right click by
  context, armed orders, a command panel or radial menu (optional), cursor cues,
  RTS cameras. Use when the user wants an RTS, unit selection, box select,
  control groups, formations, attack-move, a command card, or /add-rts-controls.
  Not pathfinding or combat (the game's). No network inside: MpKit is connected
  by the game.
---

# Godot — RTS controls (RtsKit)

Addon `addons/rts_kit/` in the **game** project. Reference: `addons/rts_kit/README.md`; API by piece: [api.md](api.md).

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project rts_kit
```

Enable plugin **RtsKit**. Bounded request: `/add-rts-controls`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **The kit commands, the game acts.** RtsKit decides who obeys, the formation and each unit's slot; the game moves the body and fights (listen to `RtsUnit.order_started`, call `complete()` / `fail()`). Do not put movement, damage or AI inside the kit's nodes.
- **No kit depends on another.** RtsKit has no network and never names MpKit or FsmKit. Multiplayer is glue in the game: `orders.send` sends `order.to_array()`; the server calls `orders.apply(RtsOrder.from_array(data, self), sender_slot)` (README › Network). A unit's behavior may be an FsmKit machine the game wires to `order_started`.
- **One ground for 2D and 3D.** Kit points are 3D (`Vector3`, ground XZ). A 2D point `(x, y)` is `(x, 0, y)`: `RtsSpace.from_2d` / `to_2d`, `order.spot_2d()`. In 2D, world units are pixels: set `RtsOrders.spacing_base`, `max_spacing`, `retarget_range`, `RtsSelection.same_type_radius` and `RtsUnit.size` in pixels.
- **Data, not code, for kinds of order and formations.** A new order = an `RtsCommandType` in a catalog `.tres`; a new shape = a script that `extends RtsFormation`. A rule of a unit (pacifist, a foe that is not "another team") = a script that `extends RtsUnit` and overrides `accepts` / `is_foe`.
- **Menus are optional.** The right button (`RtsOrderButton`) works with no menu. Command UIs show `RtsMenuEntry` and call `RtsOrderInput.run_entry(entry, screen)`: `RtsCommandCard` (buttons), `RtsRadialMenu` (rings), or the game's own (`extends RtsOrderMenu`).
- **Modals block the world**: a pause / options UI joins `RtsWorldInput.modal_group` while open.

## Tree

```
Game
├── Units/…                 # bodies, each with an RtsUnit child (+ the game's unit logic)
├── Camera                  # RtsCamera3D / RtsCamera2D
├── Command                 # RtsCommandInput
│   ├── Selection, Orders, Pointer, State, Armed
│   ├── OrderInput, SelectInput, GroupKeys, OrderButton
│   └── Probe               # optional (cursor and cue)
└── Hud
    ├── View (+ Box)        # full-rect Control: the world's clicks
    ├── CommandCard         # optional
    ├── RadialMenu          # optional
    └── Cue                 # optional
```

Start from `addons/rts_kit/examples/skirmish_3d/skirmish_3d.tscn` (radial menu) or `skirmish_2d/skirmish_2d.tscn` (no menu, command panel): the whole rig is wired in the inspector.

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
- Distances in meters in a 2D game (units pile up on one pixel).
