---
description: "Recursos y monedas (addon WalletKit): un entero por clave con topes, pagar todo o nada, sustitutos con tasa que cubren lo que falta, payment_for para mostrar el costo, guardar con to_dict."
---

Agregá **recursos y monedas** en el **proyecto Godot del juego** con el addon WalletKit:
- un `Wallet` donde el juego guarda lo que tiene cada jugador (o un `Purse` por jugador en sus reglas, mostrado con `use_purse`);
- los topes de cada clave en `limits`;
- los `substitutes` que cubren lo que falta al pagar (el oro cubre todo, 2 de comida cubren 1 de madera);
- el HUD escuchando `changed`, `overflowed` y `rebuilt`.

Después la persona ve los montos y los sustitutos en el inspector; el agente arma y explica.

Esto **no** son precios, tiendas ni UI: el kit guarda y cobra, y el juego decide qué cuesta cada cosa y cuándo se cobra. **No** es la red: un juego en red cobra en el servidor y manda montos.

Cargar: `godot-wallet-kit`, `godot-composition-first`.

Si falta `addons/wallet_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT wallet_kit
```

Habilitá **WalletKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué recursos o monedas hay (claves) y cuáles tienen tope de almacén.
2. Con qué arranca cada jugador y cuántos jugadores hay (un `Purse` por jugador o un solo nodo).
3. Qué se paga y cuándo (construir, comprar, reclutar, un turno) y quién arma el costo.
4. Si alguna ficha reemplaza a otra al pagar: cuál, qué cubre, a qué tasa y en qué orden. Qué fichas no se pueden cubrir nunca (cultura, ánimo).
5. Qué muestra el HUD y si el juego guarda la partida o es en red.

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin WalletKit
[+] scenes/economy/wallet.tscn           # Wallet: start_amounts, limits, substitutes [food → wood a 2, gold → todo a 1]
[+] scenes/ui/resources_hud.gd           # escucha changed y rebuilt; muestra los montos
[~] scenes/ui/resources_hud.tscn         # los labels
[~] scenes/buildings/temple.gd           # can_pay(COST) deshabilita el botón; pay(COST) al construir
[~] scenes/levels/level.tscn             # instancia el Wallet
```

Arrancá desde `addons/wallet_kit/examples/minimal/minimal.tscn` (cosechar, topes, construir con sustitutos).

## 3. Implementar

Seguí [godot-wallet-kit](../skills/godot-wallet-kit/SKILL.md) y `addons/wallet_kit/README.md`.

- `start_amounts`, `limits` y `substitutes` en el inspector del `Wallet`, en orden de prioridad (el más específico primero).
- Las reglas llaman `can_pay(cost)` y `pay(cost)`; `add(gains)` devuelve lo perdido por el tope.
- Con un `Purse` por jugador en las reglas: `wallet.use_purse(player.purse)` y el HUD escucha `rebuilt`.
- `payment_for(cost)` para mostrar lo que se cobrará antes de confirmar.
- Guardar con `to_dict()` / `Purse.from_dict()`. En red, el servidor paga y manda montos.
- Decile a la persona cómo verlo: los sustitutos son recursos del inspector, y el nodo avisa de una regla vacía, repetida o que se cubre a sí misma.

## 4. Listo cuando

- El `Wallet` no muestra avisos y la persona vio sus sustitutos en el inspector.
- F6: sumar respeta los topes y avisa lo perdido; pagar usa lo propio y después los sustitutos en orden; sin alcanzar no cambia nada.
- El HUD muestra los montos y se redibuja con `rebuilt`.
- Nada de precios, tiendas ni red dentro de `addons/wallet_kit`.
