---
description: "Add RTS controls (RtsKit addon): units, selection and groups, orders in formations, command input, RTS camera."
---

Add **RTS controls** to the **game's Godot project** with the RtsKit addon: `RtsUnit` on the units, the command rig (one node: selection, orders, input), a camera, and a command UI if the game wants one.

This is **not** pathfinding, combat or AI: the kit hands each unit its order and the game executes it. **Not** multiplayer: if the game is networked, the order transport is game code in the game (`addons/rts_kit/GUIDE.md` › 6, MpKit's custom channel). **Does not** invent units, costs or rules.

Load: `godot-rts-kit`, `godot-composition-first`.

If `addons/rts_kit/` is missing:

```bash
# Copies the addon into the game's project.
./install.sh --addon /ABS/GODOT_ROOT rts_kit
```

Enable **RtsKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if 1–3 files; else `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. 2D or 3D, and which scene is the battlefield.
2. Which units exist (their scene) and who owns them (slots, teams).
3. How the player gives orders with the mouse beyond the right click: a command panel, a radial menu, both, or neither (keys only).
4. Camera: free top-down, following a hero, or both.
5. Networked? Then who is the server, and where the transport code lives (never in the addon).

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` removed), for example:

```
[~] levels/battle/battle.tscn          # + Rig (rts_command_rig_3d.tscn: camera, ground), Camera, Hud (+ CommandCard / RadialMenu)
[~] units/unit.tscn                   # + RtsUnit child
[+] units/unit_orders.gd              # the game's: walks to order.spot(), fights, complete()
[~] project.godot                      # RtsKit plugin; input actions (Tools > RtsKit: Add default input actions)
```

Follow `addons/rts_kit/GUIDE.md` (sections 2–6). The rig is one node: instance `addons/rts_kit/rig/rts_command_rig_3d.tscn` (2D: `rts_command_rig_2d.tscn`) in the battle scene, assign `camera` and `ground` (in 2D `camera` is enough) and leave the game's HUD after it in the tree; do not build `Command` or `View` by hand. To change a piece or wire the HUD to it: Editable Children; from a script: `@export var rig: RtsCommandRig` and `rig.selection`, `rig.orders`… The examples (`minimal_2d`, `skirmish_3d`, `skirmish_2d`) show it; do not copy their walker (the minimal one's `soldier.gd` is the shape of a unit script). In 2D distances are pixels: the 2D rig already has them and the inspector shows `px`; set `RtsUnit.size` in pixels.

## 3. Implement

Follow [godot-rts-kit](../skills/godot-rts-kit/SKILL.md). The unit logic listens to `order_started` and reports `complete()` / `fail()`; dead units turn `selectable` / `orderable` / `targetable` off. A unit rule (pacifist) = `extends RtsUnit`. A new order = an `RtsCommandType` in the game's catalog.

## 4. Done when

- F6: a box selects own units only; a right click on the ground moves them into formation; on a foe they attack it; Ctrl/Cmd+1 then 1 recalls the group; Alt+N keeps a formation.
- The rig shows no warnings in the editor (the yellow triangle: `camera` or `ground` is missing).
- Removing the command UI nodes (panel, radial menu) leaves the right click working.
- No unit movement or damage inside `addons/rts_kit`; no RPC either.
