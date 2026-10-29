---
description: "Scaffoldea un actor de MpKit (escena con MpActor + MpInput y su script) en el juego Godot."
---

Creá **un** actor multiplayer en el **proyecto Godot del juego** (no en este repo de skills), con la capa de nodos de MpKit: lo mismo que hace una persona con Proyecto › Herramientas › *MpKit: Make selection a network actor* y la plantilla de script **MpKit actor**.

Si no hay `addons/mp_kit` en el juego, pará y pedí instalar el addon. Si el juego todavía no es multijugador (no hay `game.tres`, boot ni `MpWorld`), proponé primero *Setup game* (o copiar `addons/mp_kit/examples/minimal_2d/`).

Cargar: `godot-mp-kit`.

1. Preguntá: id (`snake_case`), carpeta (`res://features` por defecto, o `src/features` si es Clean), root (`CharacterBody2D` / `CharacterBody3D` / `Node2D` / `Node3D`), si lo maneja un jugador (`MpInput`, y `predict` si es su personaje), qué se ve igual en todos (*Sync*: posición, rotación, visible, extras).
2. Mostrá el árbol (`[+] res://…/<id>/<id>.gd`, `[+] <id>.tscn`, `[~]` el mundo si lo agregás a las *Extra Scenes* del `MpSpawner`) y esperá el OK.
3. Creá `<id>.tscn`: el root, su look, un hijo `MpActor` (Sync tildado, `predict` si corresponde) y, si lo maneja un jugador, `MpInput` con sus acciones. El `MpSync` lo arma el editor al guardar la escena: si no hay editor abierto, decile al usuario que abra y guarde la escena una vez (el inspector del `MpActor` lo avisa).
4. Creá `<id>.gd` desde la plantilla **MpKit actor** (`addons/mp_kit/script_templates/CharacterBody2D/mpkit_actor.gd`): reglas tras `net.is_authority()`, movimiento en `mp_move(keys, delta)` si predice, órdenes `mp_sv_*` y efectos `mp_all_*`. Sin `@rpc` a mano.
5. No pongas puntaje, copy ni loop de este título: los números de la partida van en `Mp.state()`, el fin en `Mp.finish()`.
6. Si el usuario pide RPC a mano (un caso que los nodos no cubren): Proyecto › Herramientas › *MpKit: New replicated feature...* (`MpFeatureScaffold`: `submit_*` / `apply_*`, `MpReplicate`, pipe opcional). Anotá por qué.
7. Si el proyecto no tiene `.vscode/mpkit.code-snippets`, copiá `addons/mp_kit/editor/mpkit.code-snippets`.

Devolvé las rutas creadas y si falta guardar la escena en el editor.
