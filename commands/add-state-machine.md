---
description: "Agrega una máquina de estados por composición (FsmMachine + FsmState, addon FsmKit)."
---

Agregá una **máquina de estados** por composición en el **proyecto Godot del juego**: hijos `FsmState` bajo un `FsmMachine`.

Esto **no** es una feature de reglas (`/implement-feature`) salvo que el estado nuevo **sea** el alcance. **No** es el motor de plataformas (`/add-platformer-2d`). **No** inventa HP ni puntaje.

Cargar: `godot-fsm`, `godot-composition-first`. Si el actor ya se mueve como plataforma 2D: `godot-platformer-2d` (el motor es **otro** hijo; los estados lo llaman).

Si no está `addons/fsm_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT fsm_kit
```

Enable **FsmKit**. Si está `godot-studio-workflow`: orquestador → árbol (este chat si 1–3 archivos; si no `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Acotar

Si falta, preguntá en un lote:

1. Qué actor / escena.
2. Qué estados (Idle, Move, Hurt, …). Pocos. No un diagrama del título entero.
3. ¿Ya hay un `match` / enum? Reemplazarlo, no duplicar.

## 2. Plan

```
Actor
└── States          # FsmMachine, actor = Actor
    ├── Idle
    ├── Move
    └── …
```

Cada estado = script chico que extiende `FsmState`. Sus knobs en su propio `@export` (el `speed` de `Move`), o en el inspector del `PlatMotor` si hay motor; no magic numbers en `enter()`.

## 3. Implementar

Seguí [godot-fsm](../skills/godot-fsm/SKILL.md). Patrón de referencia: `addons/fsm_kit/examples/minimal_2d/` (un número por estado en su `@export`, el golpe como payload). `transition(&"Hurt")` por nombre de nodo. El estado no spawnea ni puntúa.

## 4. Listo cuando

- F6: se entra y se sale de al menos dos estados (una acción).
- Se apaga el comportamiento sacando el hijo `States`.
- No quedó un `enum` paralelo en el actor.
