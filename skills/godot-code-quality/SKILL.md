---
name: godot-code-quality
description: >-
  Code-quality conventions for Godot 4 (GDScript), taken from the official
  docs and the community's tools: rule 0 (simple and predictable: the value
  lives on the node that uses it), proven patterns (signals, signal up / call
  down, Events bus, FSM, component, command, pool, shared Resource, spawner),
  real typing, ## versus #, language, gdformat/gdlint, and UNSAFE_* warnings.
  Use when writing or reviewing GDScript, planning a cut, generating RULES.md,
  setting up lint, or deciding whether something deserves a .tres, an
  autoload, or a pattern.
---

# Godot — code quality

"Normal" Godot 4 code: the kind a developer who has never seen the project recognises on sight and changes without asking. Everything here comes from the official docs and the community's tools ([sources](#sources)).

Tree and composition: [godot-composition-first](../godot-composition-first/SKILL.md). Layers: [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Tests and CI: [godot-testing](../godot-testing/SKILL.md). Before / after: [examples.md](examples.md).

If one of the project's own conventions (RULES.md, a CONVENTIONS file) contradicts this guide, do not follow it silently: call it out and propose the standard.

## 0. Rule 0: simple and predictable

A developer should guess where a thing lives and change it by opening one or two files.

- "Editor first" means the value lives **on the node that uses it**, as an `@export`, visible in the inspector. It does not mean a `.tres` or a pointer for everything.
- A `.tres` exists only when **several things share it** or when **it is edited as a type** (an enemy, a weapon with variants). If a single scene uses it, it is an `@export` on the node.
- No indirection through tags or text. That covers a key that names another resource, a path built from a code (`"res://shots/" + tag + ".tscn"`), or a `String` that picks a scene. Reference the scene, node, or resource directly.
- No chains: going from A to B to C to find one number is a design bug.
- **Measure:** if changing a number means opening more than 2 files, the design is wrong.
- When two designs work, pick the one with fewer files and fewer hops, even if it is less "general".

## 1. Scenes and references

- A game concept (a creature, a weapon, a HUD widget) is a **scene** ([scenes vs scripts][s-scenes]). Its behaviour is child nodes you can see in the tree, each with its values in the inspector.
- References to other nodes are an `@export var health: Health` set in the inspector, or a `%UniqueName` inside the same scene ([interfaces][s-interfaces], [unique nodes][s-unique]). For nodes of your own scene, do not use `get_node("Name")` strings, `get_parent()` chains, or runtime searches by type or group.
- Scenes and resources: `@export var x: PackedScene`, dragged in the inspector. Do not `preload` into an `@export` default: the scene overwrites it and the load is wasted ([logic preferences][s-logic]).
- A scene that repeats in two places is its own `.tscn` and gets instanced; it is never copied node by node.
- In a big scene, group the children under plain parents (`World`, `Systems`, `Hud`, `Audio`) ([scene organization][s-org]).
- A node created from code is the exception (pools, bullets). Anything that exists once per scene is placed in the `.tscn`.
- An empty required `@export` shows an editor warning (`_get_configuration_warnings`) **and** calls `push_error` at runtime; never a silent `return`.
- One folder per entity when it helps: `enemies/bat/` with its `.tscn`, `.gd`, `.tres`, and art. Assets go "as close to scenes as possible" ([project organization][s-project]). A separate data folder only for types that several scenes share.
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
| Types and tuning shared by many instances | **Resource as data** | A `Resource` script with typed `@export`s (`EnemyType`), only when shared (rule 0) |
| Creating entities | **Spawner** | One node per kind of thing instances the scene, sets it up, and adds it. On the network, a `MultiplayerSpawner` |

- Connect in the editor (Node › Signals panel) when both ends are in the same scene, and in `_ready` when one end is created at runtime. Never by a method-name string.
- A signal carries typed data: listeners do not reach back into the emitter to find out what happened.
- **Do not invent other patterns:** no registries, service locators, managers of managers, or an `X.of(node)` that searches the tree. If nothing in the table fits, write the simplest direct code.

## 3. Autoloads and global state

- An autoload is only for a service that **manages its own information** for the whole game ([autoloads][s-autoload]): the menu ↔ match flow, audio, networking, and the `Events` bus. Nothing else.
- The state of one match lives in a node of that match, not in a `static var`.
- `class_name X extends RefCounted` with `static func` is fine for **pure** rules and math, with no state. They are the first thing to cover with GUT.
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
- One statement per line, under 100 columns, and two blank lines between functions.
- **No cap on script length.** Split by responsibility, not by count. A low cap leads to compressed code (one-line `if`s, 160-column lines) and to splitting a cohesive class into several. gdlint only warns at 1000 lines or 20 public methods.
- **Errors:** `push_error` for a broken setup, `push_warning` for a recoverable oddity, and `assert()` for programmer invariants (stripped from release builds). A game refusal (no mana, out of range) is an enum or a `StringName` constant, not free text.

## 5. Comments and documentation

- `##` is **API documentation**: it shows up in the editor help and as the inspector tooltip of an `@export` ([documentation comments][s-doc]). It goes on the class (right after `extends`), on public members, and on `@export`s, and it says what the thing does and what the values mean.
- `#` is for implementation notes, inside functions and only when the code cannot say it by itself. Never `##` inside a function.
- Comments describe the code as it is today. History (RFC numbers, cut names, "it used to…") belongs in git. A citation of another source (the original game, a paper, a thread) goes in a separate doc, not in a `##` that the inspector shows as a tooltip.
- A folder README exists only when it says something the code does not, in a few lines. The architecture goes in a one-page `docs/architecture.md`.

## 6. Language

- Code, comments, `print` / `push_warning` / `push_error`, editor warnings, and inspector groups (`@export_group`): **English**.
- Everything the player sees goes through `tr()` (or the project's strings module).

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

1. **How many files do you open to change a number in this feature?** Count them. More than 2 = redesign.
2. Is each new `.tres` shared by several things or edited as a type? If not, it is an `@export` on the node.
3. Is there a reference through a tag, a string, or a built path? Turn it into a direct `@export`.
4. Does every communication use a pattern from §2? Did a registry, locator, manager, or new autoload show up?
5. Is the typing real? Over the diff's `.gd` files (check each hit: a `Dictionary.get` at the network edge is legitimate):

   ```bash
   git diff --name-only -- '*.gd' | xargs rg -nP '(:|->)\s*(Dictionary|Array)\b(?!\[)'
   git diff --name-only -- '*.gd' | xargs rg -n '\.get\("|\.set\("|has_method\(|\.call\("'
   ```

6. `##` only on the API and `#` inside functions, with no history or citations? `rg -n '^\s+##'` finds indented `##`.
7. Logs and warnings in English, and player text through `tr()`?
8. `gdformat --check`, `gdlint`, and GUT green, if the project has them? Paste the output.

## Sources

- Godot 4: [style guide][s-style] · [documentation comments][s-doc] · [static typing][s-typing] · [scene organization][s-org] · [scenes vs scripts][s-scenes] · [autoloads vs nodes][s-autoload] · [Godot interfaces][s-interfaces] · [logic preferences][s-logic] · [project organization][s-project] · [groups][s-groups] · [scene unique nodes][s-unique]
- gdtoolkit: [linter][s-gdlint] · [formatter][s-gdformat] · GUT: [docs][s-gut]
- Community: [GDQuest, GDScript guidelines][s-gdq] · [GDQuest, event bus][s-bus] · [KidsCanCode, node communication][s-kcc] · [Game Programming Patterns][s-gpp] · [godot-demo-projects][s-demos] (reference for idiomatic code)

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
