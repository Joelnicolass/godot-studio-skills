# SpillKit

What a body spills, in 3D: blood, ichor, oil, slime, ink.
- **Every hit** sprays drops and leaves marks on the floor, which stay for the whole match.
- **A death** grows a puddle: it follows the floor's slope, shrinks to stay off a curb and, if it does not fit by the curb, moves to the nearest flat floor.
- **Each substance is a type** (`SpillType`) in the inspector: its colour, how its drops fly, its marks, its puddle and how they look. It can have the kit's wet look (with normal maps of its own), your PBR textures (albedo, normal, ORM) or your game's material (a PS1 shader).
- **The rules are values** of the component: heavy from 40 % of the HP, light sprays at most every 0.25 s, small hits adding up.
- **One property for the network:** `wound`. Every machine draws what changed, and one that joins late sees nothing old.
- **In the editor:** buttons to try it in the 3D view, its cost in the inspector, and warnings.

It works in Compatibility and in WebGL 2: it uses CPUParticles3D, MultiMesh and quads with standard materials, which draw the same in every renderer. It draws nothing on a dedicated server. There is no network code and no autoload, and SpillKit depends on no other kit. Three calls are all the game writes: `hit()`, `die()` and, in a network game, syncing `wound`.

```bash
./install.sh --addon /path/to/godot-project spill_kit
```

Enable the **SpillKit** plugin for the cost line in the inspector. The nodes, their buttons and their warnings work without it.

**Examples:**

