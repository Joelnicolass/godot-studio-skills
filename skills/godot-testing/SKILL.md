---
name: godot-testing
description: >-
  Test Godot 4 projects with GUT (GDScript) or GdUnit4 (C#) and run them in CI
  (GitHub Actions: gdformat, gdlint, headless import, and GUT). Use when
  writing unit tests, scene tests, Resource, signal, pure-rule, or RefCounted
  domain tests, when setting up headless CI, or when choosing a Godot test
  runner.
---

# Godot — tests and CI

Do not invent a runner. Detect the one already there (GUT, GdUnit4, repo script). If there is none and the user asked for tests: **GUT** for GDScript, **GdUnit4** if the project is C#. Do not install a framework without saying so.

Architecture: [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Composition: [godot-composition-first](../godot-composition-first/SKILL.md). Lint and type warnings: [godot-code-quality](../godot-code-quality/SKILL.md).

## What to test

| Layer | How |
|------|------|
| Pure rules (`class_name` + `static func`) and Clean domain (`RefCounted`) | `MyRule.new()` or the static call. No scene, no autoloads. This is the first batch |
| Type Resource | Construct the Resource or load the `.tres`; do not mutate the shared asset |
| Node / component | Add it as a child of the test with `add_child_autofree`. Test signals |
| Feel / camera / juicy | Annotated playtest. A green unit test does not prove it feels right |

No filler tests. Each test must **fail** if an acceptance criterion breaks.

## GUT (GDScript)

- **Install:** "GUT - Godot Unit Testing" from the Asset Library, or a release of [bitwes/Gut](https://github.com/bitwes/Gut/releases). GUT 9.x is for Godot 4; pick the release whose notes name your Godot version. Enable the plugin.
- **Folders:** `res://test/unit/` (fast, pure rules) and `res://test/integration/` (scenes). Files `test_*.gd`, `extends GutTest`, functions `test_*`.
- `before_each` / `after_each` per test; `before_all` / `after_all` per script.
- Nodes: `add_child_autofree(scene.instantiate())`; `assert_no_new_orphans()` when you suspect leaks.
- Signals: `watch_signals(node)` and `assert_signal_emitted(node, "died")`.
- Input: GUT helpers (`GutInputSender`), and **clear** them in teardown.
- `test/` and `addons/gut/` stay out of the export (the preset's exclude filter).
- Default options in `res://.gutconfig.json`; command-line options override them.

```bash
# From the project root (where project.godot is)
godot --headless --path "$PWD" --import      # clean checkout: builds the class_name cache
godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit -ginclude_subdirs -gexit
```

It returns `0` if everything passes and `1` if anything fails: CI relies on that code. `-gjunit_xml_file=<path>` writes a JUnit report. Paste the real output.

## GdUnit4 (C#)

- Use the project’s GdUnit4 runner: scene runner and `simulate_action_*` per its API.
- Do not mix GUT and GdUnit4 in the same title without a reason.

## CI (GitHub Actions)

One workflow that runs, on every push and PR, the same thing you run by hand: format, lint, import, and tests. Pin the project's exact Godot version.

```yaml
# .github/workflows/godot-checks.yml
name: Godot checks
on: [push, pull_request]

jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install "gdtoolkit==4.*"
      - run: gdformat --check scenes test
      - run: gdlint scenes test
      - uses: chickensoft-games/setup-godot@v2
        with:
          version: 4.x.y          # the project's exact version
          use-dotnet: false
          include-templates: false
      - run: godot --headless --path "$PWD" --import
      - run: godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit
```

- Match the folders to the project's, and set `working-directory` if the game lives in a subfolder.
- In an older project with many lint findings, the existing code can run with `continue-on-error: true` until the `gdformat` pass. Tests and new code block from day one.
- `npm test` and TS typechecks do not apply.

## Anti-patterns

- Installing GUT “just in case” in a game the user did not want tests for.
- Testing the whole `.tscn` for a sum that lives in a pure rule.
- Leaving nodes without free.
- Claiming feel coverage with an `assert_eq` on a shader float.
- A CI that runs something different from what you run by hand.
