---
description: "Scaffold one MpKit actor (a scene with MpActor + MpInput and its script) in the Godot game."
---

Create **one** multiplayer actor in the **game’s Godot project** (not this skills repo), with MpKit's node layer: the same a person does with Project › Tools › *MpKit: Make selection a network actor* and the **MpKit actor** script template.

If the game has no `addons/mp_kit`, stop and ask to install the addon. If the game is not multiplayer yet (no `game.tres`, boot or `MpWorld`), offer *Setup game* first (or copying `addons/mp_kit/examples/minimal_2d/`).

Load: `godot-mp-kit`.

1. Ask: id (`snake_case`), folder (`res://features` by default, or `src/features` if Clean), root (`CharacterBody2D` / `CharacterBody3D` / `Node2D` / `Node3D`), whether a player drives it (`MpInput`, and `predict` if it is their character), what looks the same for everyone (*Sync*: position, rotation, visible, extras).
2. Show the tree (`[+] res://…/<id>/<id>.gd`, `[+] <id>.tscn`, `[~]` the world if you add it to the `MpSpawner`'s *Extra Scenes*) and wait for OK.
3. Create `<id>.tscn`: the root, its look, an `MpActor` child (Sync ticked, `predict` when it applies) and, if a player drives it, `MpInput` with its actions. The editor builds the `MpSync` when the scene is saved: with no editor open, tell the user to open and save the scene once (the `MpActor` inspector warns about it).
4. Create `<id>.gd` from the **MpKit actor** template (`addons/mp_kit/script_templates/CharacterBody2D/mpkit_actor.gd`): rules behind `net.is_authority()`, movement in `mp_move(keys, delta)` if it predicts, `mp_sv_*` orders and `mp_all_*` effects. No hand-written `@rpc`.
5. Do not put score, copy, or this title’s loop in it: match numbers go in `Mp.state()`, the end in `Mp.finish()`.
6. If the user asks for hand-written RPC (a case the nodes do not cover): Project › Tools › *MpKit: New replicated feature...* (`MpFeatureScaffold`: `submit_*` / `apply_*`, `MpReplicate`, optional pipe). Note why.
7. If the project has no `.vscode/mpkit.code-snippets`, copy `addons/mp_kit/editor/mpkit.code-snippets`.

Return the paths you created and whether the scene still needs a save in the editor.
