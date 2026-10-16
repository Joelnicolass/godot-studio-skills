---
description: "Scaffold one replicated MpKit actor (script + scene) in the Godot game."
---

Create **one** replicated multiplayer feature in the **game’s Godot project** (not this skills repo). Same layout as Project → Tools → MpKit: New replicated feature.

If the game has no `addons/mp_kit`, stop and ask to install the addon.

1. Ask: id (`snake_case`), folder (`res://features` by default, or `src/features` if Clean), root (`CharacterBody2D` / `CharacterBody3D` / `Node2D` / `Node3D`), whether they want `MpCustomPipe` (Dictionary tunnel).
2. Show the tree (`[+] res://…/<id>/<id>.gd`, `[+] <id>.tscn`, `[~]` the match scene if you register the spawner) and wait for OK.
3. Create `res://…/<id>/<id>.gd` and `<id>.tscn` matching `MpFeatureScaffold` (submit_/apply_, MpReplicate, MultiplayerSynchronizer, optional pipe). Prefer running the addon scaffold if the user is in Godot; otherwise write the files.
4. Do not put score, copy, or this title’s loop. Leave `apply_action` empty.
5. Remind: register the scene on the match `MpSpawner`; LAN and dedicated use the same feature; tunnel = `send_custom` with no auto-broadcast.
6. If the project has no `.vscode/mpkit.code-snippets`, copy `addons/mp_kit/editor/mpkit.code-snippets`.

Return the paths you created.
