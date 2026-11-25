# RtsKit changelog

## 0.3.0

- **The command rig is one node.** `rig/rts_command_rig_3d.tscn` and `rig/rts_command_rig_2d.tscn` (`RtsCommandRig`) hold `Command` with its ten pieces and the `View` with its `Box`, all wired. Instance it, assign `camera` and `ground` (in 2D `camera` is enough) and you select and order. `menu` is a third, optional socket for the right button's menu. If a socket is missing, or the camera is of the other dimension, the node shows a warning in the editor.
- **The pieces stay at hand.** In the editor, right click the rig > Editable Children: every value stays on the piece that uses it. In code, `rig.selection`, `rig.orders`, `rig.command`, `rig.order_input`, `rig.select_input`, `rig.armed`, `rig.state`, `rig.pointer`, `rig.probe`, `rig.order_button`, `rig.group_keys`, `rig.view`, `rig.box`.
- **The camera's edges, with nothing to wire.** An `RtsCamera3D` / `RtsCamera2D` with no `edge_area` gets the rig's `View`.
- **The inspector shows the unit of every distance.** `RtsUnit.size`, `RtsOrders.spacing_base`, `max_spacing`, `retarget_range` and `RtsSelection.same_type_radius` show `px` when the node sits under a `Node2D` and `m` when it sits under a `Node3D`; before, they showed nothing and the docs said "meters" in 2D too. No value changes. The 2D rig has its own in pixels (8, 120, 1200, 600). `RtsSpace.distance_unit(node)` is the rule.
- **`RtsOrderButton.menu` can change while the game runs** (before, it was only connected in `_ready`).
- **Examples:** `minimal_2d`, `skirmish_3d` and `skirmish_2d` use the rig; the `skirmish` ones have Editable Children on to wire their HUD.
- **Tests:** `test_rig` (the rig in 2D and 3D with mouse events, the warnings, the ground socket, the menu, the edges, a HUD on top with a real pointer), `test_space` (the unit the inspector shows) and `test_independence` (the kit names no other kit).

To update: nothing breaks; a rig built by hand keeps working the same. To move to the scene: delete your `Command` and your `Hud/View`, instance the rig of your dimension, assign `camera` and `ground`, and leave your HUD after the rig in the tree. The values you had changed on a piece go back in with Editable Children; in your scripts, `$Command/Selection` becomes `rig.selection` (with `@export var rig: RtsCommandRig`), and your camera's `edge_area` may stay empty. A script of yours that extends `RtsOrders` or `RtsSelection` stays the same (they are `@tool` now only to show the unit).

## 0.2.0

- **The edges stop over the UI.** `RtsCamera3D` and `RtsCamera2D` no longer pan or turn by the edges while the pointer is over a control of the UI: a HUD button or panel, any control whose mouse filter is not *Ignore* (labels and containers on *Ignore* do not count). Before, without `edge_area`, the camera moved while you aimed at a button in a corner. `edges_over_gui = true` brings the old behavior back. With `edge_area` nothing changes: the edges still work only over that control.
- **Tests:** `test_camera` checks a button at the edge, a label that ignores the mouse, `edges_over_gui` and `edge_area`, in 3D and in 2D.

To update: if your camera has no `edge_area` and a HUD panel covers an edge you want to pan by, set that panel's mouse filter to *Ignore* (its buttons still stop the edges) or turn `edges_over_gui` on.

## 0.1.1

- **Minimal example** `examples/minimal_2d/`: six soldiers (`soldier.tscn`: a body, an `RtsUnit` and the GUIDE's unit script in 2D) and the command rig of GUIDE › 3. The tests play it with mouse events.
- **Tests:** the runner fails a test that stops on a script error or made no check at all; it used to count it as a pass.

Nothing to update in your project.

## 0.1.0

First version: the command layer of an RTS, for 2D and 3D, with no network and no game rules.

- **Units**: `RtsUnit` (owner, team, kind, tags, selectable / orderable / targetable, size, center, refused commands, formation) with its order queue (`give`, `complete`, `fail`, `stop`; `order_started`, `order_ended`, `order_queued`).
- **Selection**: `RtsSelection` (click, Shift, Ctrl / Cmd or double click by kind and radius, box in 2D and 3D with optional occlusion, limit with push, ten groups and a new-units group, units that stop being selectable leave by themselves).
- **Orders**: `RtsOrders` (`apply(order, from_slot)` checks the slot, `request` / `send` for the local player, `apply_units` for an AI), typed commands (`RtsCommandType`, `RtsCommandCatalog`: move, attack, guard, guard_area, attack_move, retreat), formations (`RtsFormation`: line, flanks, phalanx, semicircle, circle, wedge, skirmish), greedy and row-by-row slot matching, retarget to the nearest foe, retreat to the side's anchor, `RtsOrder.to_array` / `from_array` for any transport.
- **Input**: `RtsCommandInput`, `RtsSelectInput`, `RtsOrderButton`, `RtsOrderInput` (context -> command, armed clicks by target kind, `run_entry`), `RtsArmedCommand`, `RtsGroupKeys`, `RtsPointer` (2D and 3D), `RtsWorldInput`, `RtsKeymap` (Cmd or Ctrl on macOS, configurable).
- **Command UIs, all optional**: `RtsMenuEntry` (one model for every UI), `RtsCommandCard` (a panel of buttons), `RtsOrderMenu` (the contract of a menu at a point) and `RtsRadialMenu` (any number of rings, filled by hand or from the catalogs).
- **Cues**: `RtsCueSet`, `RtsTargetProbe`, `RtsCursorSkin`, `rts_command_cue.tscn` with `RtsRefusalReason`, `RtsArmedPreview`, `RtsPing3D` / `RtsPing2D`.
- **Cameras**: `RtsCamera3D` (follow a body, or a free top-down view with pan, turn, zoom and bounds), `RtsCamera2D` (the same contract), `RtsCameraEffect`.
- **Examples**: `skirmish_3d` (radial menu) and `skirmish_2d` (no menu, command panel). **Tests**: `rtskit_lab`.
