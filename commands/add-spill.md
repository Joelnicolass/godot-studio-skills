---
description: "Blood and other substances (SpillKit addon): every hit sprays and marks the floor, a death grows a puddle; each substance is a type with the kit's wet look, PBR of its own or the game's shader, in 3D, with one property for the network."
---

Add **what a body spills** in the **game's Godot project** with the SpillKit addon:
- a `SpillSource3D` at the chest of every body that bleeds, with its type;
- one `SpillType` per substance (blood, ichor, oil, slime, ink);
- a `SpillPool3D` in the level;
- `hit()` where the game takes HP off and `die()` where it dies.

The person then tries it with the component's buttons in the 3D view; the agent sets up and explains.

This is **not** the game's HP or damage: the kit gets a hit's damage and the max HP. **Not** the network: a network game decides who calls `hit()` and how `wound` travels. **Not** dismemberment or wounds on the body's mesh.

Load: `godot-spill-kit`, `godot-composition-first`.

If `addons/spill_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT spill_kit
```

Enable **SpillKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat for 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which bodies spill and which substance each (red blood, a bug's green blood, a robot's oil); where the drops leave (the chest, the shell).
2. The look of each substance:
   - the kit's wet look (a colour only);
   - PBR textures of its own (albedo, normal, ORM);
   - or the game's material or shader (PS1) and the names of its texture and colour uniforms.
3. Where HP is taken off today (the HP component, the hurtbox) and where a body dies. Whether some hits are always heavy (a combo's finisher).
4. The rules: from what share of the HP a hit is heavy (40 %), how often at most a light spray (0.25 s).
5. The floor's layer; whether the bodies are on another.
6. Whether the game is networked (who decides damage, what it syncs with), whether it ships on the web, and whether the player can turn blood off.

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` removed), for instance:

```
[~] project.godot                        # SpillKit plugin; the floor layer's name
[+] resources/spill/blood.tres           # SpillType: red, the kit's look
[+] resources/spill/green_blood.tres     # SpillType: green, with mark_material = the game's PS1 material
[~] scenes/levels/level_1.tscn           # SpillPool3D: types [blood, green_blood]; floor_mask: the floor
[~] scenes/enemies/enemy.tscn            # Spill (SpillSource3D) at the chest, type green_blood; Spill:wound in what the game syncs
[~] scenes/enemies/enemy.gd             # on taking HP: $Spill.hit(damage, max_hp, from); on death: $Spill.die()
[~] scenes/ui/pause_menu.gd              # the "blood" option sets pool.shown
```

Start from `addons/spill_kit/examples/minimal_3d` (a dummy that bleeds) or `substances_3d` (six substances: the kit's look, PBR of its own, a shader of its own, a slope, a curb, night). Copy the types from `addons/spill_kit/examples/types/`.

## 3. Implement

Follow [godot-spill-kit](../skills/godot-spill-kit/SKILL.md) and `addons/spill_kit/README.md`.

- One type per substance; the component at the chest with its type; the pool in the level with the types in `types`.
- `hit(damage, max_hp, from)` where HP is taken off (`from`: the impact point or the attacker), `heavy = true` for a finisher; `die()` on death.
- A material of the game's own in `mark_material` / `puddle_material` / `drop_material`, with `texture_parameter` and `color_parameter` if its uniforms are named differently.
- Networked: `hit()` and `die()` only on the authority, and `wound` synced (MpKit: `Spill:wound` in `sync_extra`; MultiplayerSynchronizer: Spawn and On Change).
- Tell the person how to try it: select the component and press Spray, Heavy spray and Die (puddle) in the 3D view; the cost reads at the top of the pool's inspector.

## 4. Done when

- The component and the pool show no warnings, and the buttons draw on the scene's floor.
- F6: a hit sprays and marks, a heavy one leaves three marks, a death leaves a growing puddle.
- Networked, another instance sees the same and one that joins late does not see the old ones.
- No HP, damage or network inside `addons/spill_kit`.
