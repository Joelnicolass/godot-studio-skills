# deckkit_lab

- **What it is:** a tiny Godot project that runs DeckKit's example and tests without any game.
- **What it is not:** a game. `addons/deck_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees, and `test_examples` plays `minimal` with its buttons and clicks (drawing, discarding one of two copies, dragging to the discard and back, refilling and dealing with the same seed twice).
- **Verify:** `godot --headless --path deckkit_lab --script res://addons/deck_kit/tests/deck_test_runner.gd` → `DECKKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path deckkit_lab --import`).
- **Editor check:** `godot --headless --editor --path deckkit_lab -- --deckkit-editor-check` → `DECKKIT EDITOR CHECK PASS (n)`. The `editor_check` plugin only acts with that argument (without it, opening the lab is normal). It opens a temporary copy of `minimal.tscn` in the editor, checks that the deck's `HandView` shows the 12 start cards, changes `start_cards` and `card_scene` through the editor's history (as the inspector does), undoes and redoes with Ctrl/Cmd+Z, saves and reads the file; at the end it deletes the copy and checks the example was not touched. It is the only check that goes through the real editor and **does not replace** looking at the cards with your own eyes.
- **Play:** open the project. F5 runs `minimal`.