- `examples/minimal_3d/minimal_3d.tscn`: the minimum, a dummy that bleeds (below, [Minimal example](#minimal-example)).
- `examples/substances_3d/substances_3d.tscn`: six substances side by side, one type each:
  - **blood:** a type with only its colour, the kit's wet look;
  - **oil:** black and glossy, with a big slow puddle;
  - **slime:** green, translucent and soft-edged, by a curb (its puddle shrinks to stay off it);
  - **mercury:** a metal, on a ramp (its puddle follows the slope);
  - **paint:** a PBR type with its own albedo, normal and ORM textures;
  - **ink:** with a shader of the game's own (flat and banded), the way a game puts its PS1 material.

  Keys:
  - **Click a dummy, or 1 to 6:** a hit (right click or Shift: heavy).
  - **Space:** a hit on all of them. **K:** they all die. **R:** a new round.
  - **L:** a lamp from the camera. **N:** night. **Left and right:** turn around them.
- `examples/types/`: the six types, to copy.

## Start

1. **Make a type.** In the FileSystem: right click → New Resource → `SpillType`, for instance `blood.tres`. Give it a colour: that alone already looks wet. Or copy one from `examples/types/`.
2. **Add a `SpillSource3D`** to the body, where the drops leave (the chest, the shell), and give it the type.
3. **Add a `SpillPool3D`** to the level (one per world) and list in `types` the types it uses. If it is missing, the first component makes one with the default values and warns; if the level brings its own later, the level's takes its place.
4. **Call `hit(damage, max_hp, from)`** where the game takes HP off, and **`die()`** when the body dies.
5. **Try it in the editor:** select the component and press **Spray**, **Heavy spray** or **Die (puddle)** in its "Try it" group. The drops, marks and puddle show in the 3D view, on your scene's floor.

## Minimal example

`examples/minimal_3d/minimal_3d.tscn` (F6): a dummy on a floor. A click is a 20 % hit, a right click a 50 % one (heavy), K kills it and R cleans the floor.

```
Minimal3D (minimal_3d.gd)
├── WorldEnvironment, Sun, Camera3D
├── Floor (StaticBody3D)               # on layer 1: the floor the marks look for
├── SpillPool3D                        # types: [blood.tres]
├── Dummy (StaticBody3D)               # on layer 2: the floor rays do not see it
│   └── Spill (SpillSource3D)          # at the chest, 1.25 m up; type: blood.tres
└── Label
```

```gdscript
# minimal_3d.gd (the essentials)
func strike(damage: float) -> void:
	hp -= damage
	spill.hit(damage, MAX_HP, camera.global_position)  # the drops fly away from you
	if hp <= 0.0:
		spill.die()                                     # a puddle grows under it
```

**Tips from it:**
- `hit()` decides whether it bleeds and how much. Two clicks closer than `every_s` spray once, and one of 40 % or more is heavy (3 marks instead of 1).
- The third argument is where the hit came from: the impact point or the attacker. The drops fly the other way.
- The dummy's body is found on its own (the nearest physics body above the component), so the rays that look for the floor go through it.

## Network

The kit has no network. A network game calls `hit()` and `die()` only where damage is decided (the server) and syncs one property of the component, `wound` (a `Vector4`). Every machine draws what changed: the spray and its marks, or the puddle. A machine that meets the body late starts from the value it brings and draws nothing old.

**With MpKit:** in the body's `MpActor`, add `Spill:wound` to **Sync › sync_extra**. Everything travels at spawn, so a late joiner starts from the current value.

```gdscript
# enemy.gd: the server decides the damage; clients only draw what arrives in wound
func take_damage(amount: float, from: Vector3) -> void:
	if not MpKit.is_authority():
		return
	hp -= amount
	$Spill.hit(amount, max_hp, from)
	if hp <= 0.0:
		$Spill.die()
```

**With Godot's `MultiplayerSynchronizer`:** in its Replication add the property `Spill:wound`, with **Spawn** on and **Replicate: On Change**. Call `hit()` and `die()` behind `multiplayer.is_server()`.

Two sprays closer together than one send interval arrive as one (the last). The `every_s` rule already keeps them farther apart than that, except a heavy hit right after another spray.

## The type (`SpillType`)

One resource per substance. It only describes how it looks; when it bleeds is up to the component.

| Value | What it does |
|---|---|
| `color` | The colour of the drops, the marks and the puddle. Its alpha is their opacity with `alpha_scissor` at 0 |
| `roughness` | 0 = a mirror (fresh, wet), 1 = matte (dry). Multiplies an ORM's green |
| `metallic` | 0 = a liquid, 1 = a metal (mercury, molten metal). Multiplies an ORM's blue |
| `specular` | How bright the highlights are |
| `normal_scale` | How much the normal maps raise the surface (0 = flat) |
| `alpha_scissor` | Above 0, cuts the pixels with less alpha: hard edges that never sort wrongly where marks overlap. 0 = soft edges, blended by alpha |
| **Spray:** `drops` | Drops of a light hit |
| `drop_size_m`, `drop_speed_m_s` | Side of a drop; how fast it leaves (each one 25 % more or less) |
| `spread_deg`, `rise_deg` | How wide the spray opens, and how far above the horizon it leaves |
| `drop_life_s` | How long a drop flies (it falls through the floor: the marks are what it leaves) |
| `drop_scale_min`, `drop_scale_max` | Each drop is `drop_size_m` times a size between these |
| **Heavy spray:** `heavy_drops`, `heavy_drop_size_m`, `heavy_drop_speed_m_s`, `heavy_spread_deg`, `heavy_rise_deg`, `heavy_drop_life_s`, `heavy_drop_scale_min`, `heavy_drop_scale_max` | The same for a heavy hit, tuned on its own (32 drops of 0.12 m at 3 m/s, 38° wide, at 45°, 0.85 s, 0.7 to 1.6). Its drops look like the light ones: the Spray group's textures and material |
| **Marks:** `marks_per_spray`, `marks_per_heavy` | Marks a light hit and a heavy one leave |
| `mark_radius_m`, `mark_min_m`, `mark_max_m` | They fall anywhere this far around the body, between these sizes |
| **Puddle:** `puddle_size_m`, `puddle_grow_s` | The side of a grown puddle (smaller where the floor is not flat), and how long it takes to grow |
| `drop_` / `mark_` / `puddle_albedo_texture` | Its shape (alpha) and colour, multiplied by `color`. Empty = the kit's shape |
| `drop_` / `mark_` / `puddle_normal_texture` | Its normal map. Empty = the kit's shape's, or none with an albedo of yours |
| `drop_` / `mark_` / `puddle_orm_texture` | Occlusion (red), roughness (green), metallic (blue). Empty = `roughness` and `metallic` alone |
| `drop_` / `mark_` / `puddle_material` | Replaces the kit's material on that surface: your game's shader or material. A drops' shader may take its colour from `COLOR` (the particle's) and declare no uniform |
| **Own material:** `texture_parameter`, `color_parameter` | On a ShaderMaterial of yours, the uniform that gets the surface's texture and the one that gets `color` (`albedo_texture`, `albedo_color`). A marks' or puddle's shader must declare them; a drops' shader need not |

## The component (`SpillSource3D`)

It goes in the body, where the drops leave. The drops leave from its position, and the marks and the puddle fall on the floor under it.

| Value | What it does |
|---|---|
| `type` | What this body spills |
| `pool` | The pool that draws it. Empty = its world's `SpillPool3D` |
| `floor_reach_m` | How far under the component the floor of its marks and puddle may be; farther (in the air), none. 0 = the pool's `floor_reach_m`. A low component (a bug's shell) wants less than a chest |
| **Rules:** `heavy_from` | A hit that takes at least this share of the max HP is heavy (0.4) |
| `every_s` | Light sprays keep at least this far apart; the hits in between add up (0.25 s) |
| `min_lost` | The damage (a share of the max HP) that has to add up before a light spray; a hit that comes alone (no other for `every_s`) bleeds anyway (0.05) |
| **Try it:** Spray, Heavy spray, Die (puddle), Clear the floor | Buttons that try it in the editor's 3D view (and in play). The drops fly the way the node faces (-Z) |
| `wound` | The last spray and death, packed: the value to sync. Neither saved nor shown |

