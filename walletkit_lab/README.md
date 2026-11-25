# walletkit_lab

- **What it is:** a tiny Godot project that runs WalletKit's example and tests without any game.
- **What it is not:** a game. `addons/wallet_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees, and `test_examples` plays `minimal` with its buttons (with its two inspector substitutes).
- **Verify:** `godot --headless --path walletkit_lab --script res://addons/wallet_kit/tests/wallet_test_runner.gd` → `WALLETKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path walletkit_lab --import`).
- **Play:** open the project. F5 runs `minimal`.
