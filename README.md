# Godot studio kit

Framework chico (y a propósito) para juegos Godot 4: **skills de Cursor** + **addons Godot**. Se agranda de a una pieza reusable. El juego (dominio, glue, escenas) no vive acá.

Repo: https://github.com/Joelnicolass/godot-studio-skills

| Pieza | Dónde | Qué es |
|-------|--------|--------|
| Capas / composición / MP | `skills/` | Instrucciones para el agente |
| MpKit | `addons/mp_kit/` | Plugin Godot: transporte, slots, RPCs de sesión. Cero gameplay |

Qué **no** entra en este repo: puntaje, naves, CRT, copy, `GameSession`, `SceneDirector`. Eso es glue del título.

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

## Instalar skills (Cursor)

```bash
./install.sh                 # ~/.cursor/skills/  (todos tus proyectos)
./install.sh --project       # ./.cursor/skills/ del cwd
```

Desde GitHub:

```bash
npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y
```

`npx skills` solo copia `skills/`. El addon Godot va aparte (abajo).

Abrí un **chat nuevo** en Cursor después de instalar.

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
install.sh                     # skills y/o --addon
```

Cómo crece el framework: extraer a `addons/` o `skills/` cuando algo se reusa. No copiar un FX o un tracker de puntaje “por las dudas”.