| Method | What it does |
|---|---|
| `hit(damage, max_hp, from = INF, heavy = false) -> bool` | A hit. The drops fly away from `from` (without `from`, any way). `heavy`: a blow that is always heavy (a combo's finisher). True if it bled |
| `spray(heavy = false, from = INF)` | Sprays now, without the rules (a wound of the game's own) |
| `die()` | A puddle grows under it. A body that comes back can die again |
| `current_pool() -> SpillPool3D` | The pool that draws it (null on a dedicated server) |
| static `body_above(node)` | The nearest physics body above a node: the floor rays go through it |

## The pool (`SpillPool3D`)

One per world (a level). It builds everything once per type and reuses it: a hit makes nothing new.

| Value | What it does |
|---|---|
| `shown` | Off, nothing new is drawn and what is on the floor stays (a player's "blood" option) |
| `types` | The types it builds when it starts. A component builds its type when it enters, listed or not |
| `floor_mask` | What counts as floor for marks and puddles. Keep the bodies out of it |
| `floor_reach_m` | It looks for the floor down to this far under the hit; farther (in the air), no mark |
| **Sprays:** `sprays_per_type` | Sprays kept per type and weight; more at once reuse the oldest (6) |
| **Marks:** `marks_per_type` | Marks kept per type; past that the oldest is reused (64) |
| `mark_shade_min` | Each mark's shade goes from this (darker) to 1, so they do not repeat |
| `mark_lift_m`, `mark_lift_step_m` | Off the floor, and a bit more per mark so two that overlap never flicker (64 heights, then over) |
| **Puddles:** `puddles` | Puddles kept, every type together (12) |
| `puddle_start_m`, `puddle_lift_m` | The side it starts growing from; off the floor (under the marks) |
| `puddle_probes`, `puddle_edge_share`, `puddle_flat_m`, `puddle_shrink`, `puddle_min_m` | Before it grows, it casts rays around its edge; if one finds the floor farther than `puddle_flat_m` (a curb, a step), it shrinks until it fits. Under `puddle_min_m`, it does not fit there |
| `puddle_seek_m` | If not even a `puddle_min_m` puddle fits under the body (by a curb, on its bevel), it looks for flat floor this far around, away from the slope first and never higher than where the body lies: a liquid runs down, not up a curb. 0 = no puddle there (0.75) |
| **Try it:** Clear the floor | Takes every mark and puddle off |

| Method | What it does |
|---|---|
| `spill(type, at, away = ZERO, heavy = false, exclude = [], reach_m = 0)` | A spray with no component (a barrel that leaks oil). `away` is the way it flies, flat; `reach_m`, how far under it the floor may be (0 = `floor_reach_m`) |
| `puddle(type, at, exclude = [], reach_m = 0)` | A puddle under `at` |
| `clear()` | Takes everything off the floor and out of the air (a new round) |
| `prepare(type)` / `refresh(type)` | Builds a type now / takes the type's values again, leaving what is on the floor |
| `material_of(type, shape)` | The material it draws a type's drops, marks or puddles with (`SpillShapes.Shape.DROP`, `MARK`, `PUDDLE`) |
| `mark_count(type)`, `marks_of(type)`, `puddles_of(type)`, `sprays_played(type)` | What is on the floor, for tests or a debug probe |
| `cost()`, `cost_text()` | What it keeps: drops, marks, puddles and the most draw calls |
| static `of(world)`, `draws_here()` | A world's pool; false on a dedicated server |

## In the game

| You want to | Write |
|---|---|
| Make a hit bleed | `$Spill.hit(damage, max_hp, attacker.global_position)` |
| The combo's third hit always heavy | `$Spill.hit(damage, max_hp, from, true)` |
| A puddle on death | `$Spill.die()` |
| A wound with no rules (a script, a trap) | `$Spill.spray(true)` |
| The player's "blood" option | `pool.shown = prefs.blood` (what is on the floor stays) |
| A new round | `pool.clear()` |
| Oil leaking from a barrel, with no body | `pool.spill(oil, barrel.global_position)` and `pool.puddle(oil, barrel.global_position)` |
| A species that bleeds more easily | `heavy_from = 0.25` on its component |
| Fewer marks on a slow machine | The pool's `marks_per_type`, or the type's `marks_per_spray` |
| A low bug that leaves no mark when it jumps | Its component's `floor_reach_m`: the component's height plus what it tolerates in the air (0.8 + 0.6 = 1.4) |
| A more violent heavy hit | The type's Heavy spray group: more `heavy_drops`, more `heavy_drop_speed_m_s` |
| A network game | [Network](#network): `hit()` and `die()` on the server, `wound` synced |
| Draw nothing on a dedicated server | Nothing: an export with the `dedicated_server` feature, or an export run headless, builds nothing. One run with the editor headless does draw: `pool.shown = false` there |
| Change the material live | `pool.material_of(type, SpillShapes.Shape.MARK)`, or change the type and call `pool.refresh(type)` |

## Materials: PBR or yours

Each type draws three surfaces (the drops, the marks and the puddle), and each one looks one of three ways:

1. **The kit's wet look:** only `color`, `roughness`, `metallic`, `specular`. The kit draws its own drop (a round bead), its mark (with droplets around) and its puddle, each with a normal map: a rounded edge and a flat middle. The light catches the edge and the middle reflects like a mirror.
2. **Your PBR:** set `mark_albedo_texture`, `mark_normal_texture`, `mark_orm_texture` (and the same for `drop_` and `puddle_`), as in GrassKit's `GrassMesh`. The albedo carries the shape in its alpha. With an ORM the kit uses an `ORMMaterial3D`, and its green and blue are multiplied by `roughness` and `metallic` (leave them at 1 to let the texture lead).
3. **Your game's material:** assign `mark_material` (and `drop_material`, `puddle_material`), for instance the game's PS1 ShaderMaterial. Each surface gets a copy:
   - on a ShaderMaterial, the kit writes the surface's texture into `texture_parameter` and `color` into `color_parameter`, when the shader declares them;
   - on a BaseMaterial3D, the kit writes `albedo_texture` (if it has none) and `albedo_color`.

   Each mark's shade comes in as vertex colour (`COLOR` in a shader), like each drop's colour. A drops shader has to face the camera (see `examples/types/flat_ink.gdshader`); it may take its colour from `COLOR` and declare no uniform.

All of that works in Compatibility and WebGL 2: the kit's materials are StandardMaterial3D or ORMMaterial3D. On a slope, the puddle's and the marks' normals follow the floor.

## In the editor

- Select a `SpillSource3D`. At the top of the inspector, the cost of a hit and of a death; under "Try it", the buttons **Spray**, **Heavy spray**, **Die (puddle)** and **Clear the floor**. The drops fly the way the node faces (-Z), and the marks and the puddle fall on the scene's floor (the editor's physics finds it). Each button takes the type's current values first, so changing the type and pressing again shows the change.
- In a body's scene alone (with no pool), the button makes a pool there, which is not saved.
- Select the `SpillPool3D`: at the top, what it keeps (drops, marks, puddles and the most draw calls). It follows the values as they change.
- The scene tree warns for a component with no type, an empty `floor_mask`, a second pool in the same world, a puddle smaller than `puddle_min_m`, `mark_min_m` above `mark_max_m`, and a marks' or puddle's shader of your own without the uniforms of `texture_parameter` or `color_parameter` (a drops' one needs none).

What the buttons draw is never saved in the scene.

## Performance

Nothing is made per hit: each type has its sprays (a ring of CPUParticles3D per weight), its marks (a MultiMesh) and shares the puddles (MeshInstance3D). The marks are one draw call per type; each spray in the air and each puddle, one.

**Measured** on an M4 Mac, at 1280 × 720 with the kit's look:

| What | Cost |
|---|---|
| A spray (`spill()`: its 1 or 3 marks and their rays) | 9 µs |
| A puddle (`puddle()`: with its 8 edge rays) | 12 µs; 0.16 ms by a curb, where it looks for flat floor (0.19 ms if it finds none) |
| 2 types: 128 marks, 12 puddles and 552 drops in the air | Within the frame's noise (1.2 to 1.9 ms in all), in Compatibility and in Forward+ |
| Compiling a new type's shaders | About 230 ms, while the level loads |

Godot compiles a shader the first time it draws it. So that this does not happen on the first hit, the pool draws a drop, a mark and a puddle of each type right after it builds it, for two frames, smaller than a pixel in front of the camera. List the level's types in `types` and all of that happens while it loads. Without that warm-up, the first hit of each type stalled about 180 ms.

The inspector of the pool shows the cost per machine (`cost_text()`). With many types, lower `sprays_per_type` and `marks_per_type` first.

## Tips and recommendations

- **The component at the chest.** The drops leave from there, and the marks look for the floor under it, down to `floor_reach_m`. A body in the air sprays but leaves no mark. Bodies of different heights: each component's `floor_reach_m`.
- **A layer for the floor.** `floor_mask` is what counts as floor. Bodies on another layer, or the body itself, which is found on its own, never get marks.
- **Hard edges for many marks.** With `alpha_scissor` above 0, two marks that overlap never sort wrongly. Soft edges (`alpha_scissor` at 0, the example's slime) look better in small numbers.
- **One type per species, not per body.** Every body of a type shares its sprays, its marks and its material.
- **A body placed in the level** (not made by a spawner) in a network game: its first network value can arrive after it is ready, and a late joiner would see that old spray once. Bodies a spawner (or MpKit) makes bring their value at spawn.
- **Your game's PS1 shader** goes in `mark_material` / `puddle_material` / `drop_material`. With `texture_parameter` and `color_parameter`, one material serves every type.

## Where the ideas come from

The first version was a network game's blood, measured with four players. This kit made it generic:
- **Sprays that are not made per hit:** reused rings of particles, as action games with many enemies do.
- **Marks that stay the whole match and reuse the oldest:** like the blood decals of shooters, but in a MultiMesh, which draws the same in every renderer and on the web.
- **A puddle that grows on death and shrinks to stay off a curb.**
- **One property for the network, with counters:** a late joiner compares counters, not events, so it never sees the old ones.

The wet look (a rounded edge with a flat middle, low roughness) is a meniscus: a liquid rests on the floor with a curved edge.

## Tests

```bash
godot --headless --path spillkit_lab --script res://addons/spill_kit/tests/spill_test_runner.gd
```

The result is `SPILLKIT TESTS PASS (n)`. The tests cover:

- **the rules:** heavy at 40 % or by the blow, light ones `every_s` apart, small hits adding up, a lone graze that still bleeds;
- **the value that travels:** its counts, deaths starting over, from nowhere;
- **the component with physics:**
  - a hit sprays and marks the floor under it; the drops fly away from where the hit came from;
  - a death grows a puddle, and a body that comes back dies again;
  - a machine that reads the value draws the same, under its own body; a late joiner draws nothing old;
  - its own body never gets marks; none behind a wall or in the air; each component's floor reach;
  - with no pool one is made; a spray of the game's own; the warning with no type;
- **the pool:**
  - the ring of marks and their heights; the ring of puddles; the heavy spray with values of its own;
  - a puddle on a slope and by a curb; by a curb or on its bevel, the puddle moves to flat floor; it never climbs onto a block or squeezes into a narrow gap;
  - the player's option and a new round; built once per type, all internal; the cost;
  - one pool per world and its warnings; a pool made on its own gives way to the level's; spilling with no component;
  - each type drawn once at load, tiny and in front of the camera, and then removed;
- **the materials:**
  - a type with only its colour looks wet (the kit's normal maps);
  - a PBR type's normal map and ORM reach the material and what the pool draws;
  - a game's ShaderMaterial and StandardMaterial3D, copied, with their texture and colour;
  - a drops' shader that takes the particle's colour, with no uniform and no warning;
  - the kit's shapes rise like a liquid;
- **a scene saved and loaded again:** its values, and nothing drawn and no `wound`;
- **every script loads; what runs on a server uses no camera, screen or material; no other kit is named;**
- **both examples, end to end**, and a click that hits the dummy under it.

A test that stops on a script error, or never checks anything, fails.

The buttons have a check of their own in a real editor. It checks:
- in `minimal_3d`, pressing Spray, Heavy spray, Die (puddle) and Clear the floor in the inspector draws and cleans in the 3D view, on the floor the editor's physics finds;
- the cost lines and the warning with no type;
- the saved scene, with nothing drawn in it;
- a body's scene alone, where Spray makes a pool that is not saved.

```bash
SPILLKIT_EDITOR_CHECK=1 godot --headless --editor --path spillkit_lab
```

It prints `EDITOR CHECK PASS`.

## Not in the kit

This is the game's:

- the HP and the damage (the kit gets a hit's damage and the max HP, never the HP);
- who decides the damage in a network game, and how `wound` travels;
- where a hit came from (the impact point or the attacker);
- the player's "blood" option (`shown`) and where it is saved;
- its shader or material, if it does not use the kit's.
