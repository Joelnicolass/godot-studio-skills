# Platformer forgiveness (catalog)

Source: [Celeste & Forgiveness](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html). The addon covers generic 1–4 and 7. The rest is glue **if the game has** dash / one-way / stamina.

## In PlatKit

1. **Coyote** — jump for a moment after leaving the floor.
2. **Jump buffer** — the press is stored and spent on landing.
3. **Apex** — hold jump → less gravity at the peak (more time to adjust the land).
4. **Jump corner** — ceiling corner → slide in X so you don’t bonk.
7. **Lift** — `get_platform_velocity()` is remembered for `lift_remember` s.

Wall jump with `wall_extra_pixels` (the article: 2 px at 320×180 ≈ ¼ tile). Off by default.

## Game glue

### Dash corner / one-way pop

During a **title** dash, call `PlatMotor.try_side_corner_correct(delta)` and raise `side_corner_pixels`. One-way: if the dash crosses a `collision_one_way`, the game sets `global_position.y` to the collider top — that knows your layers; it does not belong in the addon.

### Super wall-jump

If there is a “super” verb (dash up + wall jump), use **more** `wall_extra_pixels` in that state (the article: ~5 px). An `@export` on the state, not a PlatKit fork.

### Stamina refund

If you have two wall jumps with similar inputs (up vs away): a short post-jump window that **converts** to the other and refunds stamina. That is a rule of **your** stamina resource, not the motor.

## Intensity

If the user does not say: coyote **0.08**, buffer **0.12**, apex **0.5**. Do not put 0.4 s of coyote “to make it fair” without asking.
