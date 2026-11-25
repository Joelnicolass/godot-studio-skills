# walletkit_lab

- **Qué es:** un proyecto Godot chico que corre el ejemplo y los tests de WalletKit sin ningún juego.
- **Qué no es:** un juego. `addons/wallet_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles, y `test_examples` juega `minimal` con sus botones (con sus dos sustitutos del inspector).
- **Verificar:** `godot --headless --path walletkit_lab --script res://addons/wallet_kit/tests/wallet_test_runner.gd` → `WALLETKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path walletkit_lab --import`).
- **Jugar:** abrí el proyecto. F5 corre `minimal`.
