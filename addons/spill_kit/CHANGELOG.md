# SpillKit changelog

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
