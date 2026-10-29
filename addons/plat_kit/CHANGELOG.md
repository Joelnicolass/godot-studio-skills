# PlatKit changelog

## 0.2.0

**Changes**

- Jumping off a moving platform adds its velocity **once**. It used to be added twice: Godot adds it when the body leaves the floor (`platform_on_leave = ADD_VELOCITY`, the default) and the motor added it again. Now the motor adds the remembered velocity (`lift_remember`) only on a jump in coyote time, or when the body has another `platform_on_leave`. If you lowered your platforms' speed to make up for it, try them again.

**New**

- `release_jump()`: let go of the jump from code (cuts the jump and stops floating at the apex). With `read_input` off, a state or the network had no way to let go, and the jump stayed held forever.
- Minimal example `examples/minimal_2d/`: a player, a floor and two ledges, no code.
- Tests: `addons/plat_kit/tests/plat_test_runner.gd` plays the motor on real physics and the example with input.
- `axis`, `request_jump()`, `tick()`, `wall_dir()` and `try_side_corner_correct()` are documented in the script.

## 0.1.0

`PlatMotor` as a child of a `CharacterBody2D`: coyote, jump buffer, apex gravity, corner correction, lift remember, optional wall jump.
