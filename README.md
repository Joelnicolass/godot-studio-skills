# Godot studio skills (Cursor)

Skills de agente para armar **otro** juego Godot 4 con la misma base: capas limpias, composición, inspector primero, componentes reutilizables, y multiplayer host-authoritative con MpKit.

| Skill | Qué cubre |
|-------|-----------|
| `godot-layered-architecture` | `features → core → domain`, sesión, eventos, cómo agregar features |
| `godot-composition-first` | nodos hijos, `@export`, editor, `shared/` |
| `godot-mp-kit` | addon `addons/mp_kit`, glue, handshake, `submit_*` |

El código de ejemplo vive en el juego (carpeta `addons/mp_kit` del proyecto Godot). Este repo solo reparte las skills.

## Instalar (local, sin GitHub)

Desde este directorio:

```bash
chmod +x install.sh uninstall.sh pack.sh
./install.sh          # ~/.cursor/skills/  (todos tus proyectos Cursor)
./install.sh --project   # ./.cursor/skills/ del cwd
```

O con el zip:

```bash
unzip godot-studio-skills.zip
cd godot-studio-skills
./install.sh
```

Generar un zip nuevo:

```bash
./pack.sh    # dist/godot-studio-skills.zip
```

Abrí un **chat nuevo** en Cursor después de instalar.

## Instalar desde GitHub

```bash
npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y
```

Repo: https://github.com/Joelnicolass/godot-studio-skills

Layout que descubre `npx skills add`:

```
skills/
  godot-layered-architecture/SKILL.md
  godot-composition-first/SKILL.md
  godot-mp-kit/SKILL.md
```

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes
