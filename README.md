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

## Instalar cuando el repo esté en GitHub

El CLI oficial de skills espera un `OWNER/REPO` público o al que tengas acceso:

```bash
npx skills add OWNER/godot-studio-skills -g -a cursor -y
```

Hasta no existir el remoto, `OWNER` es un placeholder. Copiá `publish.env.example` → `publish.env` y reemplazá `OWNER`.

## Publicar (placeholder)

En esta máquina no hay `gh`. Cuando tengas GitHub:

1. Creá un repo vacío llamado `godot-studio-skills` (o el nombre que elijas).
2. En este directorio:

```bash
git init -b main
git add .
git commit -m "Add Godot Cursor skills pack (architecture, composition, MpKit)."
git remote add origin git@github.com:OWNER/godot-studio-skills.git
git push -u origin main
```

3. Sustituí `OWNER` en este README y en el comando `npx skills add`.

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
