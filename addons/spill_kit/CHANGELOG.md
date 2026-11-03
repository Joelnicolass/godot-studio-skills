# SpillKit changelog

## 0.2.0

What El Eternauta found while planning its migration.

- **The heavy spray is tuned on its own.** The type has a Heavy spray group with values of its own: `heavy_drop_size_m`, `heavy_drop_speed_m_s`, `heavy_spread_deg`, `heavy_rise_deg`, `heavy_drop_life_s`, `heavy_drop_scale_min`/`max`. It used to be the light one multiplied by `heavy_scale`, which is gone. The light drops' size range is the type's too (`drop_scale_min`/`max`, 0.6 to 1.4), and `rise_deg` goes from 50° to 51°.
- **The floor's reach, per component.** `SpillSource3D.floor_reach_m`: how far under it the floor of its marks and puddle may be (0 = the pool's). A bug with its component at 0.8 m and a player at 1.25 m stop marking in the air at the same height over their feet. The pool's `spill()` and `puddle()` take an optional `reach_m`.
- **The level's pool takes the place of one made on its own.** If a body entered before its world's pool (a persistent scene with the players and the level loaded later), the pool made with the default values kept the world and the level's drew nothing. Now the level's takes its place.
- **Tests:** 42.

What to update: if a type changed `heavy_scale`, move its values to the Heavy spray group. With the defaults, a heavy hit comes out as in 0.1 but a bit faster (3 m/s), longer (0.85 s), lower (45°) and with somewhat bigger drops (0.7 to 1.6), like El Eternauta's blood.

## 0.1.1

- **A drops shader of your own that takes the particle's colour no longer warns** (found while reviewing El Eternauta's migration). Its `blood_drop.gdshader` uses `COLOR`, each drop's colour, and declares neither `albedo_tex` nor `albedo_color`. With it in `drop_material`, 0.1.0 warned that those uniforms were missing, though the drops drew fine. Now only a marks' or puddle's shader must declare them; a drops' shader gets the ones it declares.
- **Tests:** 39 (`test_a_drops_shader_that_takes_its_colour_from_the_particle`).

What to update: nothing.

## 0.1.0

The first version, asked for by El Eternauta: the blood of its RFC-041, made generic for any substance.

- **`SpillType`:** a substance in the inspector (blood, ichor, oil, slime, ink). It sets its colour, how its drops fly, its marks and its puddle, and how they look:
  - the kit's wet look, with normal maps of its own;
  - PBR textures of its own (albedo, normal, ORM) for the drops, the marks and the puddle;
  - or the game's material (its PS1 shader), which gets the texture and the colour through `texture_parameter` and `color_parameter`.
- **`SpillSource3D`:** the body's component.
  - `hit(damage, max_hp, from, heavy)` applies the rules: heavy from `heavy_from` (40 %) or by the blow, light ones `every_s` apart (0.25 s), small hits adding up to `min_lost`.
  - `die()` grows a puddle; `spray()` sprays with no rules.
  - One property for the network, `wound`: every machine draws what changed, and a late joiner sees nothing old.
  - Its own body never gets marks.
- **`SpillPool3D`:** what draws a world. Everything is built once per type and reused:
  - the sprays, rings of CPUParticles3D;
  - the marks, one MultiMesh per type that reuses the oldest;
  - the puddles, a ring that grows and shrinks to stay off a curb, along the floor's slope.

  No mark lands behind a wall. `shown` is the player's option and `clear()` starts a new round. `spill()` and `puddle()` work with no component. It warms each type's shaders up at load, so the first hit does not stall. On a dedicated server it builds nothing.
- **`SpillRules`, `SpillWound`, `SpillShapes`, `SpillMaterials`:** the rule, the packed value, the kit's own shapes and the materials, public and pure.
- **Editor:**
  - the "Try it" buttons (Spray, Heavy spray, Die (puddle), Clear the floor) draw in the 3D view, on the scene's floor;
  - the cost in the pool's and the component's inspector;
  - warnings for a missing type, an empty `floor_mask`, a second pool, a puddle too small, mark sizes the wrong way round and a shader of your own without its uniforms.
- **Compatibility and WebGL 2;** nothing is drawn on a dedicated server.
- **Examples:** `minimal_3d` and `substances_3d` (blood, oil, slime, mercury, PBR paint, ink with a shader of its own), and six types in `examples/types/`.
- **Tests:** 38, and an editor check (27 checks).
