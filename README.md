# Godot studio kit

Framework chico (y a propósito) para juegos Godot 4: **skills de Cursor**, **commands de producto** (PRD / RFC) y **addons Godot**. Se agranda de a una pieza reusable. El juego (dominio, glue, escenas) no vive acá.

Repo: https://github.com/Joelnicolass/godot-studio-skills

| Pieza | Dónde | Qué es |
|-------|--------|--------|
| Arquitectura (Clean **o** estándar; **preguntar**) / composición / Resources / MP | `skills/` | Instrucciones para el agente |
| PRD → features → rules → RFCs → implement / review | `commands/` | Slash commands de Cursor (`/create-prd`, …) |
| MpKit | `addons/mp_kit/` | Plugin Godot: transporte, slots, RPCs de sesión. Cero gameplay |

Qué **no** entra en este repo: puntaje, copy de producto, escenas de un título, `GameSession`, `SceneDirector`. Eso es glue del juego.

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

## Instalar skills (Cursor)

```bash
./install.sh                 # ~/.cursor/skills/ y ~/.cursor/commands/
./install.sh --project       # ./.cursor/skills/ y ./.cursor/commands/ del cwd
```

Desde GitHub:

```bash
npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y
```

`npx skills` solo copia `skills/`. Commands y el addon Godot van con `./install.sh`.

Abrí un **chat nuevo** en Cursor después de instalar.

## Commands de producto

Quedan como slash commands (`/create-prd`, …). Flujo:

1. `/create-prd` → `PRD.md`
2. `/verify-prd` → `PRD-REVIEW.md`
3. `/extract-features` → `FEATURES.md`
4. `/generate-rules` → `RULES.md`
5. `/generate-rfcs` → `RFCs/` + `RFCS.md`
6. `/test-strategy` → `TEST-STRATEGY.md`
7. `/implement-rfc <id>`
8. `/review-rfc <id>`
9. `/manage-changes` cuando se mueve el alcance
10. `/workflow-status` en cualquier momento

`npx skills` no instala estos archivos; usá `./install.sh`.

## Instalar MpKit en un proyecto Godot

```bash
./install.sh --addon /path/to/godot-project
```

Eso deja `addons/mp_kit/` en ese proyecto. Después, en `project.godot`, autoload **antes** del glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

Detalle: `addons/mp_kit/README.md` y skill `godot-mp-kit`.

## Zip

```bash
./pack.sh    # dist/godot-studio-skills.zip  (skills + addons + instalador)
unzip dist/godot-studio-skills.zip
cd godot-studio-skills
./install.sh
./install.sh --addon /path/to/godot-project
```

## Layout

```
addons/mp_kit/                 # plugin Godot (canónico)
skills/
  godot-layered-architecture/
  godot-composition-first/
  godot-mp-kit/
commands/                      # /create-prd, /generate-rfcs, /implement-rfc, …
install.sh                     # skills, commands y/o --addon
```

Cómo crece el framework: extraer a `addons/` o `skills/` cuando algo se reusa. No copiar un FX o un tracker de puntaje “por las dudas”.
