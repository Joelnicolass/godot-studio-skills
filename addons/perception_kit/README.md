# PerceptionKit

What an actor perceives, in 2D and 3D:
- **Sight:** a view cone that starts seeing at one distance and keeps seeing until a farther one, all-around awareness up close, and walls that hide.
- **Hearing:** the game's noises, each heard up to its own distance.
- **Any other sense:** a kind of the game's own (an alarm, a smell, a hit, a lit lamp), with no change to the kit.
- **Memory:** each thing perceived is remembered with where it was last, and forgotten after a time.
- **In the editor:** the view drawn in the 2D and 3D views, with handles to drag it; every drag undoes.

There is no network, no game rule and no autoload, and PerceptionKit depends on no other kit. Two signals, `perceived` and `forgotten`, and a few questions (`latest()`, `sees_any()`, `is_aware()`) are all a game's state machine reads.

```bash
./install.sh --addon /path/to/godot-project perception_kit
```

Enable the **PerceptionKit** plugin for the handles in the editor. The nodes work without it.

**Examples:**

- `examples/minimal_3d/minimal_3d.tscn`: the minimum, a guard that turns its head toward what it perceives (below, [Minimal example](#minimal-example)).
- `examples/minimal_2d/minimal_2d.tscn`: the same in 2D.
- `examples/guards_3d/guards_3d.tscn`: a yard with two guards that watch, look at you, search where they saw or heard you and walk back home. Keys:
  - **Arrows:** walk.
  - **Space:** a noise; every guard within 12 m hears it.
  - **L:** your lamp, a target of kind `&"light"` the guards see from 2.5 times farther.
  - **N:** night; the guards see half as far.
  - **The dark patch** is shade: in it you are less visible.

## Start

1. **Add a PerceptionSensor3D** to the actor's head (a child of whatever turns to look). It looks along its -Z. Its view shows in the 3D view.
2. **Add a PerceptionTarget3D** to what it should see, where it is seen from (a character's chest).
3. **Drag the view's handles** to size it: sight, lose, angle, near, eye height.
4. **Connect `perceived` and `forgotten`**, or read `latest()` from the actor's states.

In 2D, the same with PerceptionSensor2D (it looks along its +X; rotate it) and PerceptionTarget2D, in pixels.

## Minimal example

`examples/minimal_3d/minimal_3d.tscn` (F6): a guard, a wall, and you. Arrows walk you; Space makes a noise.

```
Minimal3D (minimal_3d.gd)
├── WorldEnvironment, Sun, Camera3D, Floor
├── Wall (StaticBody3D)                 # on layer 1: it hides you
├── Guard (StaticBody3D)                # the sensor's own body: never hides its view
│   └── Head (Node3D)                   # turns toward what it perceives
│       ├── Nose
│       └── Sensor (PerceptionSensor3D) # sight 12, lose 16, angle 100°, near 2, show_in_game
└── Player (CharacterBody3D)
    └── Target (PerceptionTarget3D)     # at the chest
```

```gdscript
# minimal_3d.gd (the essentials)
func _physics_process(delta: float) -> void:
	var latest := sensor.latest()  # the youngest thing it remembers, or null
	if latest != null:
		var to := latest.position - head.global_position
		head.rotation.y = rotate_toward(head.rotation.y, atan2(-to.x, -to.z), deg_to_rad(TURN_DEG_S) * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		sensor.hear(player.global_position, NOISE_RADIUS_M, player.get_instance_id())
```

**Tips from it:**
- The head turns, and the sensor with it. The guard's body is found on its own (the nearest body above the sensor), so the ray from the eyes never hits it; the same for your body around your target.
- `latest()` is all the guard needs: it keeps pointing at where you were last seen or heard until it forgets you, and is null after.
- Nothing in the script knows about the wall: the occlusion mask (layer 1) does.

## The sensor (`PerceptionSensor3D` / `PerceptionSensor2D`)

| Setting | What it does |
|---|---|
| `sight_radius_m` (`_px`) | It starts seeing a target within this distance and the view's angle |
| `lose_radius_m` (`_px`) | It keeps seeing one it sees until this distance (no flicker at the edge) |
| `view_angle_deg` | The whole view, around its up axis (360: all around). The height does not count |
| `near_radius_m` (`_px`) | Within it, it notices a target behind it too (walls still hide it) |
| `eye_height_m` (3D) | The eyes, this far above the sensor (0: the sensor is at the eyes) |
| `occlusion_mask` | The world's layers that hide a target |
| `body` | Its own body, never in the way. Empty: the nearest body above it |
| `sight_scale` | Scales every sight radius: night, fog, a blinding flash |
| `reach_by_kind` | Kinds it sees from farther: `{&"light": 2.5}` |
| `hearing_scale` | Scales every noise's radius: 0 deaf, 2 keen |
| `memory_s` | It forgets one this long after it last perceived it |
| `sense_hz` | Looks a second (5). Each sensor looks at its own moment, the same every run |
| `enabled` | Off, it perceives nothing and forgets everything, without signals |
| `show_in_game` | Draws its view in the game: grey (nothing), amber (remembers what it does not see), red (sees). Never headless |

**Sides are physics layers.** A target's collision layer is its side; a sensor sees the targets on the layers of its collision mask. Out of the box both are on layer 1, like any area, so everything sees everything. Name a layer per side (Project Settings › Layer Names), apart from the world's, put each target on its side's layer and tick the sides each sensor sees: the physics engine then filters them for free. The inspector shows a sensor's mask and a target's layer only: what the kit sets itself (nothing detects a sensor, a target detects nothing) is neither shown nor saved.

**One look** takes the targets inside the sensor's own sphere (sized by `reach_m()`, internal, not saved), then for each:
1. its radius: `lose_radius_m` if it sees it already, else `sight_radius_m`, times `sight_scale`, `reach_by_kind[target.kind]` and the target's `visibility`;
2. within `near_radius_m`, or within the radius and the view's angle;
3. one ray from the eyes, past the sensor's and the target's own bodies.

What passes is seen. A target it saw that fails is no longer seen but stays remembered, where it was last.

## The target (`PerceptionTarget3D` / `PerceptionTarget2D`)

| Setting | What it does |
|---|---|
| `enabled` | Off, no sensor sees it (it is still remembered until forgotten) |
| `visibility` | 0 to 1: how visible it is now. The game lowers it in the dark, in cover, crouched |
| `kind` | What seeing it gives: `&"sight"`, or the game's own (`&"light"` for a lamp) |
| `radius_m` (`radius_px`) | Its own sphere (internal, not saved) |
| `body` | Its own body, which never hides it. Empty: the nearest body above it |

## What it perceives (`PerceptionStimulus`)

| Field | What it is |
|---|---|
| `kind` | `PerceptionStimulus.SIGHT`, `HEARING`, or the game's own StringName |
| `position` | Where it was last (`position_2d` in 2D) |
| `strength` | 1 at the eye (or the noise), 0 at the edge of its radius |
| `age_s` | Seconds since it was last perceived |
| `sensing` | Perceived at the latest chance (seen in the latest look, heard since it) |
| `target` | The seen target, or null (a noise, or a freed target) |
| `key` | The target's instance id, or the noise's `source` |

The sensor keeps one per seen target and one per kind and source, and updates the same object while it keeps perceiving it: a state that holds one reads it fresh.

## Signals and questions

| You want to | Write |
|---|---|
| React when it notices something | `sensor.perceived.connect(func(stimulus): ...)`: once when it starts seeing a target, on every noise and every `sense()` |
| React when it gives up | `sensor.forgotten.connect(func(stimulus): ...)`: `stimulus.position` is where it was last |
| Know where to look or go | `sensor.latest()`, or `latest(PerceptionStimulus.HEARING)` |
| Know if it sees anyone now | `sensor.sees_any()`, `sensor.sees(target)` |
| Know if it is on alert | `sensor.is_aware()`: it remembers something |
| Everything it remembers | `sensor.remembered()`, or of a kind |
| What it knows of one target | `sensor.stimulus_of(target)` |

## In the game

| You want to | Write |
|---|---|
| Tell it about a noise | `sensor.hear(position, radius_m, source)`: true when heard. Connect the game's own noise signal to each sensor that listens |
| A sense of the game's own | `sensor.sense(&"alarm", position, strength, source)` |
| Only the server perceives | `sensor.enabled = is_server` (the game decides; the kit has no network) |
| Hide in the dark or in cover | `target.visibility = 0.3` |
| Night or fog for a guard | `sensor.sight_scale = 0.5` |
| A lamp seen from afar | A PerceptionTarget3D with `kind = &"light"` on the lamp, `enabled` while it is lit, and `reach_by_kind = {&"light": 2.5}` on the sensors |
| Stop seeing a dead or hidden one | `target.enabled = false` |
| Forget everything (a respawn) | `sensor.forget_all()` |
| A rule of the game's own for the radius | A script that `extends PerceptionSensor3D` and overrides `_sight_radius(target, seen, radius) -> float`; if it can return more than `reach_m()`, override `reach_m()` too |
| A shared memory for a squad | A `PerceptionMemory` of the game's own, fed from the squad's `perceived` |
| The pure checks, in a test or a tool | `PerceptionGeometry.in_view_3d(eye, basis, point, half_angle)`, `in_view_2d()`, `strength_at()` |

## In the editor

Select a sensor:
- **3D:** its view is drawn at its eyes, with five handles: **sight radius**, **lose radius** (it stays over the sight radius), **view angle** (on the sight arc's edge), **near radius** (behind) and **eye height** (the eyes' point; drag it seen from the side).
- **2D:** the same four handles, without eye height, in the 2D view.

Every drag is one step of the editor's history (Ctrl+Z), and a cancelled one leaves the value. The scene tree warns when the lose radius is under the sight radius, and when the mask is empty.

## Performance

A look is cheap and comes `sense_hz` times a second, each sensor at its own moment, so they never all look in the same frame:
- the physics engine gives only the targets inside the sensor's sphere, on its mask's layers;
- the radius and the angle come before the ray, and only what passes them casts one, reusing the query;
- memory ages every physics frame, a few entries each.

**Measured** headless on an M4 Mac, a 40 × 40 m yard with walls, 5 Hz:

| Sensors × targets | A look | Per physics frame |
|---|---|---|
| 8 × 4 | 7 µs | 0.004 ms |
| 50 × 30 | 38 µs | 0.16 ms |
| 200 × 100 | 163 µs | 2.7 ms |

With many sensors, lower `sense_hz` first, then the radii (fewer candidates).

## Tips and recommendations

- **The handles first.** Size a sensor with its handles in the actor's scene; every instance takes those values, and a value changed in one instance is that one's.
- **The sensor on the head.** Turning the head turns the view; the body is found on its own.
- **A layer per side.** Out of the box everything sees everything (layer 1), and the sensors' spheres also meet the world's bodies on it.
- **Read `latest()`, not the signals, in a state machine.** The signals start and end a state; `latest()` says where to look while it lasts.
- **A noise per source.** Give `hear()` a `source` (a player's slot, an instance id): the same source stays one memory and keeps its newest position.
- **Hysteresis is the point.** Keep `lose_radius_m` a quarter or a third over `sight_radius_m`.
- **Networked games** perceive on the server only (`enabled`), and send what the actor does about it, not the perception.

## Where the ideas come from

Unreal Engine's AI Perception shaped the model:
- sight with a sight radius, a farther lose-sight radius and a peripheral angle;
- noises reported to the system with a range;
- stimuli with an age, forgotten past a maximum age;
- an actor's eyes as the view's point.

Stealth games (Thief, Splinter Cell) make light and darkness change how visible a target is: here, `visibility` and a light as a kind of its own.

## Tests

```bash
godot --headless --path perceptionkit_lab --script res://addons/perception_kit/tests/perception_test_runner.gd
```

The result is `PERCEPTIONKIT TESTS PASS (n)`. The tests cover:

- **the geometry:** the view in 3D (height aside, turned, scaled) and 2D, strength, the drawn lines, the handles' math;
- **the memory:** new and refreshed, aging and forgetting, the latest (a seen one wins a tie), kinds;
- **the 3D sensor in physics:**
  - seen inside the view and radius, once; not outside the angle or the radius;
  - kept until the lose radius, then remembered where it was last;
  - walls hide (and only on the occlusion mask), near awareness behind, a wall hides a near one too;
  - its own body and the target's never hide; the eyes over a low wall;
  - noises: heard by radius and `hearing_scale`, each one perceived, one memory per source;
  - forgotten past `memory_s`, seen again before that not perceived again, a freed target forgotten with no target;
  - sides by layers, `visibility`, `sight_scale`, `reach_by_kind`, a `_sight_radius()` of the game's own;
  - `sense()`, off and on, a target turned off;
  - its sphere internal and unsaved, the warning, nothing drawn headless, each sensor at its own moment;
- **the 2D sensor:** the view aimed by rotation, the lose radius and memory, walls and near, noises, sides and visibility;
- **the handles' drags** in 3D (turned) and 2D (scaled);
- **a scene saved and loaded again** keeps a sensor's mask and a target's layer, and saves nothing of the kit's own;
- **every script loads; the sensors use no camera, picture or shader; no other kit is named;**
- **the three examples, end to end.**

A test that stops on a script error, or never gets to check anything, fails.

The handles have their own check in a real editor: the guard's gizmo, dragging its sight, angle and eye handles from the 3D view's camera with undo and redo, a cancelled drag, the warning, the saved scene; then the 2D sensor's handles with the mouse and their undo.

```bash
PERCEPTIONKIT_EDITOR_CHECK=1 godot --headless --editor --path perceptionkit_lab
```

It prints `EDITOR CHECK PASS`.

## Not in the kit

These are the game's:

- what an actor does about what it perceives (its states, its alert levels, chasing);
- where noises come from (the game's own signal, calling `hear()`);
- who perceives in a networked game (`enabled`);
- its sides (layer names) and what light and darkness mean (`visibility`, `sight_scale`).
