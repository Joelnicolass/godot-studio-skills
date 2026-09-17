# AgentKit harness — do not contaminate product code

Read this **before** writing a playtest helper. Typical failure: the flow cannot set up state with clicks, so setup / force-state / count / pause methods land **in `src/`**. Sometimes they are prefixed `agent_*`; sometimes they use a gameplay-looking name. That **is** contamination. The name does not matter; **who calls it** does.

## Where playtest code may live

| Path | Playtest? |
|------|-----------|
| `res://agent/flows/*.json` | yes |
| `res://agent/harness/*.gd` | yes (`extends Node`, **no** `class_name`) |
| `res://agent/fixtures/` | yes (`.tres` / `.tscn` for the run only) |
| `res://src/`, `res://scenes/`, product glue | **no** |

Before editing a file outside `res://agent/`: **stop**. If the change only serves the flow, it belongs in the harness.

## What counts as playtest (role, not prefix)

Product code does **not** get a method whose job, for the flow, is to:

- spawn or place entities the player does not place on that screen
- force a state (contact, cooldown, victory, fight seed)
- count nodes for an assert
- pause or disable systems “until the agent is done”
- rebuild or replace the world only for the run

`func agent_*` in `src/` is banned. **Dropping the prefix and keeping the same role is still playtest.**

A public product API only if the **game** already needs it (load, generator, editor, replay). If the only caller is the flow JSON or `res://agent/`, it is playtest: it belongs in the harness.

## What the harness may do

Order:

1. Clicks / `press` / `wait_until` like a player. Prefer this.
2. `call.harness` to a script in `res://agent/harness/`.
3. In the harness: current scene, `%UniqueName`, `find_children`, packed scenes the **game already has**, **public** signals. Counts = `find_children`, not a new getter on product.
4. Fixtures in `res://agent/fixtures/`. Do not duplicate world-building logic.

```json
{ "call": { "harness": "hooks", "method": "setup_slice" } }
```

## If the reasoning sounds like this, stop

These arguments do **not** keep the product clean:

- “I’ll `call()` a `_on_*` / privates, so I did not contaminate.”
- “I’ll `extends` the product class from `agent/`, so the original script stays intact.”
- “I’ll rename `agent_*` to something that looks like gameplay.”
- “I’ll add a public method just for the flow.”
- “I’ll `set(\"_…\")` a private container ref / duplicate the product scene for the run.”

The helper belongs in `res://agent/harness/*.gd`. In `src/`, only APIs the **game** already needs. Setup, pause, forced state, and counts = harness (`find_children`, public signals, APIs a player also uses).

## Lies not to use

- `call()` on `_privates` / poking internal lists does **not** justify adding those methods on product “for usability”.
- `extends` a product class under `agent/` does not keep the product clean if you still demand a playtest API from it.
- A public method whose only caller is the flow **is** playtest. A product name (`load_level`, apply a layout) only if the **game** also uses it. No product caller → do not add it: set up in the harness or **stop** and ask.
- `set("_ref", …)` on the container to “avoid touching product” is the same coupling.

## Check before you finish

```bash
rg -n "func agent_" src scenes
git diff --stat -- src scenes
```

Zero `func agent_`. The playtest diff **does not add methods** in `src/` unless a product API is **already justified** (who else calls it, not the flow).
