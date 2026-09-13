# Godot studio kit

Framework chico (y a propósito) para juegos Godot 4. El **chat principal orquesta**: pregunta, corre commands de producto, investiga si hace falta, y reparte plan / código / review a subagentes. El juego (dominio, glue, escenas) no vive acá.

Objetivo: una **base sencilla de escalar** a mano o con IA (composición, editor, Resources, scripts chicos).

Repo: https://github.com/Joelnicolass/godot-studio-skills

| Pieza | Dónde | Qué es |
|-------|--------|--------|
| Orquestador | `skills/godot-studio-workflow/` | El agente del chat: flujo PRD→RFC→implementar |
| Arquitectura / composición / MP / tests | `skills/` | Cómo escribir y testear Godot |
| Tech lead, developer, reviewer, tester, visual | `agents/` | Subagentes Cursor (`.cursor/agents/`) |
| PRD → features → rules → RFCs | `commands/` | Slash commands (`/create-prd`, …) |
| MpKit | `addons/mp_kit/` | Transporte LAN. Cero gameplay |

Qué **no** entra en este repo: puntaje, copy de producto, escenas de un título, `GameSession`, `SceneDirector`. Eso es glue del juego.

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

## Cómo se trabaja

En un chat nuevo, con el kit instalado, pedí el juego. El orquestador:

1. Pregunta Clean vs estándar (y lo que falte).
2. Ejecuta `/create-prd` … `/generate-rfcs` sin que tengas que tipear cada slash.
3. Investiga APIs Godot si hace falta.
4. Por cada RFC: **tech lead** (plan) → tu OK → **developer** → **reviewer**. Tester y visual solo si los pedís.

El desarrollador (humano o subagente) recibe un RFC + plan + RULES: camino corto, sin adivinar el resto del producto.

## Instalar (Cursor)

```bash
./install.sh                 # ~/.cursor/skills, commands, agents
./install.sh --project       # ./.cursor/ del cwd
```

Desde GitHub:

```bash
npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y
```

`npx skills` solo copia `skills/`. Commands, subagentes y el addon van con `./install.sh`.

Abrí un **chat nuevo** en Cursor después de instalar.

## Commands de producto

1. `/create-prd` → `PRD.md` (en juegos: GDD corto)
2. `/verify-prd` → `PRD-REVIEW.md`
3. `/extract-features` → `FEATURES.md`
4. `/generate-rules` → `RULES.md`
5. `/generate-rfcs` → `RFCs/` + `RFCS.md` (el primero es el slice vertical)
6. `/test-strategy` → opcional
7. `/implement-rfc <id>` (tubería de subagentes)
8. `/review-rfc <id>`
9. `/manage-changes` cuando se mueve el alcance
10. `/workflow-status`

## Instalar MpKit en un proyecto Godot

```bash
./install.sh --addon /path/to/godot-project
```

Autoload **antes** del glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

## Layout

```
addons/mp_kit/
skills/
  godot-studio-workflow/
  godot-layered-architecture/
  godot-composition-first/
  godot-mp-kit/
  godot-testing/
agents/                        # studio-tech-lead, studio-developer, …
commands/
install.sh
```

Cómo crece el framework: extraer a `addons/` o `skills/` cuando algo se reusa. No copiar un FX o un tracker de puntaje “por las dudas”.
