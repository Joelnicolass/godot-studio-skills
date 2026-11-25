---
name: godot-code-quality
description: >-
  Code-quality conventions for Godot 4 (GDScript), taken from the official
  docs and the community's tools: rule 0 (simple and predictable: one owner
  per number, when a .tres exists, catalogs, docs/tuning.md), folders and
  file suffixes, proven patterns (signals, signal up / call down, Events bus,
  FSM, component, command, pool, type Resource, catalog, inherited scene,
  spawner), real typing, a readable inspector, ## versus #, language,
  gdformat/gdlint, and UNSAFE_* warnings. Use when writing or reviewing
  GDScript, planning a cut, generating RULES.md, deciding where a file goes,
  setting up lint, or deciding whether something deserves a .tres, an
  autoload, or a pattern.
---

# Godot — code quality

"Normal" Godot 4 code: the kind a developer who has never seen the project recognises on sight and changes without asking. Everything here comes from the official docs and the community's tools ([sources](#sources)).

Tree and composition: [godot-composition-first](../godot-composition-first/SKILL.md). Project size: [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Tests and CI: [godot-testing](../godot-testing/SKILL.md). Before / after: [examples.md](examples.md).

If one of the project's own conventions (RULES.md, a CONVENTIONS file) contradicts this guide, do not follow it silently: call it out and propose the standard.

## 0. Rule 0: simple and predictable

A person should guess where a thing lives and change it by opening one or two files. And when they cannot guess, they find it in `docs/tuning.md`.

This section is the whole rule. The other skills, the agents, and the commands cite it; they do not repeat it.

### One owner per number

"Editor first" means the value is in plain sight in the inspector, in a place you can guess. The design numbers of an entity (speed, health, damage, cost) have **one** owner, in this order:

1. **The entity has a type** (`EnemyType`, `WeaponType`): all its balance numbers are in the type's `.tres`. Components get them from the type (`health.setup(type.max_hp)`) and the scene does not override those same numbers in the component's inspector.
2. **It has no type:** they are exported on the scene **root**, grouped with `@export_group`. The root passes them to its children (call down). You open the scene and, without expanding the tree, see everything there is to touch.
3. **A reusable component** (`Health`, `Hitbox`) keeps its own `@export`s for what is not that entity's balance, and as the default when nobody passes another value. Its tooltip says so.

- Never the same number with a value in two places of one entity.
- If the design numbers of an entity end up spread over three or more children, give it a type even if it has a single variant.

### When a data `.tres` exists

It exists when one of these three holds:

- **several things share it;**
- **it is edited as a type** (an enemy, a weapon with variants): `class_name XType extends Resource` + one `x_type.tres` per variant;
- **it is balance tuned by someone who does not open scenes** (`match_config.tres`, a wave table): a file turns up in the FileSystem search; a node inside a scene does not.

If none holds, it is an `@export`. The look (a material, an `Environment`, a theme, a curve) is something else: a named file ([godot-composition-first](../godot-composition-first/SKILL.md) §3.1).

### Catalogs yes, blind tables no

- **Valid:** a **catalog** whose content is a typed list of named Resources (`@export var terrains: Array[TerrainType]`), where each entry is its own file and makes sense alone. It is what `TileSet`, `MeshLibrary`, `SpriteFrames`, and the kits' catalogs do. It can be an `@export` on a node or a `_catalog.tres`.
- **Valid:** a text key that **is painted data** (the terrain of a cell, as in a TileMap), when the key is declared in one place (the `id` of the `TerrainType`) and an editor warning flags a key that does not exist.
- **Invalid:** an untyped `Dictionary`, or `String → Resource`, whose key repeats something that already exists elsewhere (a material slot name, a node name); anonymous sub-resources (`Resource_umusd`) inside the catalog; a catalog nobody edits that only exists so code can look things up.
- **Test:** if I remove an entry, does the editor show what stops working? If not, it is a blind table.
- From about 15 variants of one type, offer a table view to compare them side by side (for example the [Edit Resources as Table](https://github.com/don-tnowe/godot-resources-as-sheets-plugin) plugin), with the user's OK like any third-party addon.

### No blind hops

- Outside the painted data above, no indirection through tags or text: a path built from a code (`"res://shots/" + tag + ".tscn"`), a `String` that picks a scene, a material slot name used as a key, a `node.get(&"prop")` with the name kept in an `@export StringName`, or an id → shader index dictionary far from the node that is that id. Reference the scene, node, or resource directly.
- No chains: going from A to B to C to find one number is a design bug.
- **Measure:** if changing a number means opening more than 2 files, the design is wrong.
- When two designs work, pick the one with fewer files and fewer hops, even if it is less "general".

### `docs/tuning.md`: the map of knobs

Every game has `docs/tuning.md`: a table "I want to change → file → node → property", in the user's language. Whoever plans writes the new rows in the plan, the tree includes `[~] docs/tuning.md`, whoever implements adds them, and the review marks NEEDS WORK when a feature added a design `@export` without its row.

| I want to change | File | Node | Property |
|---|---|---|---|
| Bat speed | `enemies/bat/bat_type.tres` | — | `speed_m_s` |
| Round length | `match/match.tscn` | `Match` | `round_seconds` |
| Hit flash color | `shared/vfx/hit_flash.tscn` | `Flash` | `color` |

## 1. Scenes and references

- A game concept (a creature, a weapon, a HUD widget) is a **scene** ([scenes vs scripts][s-scenes]). Its behaviour is child nodes you can see in the tree, each with its values in the inspector.
- References to other nodes are an `@export var health: Health` set in the inspector, or a `%UniqueName` inside the same scene ([interfaces][s-interfaces], [unique nodes][s-unique]). For nodes of your own scene, do not use `get_node("Name")` strings, `get_parent()` chains, or runtime searches by type or group.
- Scenes and resources: `@export var x: PackedScene`, dragged in the inspector. Do not `preload` into an `@export` default: the scene overwrites it and the load is wasted ([logic preferences][s-logic]).
- A scene that repeats in two places is its own `.tscn` and gets instanced; it is never copied node by node.
- In a big scene, group the children under plain parents (`World`, `Systems`, `Hud`, `Audio`) ([scene organization][s-org]).
- A node created from code is the exception: pools, bullets, and whatever depends on the match data (one tile per cell). Even then it is an exported `PackedScene` that gets instanced, not `MeshInstance3D.new()` with its mesh and material put together in code. Anything that exists once per scene is placed in the `.tscn`.
- An empty required `@export` shows an editor warning (`_get_configuration_warnings`) **and** calls `push_error` at runtime; never a silent `return`.
- **Folders.** One folder per subject at the root (`player/`, `enemies/bat/`, `levels/forest/`, `ui/hud/`), with no `scenes/` folder wrapping everything, "as close to scenes as possible" ([project organization][s-project]).
  - What a single entity uses lives in its folder: its `.tscn`, its `.gd`, its type `.tres`, and its art.
  - When the folder goes past about 8 files, the art moves down to subfolders by type **inside the entity**: `model/`, `textures/`, `audio/`, `vfx/`. The scene, its script, and its type `.tres` stay on top, in plain sight.
  - What two or more entities use lives in `shared/`, and there it is by type: `shared/components/`, `shared/shaders/`, `shared/materials/`, `shared/textures/`, `shared/vfx/`. In the systems + content size, shared code is in `systems/` and shared art in `content/`.
  - Autoloads in `autoloads/`. Test scenes in `debug/`: they stay out of the export (`debug/*` in the preset's exclude filter) and nothing in the game names them. `docs/` carries a `.gdignore`.
  - There is no `scenes/`, `scripts/`, `resources/`, `assets/`, or `glue/`. The full trees of both sizes: [godot-layered-architecture](../godot-layered-architecture/SKILL.md).
  - A color per folder in the FileSystem (right click › *Set Folder Color*) helps whoever browses the project.
- **The name says the type.** A `.tres` carries a suffix; one without a suffix does not pass review.

  | Suffix | What it is |
  |---|---|
  | `_type.tres` | Data of a type (`bat_type.tres`, an `EnemyType`) |
  | `_config.tres` | Global balance (`match_config.tres`) |
  | `_catalog.tres` | Catalog: a typed list of Resources |
  | `_material.tres` | Material |
  | `_env.tres` | `Environment` |
  | `_theme.tres` | `Theme` |
  | `_layout.tres` | A saved map or board |
  | `_curve.tres` | `Curve` |
  | Another resource | Its class name in `snake_case` (`_frames.tres` for `SpriteFrames`, `_gradient.tres`) |

- Files and folders in `snake_case`. A file is named after its `class_name` or its root node.

## 2. Communication: proven patterns only

Use these, and only these, so they are recognised on sight ([Game Programming Patterns][s-gpp]):

| Need | Pattern | How |
|------|---------|-----|
| A node says "something happened" | **Signal (observer)** | `signal died(by: Node)`, past tense and typed. Whoever cares connects; the emitter does not know who listens |
| A child reports to its owner | **Signal up, call down** ([KidsCanCode][s-kcc]) | Children emit and the parent calls methods on its children. A child never calls its parent |
| Two siblings | **The ancestor mediates** | The common parent connects the signals, in the scene or in its `_ready` ([scene organization][s-org]) |
| Systems that do not know each other (combat, HUD, audio, AI) | **Event bus** ([GDQuest][s-bus]) | One `Events` autoload with **only** typed `signal` declarations, no state, no methods. The owner of the fact emits. Local events stay plain signals: the bus is only for what crosses systems |
| An entity with modes | **FSM** | `FsmMachine` with one `FsmState` child per state ([godot-fsm](../godot-fsm/SKILL.md)), not `match mode:` blocks spread over a script |
| Behaviour shared by several entities | **Component** | A child node with its own script and `@export`s (`Health`, `Hitbox`). The entity is the sum of its components |
| Orders from the player or the AI | **Command** | One small object or method per order (`move`, `attack`), queued and executed by one owner. The same path for the player, the AI, and the network |
| Many short-lived objects (bullets, particles) | **Object pool** | The owning spawner or bus reuses instances. Callers never `queue_free` what belongs to the pool |
| Types and numbers shared by many instances | **Type Resource** | A `Resource` script with typed `@export`s (`EnemyType`) and one `_type.tres` per variant (rule 0) |
| A list of types to pick from (terrains, orders, waves) | **Catalog** | `Array[TerrainType]` with one file per entry (rule 0) |
| A variant with another structure or other art | **Inherited scene** | *New Inherited Scene* of the base scene; only what differs changes. One level of inheritance, no more |
| Creating entities | **Spawner** | One node per kind of thing instances the scene, sets it up, and adds it. On the network, a `MultiplayerSpawner` |

- Connect in the editor (Node › Signals panel) when both ends are in the same scene, and in `_ready` when one end is created at runtime. Never by a method-name string.
- A signal carries typed data: listeners do not reach back into the emitter to find out what happened.
- **Do not invent other patterns:** no registries, service locators, managers of managers, or an `X.of(node)` that searches the tree. If nothing in the table fits, write the simplest direct code.

## 3. Autoloads and global state

- An autoload is only for a service that **manages its own information** for the whole game ([autoloads][s-autoload]): the menu ↔ match flow, audio, networking, and the `Events` bus. Nothing else.
- The state of one match lives in a node of that match, not in a `static var`.
- An autoload with values to tune is registered as a scene (`.tscn`) or reads a `.tres`: a script autoload has no inspector.
- `class_name X extends RefCounted` is fine for **pure** rules and math: the pure core next to its node ([godot-layered-architecture](../godot-layered-architecture/SKILL.md) §2). They are the first thing to cover with GUT.
- Development tools are not autoloads of the shipped game.
- Groups are declared as **Global Groups** in Project Settings and named by a constant of their owner (`Enemy.GROUP`) ([groups][s-groups]).

## 4. GDScript

Follow the [style guide][s-style] and let `gdformat` decide the formatting.

- **Order inside a script:** `@tool` → `class_name` → `extends` → class `##` doc → `signal` → `enum` → `const` → `static var` → `@export` → public vars → private vars (`_x`) → `@onready` → virtuals (`_init`, `_ready`, `_process`…) → public methods → private methods. It is the order gdlint checks (`class-definitions-order`).
- **Names:**
  - `PascalCase` for classes and enums;
  - `snake_case` for functions and variables, with a leading `_` when private;
  - `CONSTANT_CASE` for constants and enum values;
  - past tense for signals (`died`, `health_changed`);
  - units in numeric names (`cooldown_s`, `range_m`, `speed_m_s`).
- **Real typing, not just declared** ([static typing][s-typing]):
  - typed `var`s and signatures, and typed collections (`Array[Enemy]`, `Dictionary[StringName, int]`);
  - typed access (`player.health.current`), not `.get("health")`, `.set("x", v)`, or `"x" in obj` on a type you know;
  - no `has_method` or `call("name")` on known types. If several types share a contract, a one-level base or a common component;
  - a typed class instead of a `Dictionary` whose keys live in a comment. A `Dictionary` is fine only at the network or save-file edge, with `to_dict()` / `from_dict()`;
  - the `UNTYPED_DECLARATION` and `UNSAFE_*` warnings turned on (§7). The count only goes down.
- **No magic values:** an enum instead of `0 / 1 / 2`; an `@export` (with `@export_range` and units) instead of a tuning number in code; `delta` or `Engine.physics_ticks_per_second` instead of a local `FPS := 60.0`.
- **A readable inspector:** each design `@export` carries a `##` that says what it does in design words, a range with its unit (`@export_range(0.0, 5.0, 0.05, "suffix:s")`, `"suffix:m"`), and an `@export_group` / `@export_subgroup` when the node has more than 5. The inspector's unit is the one the game uses: not an `m` suffix on a value in pixels. An `@export` whose setter rebuilds geometry or the look goes in a `@tool` script, so the change shows in the editor.
- One statement per line, under 100 columns, and two blank lines between functions.
- **No cap on script length.** Split by responsibility, not by count. A low cap leads to compressed code (one-line `if`s, 160-column lines) and to splitting a cohesive class into several. gdlint only warns at 1000 lines or 20 public methods.
- **Errors:** `push_error` for a broken setup, `push_warning` for a recoverable oddity, and `assert()` for programmer invariants (stripped from release builds). A game refusal (no mana, out of range) is an enum or a `StringName` constant, not free text.

## 5. Comments and documentation

- `##` is **API documentation**: it shows up in the editor help and as the inspector tooltip of an `@export` ([documentation comments][s-doc]). It goes on the class (right after `extends`), on public members, and on `@export`s, and it says what the thing does and what the values mean.
- `#` is for implementation notes, inside functions and only when the code cannot say it by itself. Never `##` inside a function.
- Comments describe the code as it is today. History (RFC numbers, cut names, "it used to…") belongs in git. A citation of another source (the original game, a paper, a thread) goes in a separate doc, not in a `##` that the inspector shows as a tooltip.
- A folder README exists only when it says something the code does not, in a few lines. The architecture goes in a one-page `docs/architecture.md`, and the knobs in `docs/tuning.md` (rule 0).

## 6. Language

- Code, comments, `print` / `push_warning` / `push_error`, editor warnings, and inspector groups (`@export_group`): **English**.
- Player-facing text lives in a translation file (an imported CSV, in `locale/`), not in a `.gd`. A `Control` uses the key as its text and translates itself; code uses `tr("KEY")` ([internationalizing games][s-i18n]). Changing a text is not editing code.

## 7. Standard tools

Do not write a custom grep-based lint for what the compiler and gdtoolkit already cover. gdtoolkit parses the syntax tree; a grep cannot see a path built from text or the order of declarations.

| Check | How |
|-------|-----|
| Format | `gdformat --check <folders>` (`pip install "gdtoolkit==4.*"`) |
| Lint | `gdlint <folders>`. Its defaults already are the standard: 100 columns, 1000 lines, 20 public methods, 6 `return`s, and the style guide's order. `gdlint -d` dumps a `gdlintrc` only when something needs changing (for example `tab-characters: 4` to count columns like the editor, or excluding third-party `addons/`) |
| Types | Project Settings › Debug › GDScript (with Advanced Settings): the warnings below set to *Warn* |
| Tests and CI | GUT and a workflow that runs everything above: [godot-testing](../godot-testing/SKILL.md) |

```ini
; project.godot (1 = Warn)
[debug]
gdscript/warnings/untyped_declaration=1
gdscript/warnings/unsafe_property_access=1
gdscript/warnings/unsafe_method_access=1
gdscript/warnings/unsafe_cast=1
gdscript/warnings/unsafe_call_argument=1
```

A custom check is only worth it for what the standard does not cover (a network boundary, assets that cannot be committed, scancodes instead of InputMap), and each one says why it exists.

## 8. Review: the questions that matter

1. **How many files do you open to change a number in this feature?** Count them. More than 2 = redesign. Is its row in `docs/tuning.md`?
2. Does each design number have a single owner (the type, or the root)? Does each new data `.tres` meet one of the three conditions of rule 0?
3. Is every collection a typed catalog with one file per entry? Is there a blind table (an untyped `Dictionary`, anonymous sub-resources)?
4. Is there a reference through a tag, a string, or a built path that is not painted data? Turn it into a direct `@export`.
5. Is each new file in the folder RULES.md says, and does each `.tres` have its suffix? Does anything in the game name `res://debug`?

   ```bash
   rg -n "res://debug" --glob '!debug/**' --glob '!agent/**'   # must be empty
   ```

6. Is any material, mesh, or node created or reassigned in `_ready`? List them, and say whether they show in the editor (in the scene, in the import, or with `@tool`) or why not.
7. Does each new `@export` have a `##`, a range with a unit, and a group when the node has more than 5? List the ones that do not. A design `@export` with no tooltip is NEEDS WORK.

   ```bash
   git diff --name-only -- '*.gd' | xargs rg -n -B1 '^@export'   # every @export should have a ## line above
   ```

8. Does every communication use a pattern from §2? Did a registry, locator, manager, or new autoload show up?
9. Is the typing real? Over the diff's `.gd` files (check each hit: a `Dictionary.get` at the network edge is legitimate):

   ```bash
   git diff --name-only -- '*.gd' | xargs rg -nP '(:|->)\s*(Dictionary|Array)\b(?!\[)'
   git diff --name-only -- '*.gd' | xargs rg -n '\.get\("|\.set\("|has_method\(|\.call\("'
   ```

10. `##` only on the API and `#` inside functions, with no history or citations? `rg -n '^\s+##'` finds indented `##`.
11. Logs and warnings in English, and player text in the translation file?
12. `gdformat --check`, `gdlint`, and GUT green, if the project has them? Paste the output.

## Sources

- Godot 4: [style guide][s-style] · [documentation comments][s-doc] · [static typing][s-typing] · [scene organization][s-org] · [scenes vs scripts][s-scenes] · [autoloads vs nodes][s-autoload] · [Godot interfaces][s-interfaces] · [logic preferences][s-logic] · [project organization][s-project] · [groups][s-groups] · [scene unique nodes][s-unique] · [Resources][s-resources] · [exported properties][s-exports] · [internationalizing games][s-i18n]
- gdtoolkit: [linter][s-gdlint] · [formatter][s-gdformat] · GUT: [docs][s-gut]
- Community: [GDQuest, GDScript guidelines][s-gdq] · [GDQuest, event bus][s-bus] · [KidsCanCode, node communication][s-kcc] · [Game Programming Patterns][s-gpp] · [godot-demo-projects][s-demos] (reference for idiomatic code) · folder structure: [tps-demo][s-tps], [GDQuest 3D controller][s-gdq3d], [GDQuest: modular architecture][s-modular]

[s-style]: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
[s-doc]: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html
[s-typing]: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html
[s-org]: https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html
[s-scenes]: https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html
[s-autoload]: https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html
[s-interfaces]: https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_interfaces.html
[s-logic]: https://docs.godotengine.org/en/stable/tutorials/best_practices/logic_preferences.html
[s-project]: https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html
[s-groups]: https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html
[s-unique]: https://docs.godotengine.org/en/stable/tutorials/scripting/scene_unique_nodes.html
[s-gdlint]: https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter
[s-gdformat]: https://github.com/Scony/godot-gdscript-toolkit/wiki/4.-Formatter
[s-gut]: https://gut.readthedocs.io/en/latest/
[s-gdq]: https://gdquest.gitbook.io/gdquests-guidelines/godot-gdscript-guidelines
[s-bus]: https://www.gdquest.com/library/pattern_event_bus_singleton/
[s-kcc]: https://kidscancode.org/godot_recipes/4.x/basics/node_communication/
[s-gpp]: https://gameprogrammingpatterns.com/contents.html
[s-demos]: https://github.com/godotengine/godot-demo-projects
[s-tps]: https://github.com/godotengine/tps-demo
[s-gdq3d]: https://github.com/gdquest-demos/godot-4-3d-third-person-controller
[s-modular]: https://www.gdquest.com/library/modular_game_architecture/
[s-resources]: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html
[s-exports]: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_exports.html
[s-i18n]: https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html
