# Godot studio kit

Un estudio chico para **Claude Code o Cursor + Godot 4**: el chat no “hace el juego”, **orquesta**. Pregunta, escribe PRD/RFC, y reparte plan / código / review a subagentes. El resultado no es un `World.gd` de mil líneas: es una **base chica, jugable y clara**, que un humano (o otra IA) puede seguir desde el inspector.

Repo: https://github.com/Joelnicolass/godot-studio-skills — en inglés en `main`, en español en `release/spanish`.

## Por qué existe

Sin este kit, un agente suele:

- Perder el contexto del desarrollo.
- Asumir una arquitectura, o mezclar varias en un mismo desarrollo.
- Crear scripts con muchas responsabilidades: mezclar puntaje, spawn, vfx, etc.
- Implementar el producto entero en un turno, sin PRD ni RFC.
- Saltarse la fase de testeo antes de entregar la implementación.

Con el kit:

- **Vos** elegís Clean o estándar Godot **antes** de scaffoldear. Dandote una estructura clara para el desarrollo.
- **Vos** elegís si hay multiplayer y de qué tipo (sin MP · local/WiFi · online)
- Se prioriza lo simple y predecible: cada feature es escena(s) con sus números en `@export` del nodo que los usa, Resources `.tres` solo para tipos que se comparten, no un `match kind`. Si cambiar un número exige abrir más de 2 archivos, el diseño está mal.
- Código estándar de Godot: patrones probados (señales, bus `Events`, FSM, componentes…), tipado real, `gdformat` / `gdlint`, y GUT + CI si hay tests (skill `godot-code-quality`).
- Un RFC a la vez, con **árbol de archivos** aprobado, review, playtest y pase visual si los pedís
- MpKit aparte del gameplay; notas entre sesiones en Engram o `.studio/MEMORY.md` si hace falta.
- El juego vive en **otro** repo; acá hay skills, commands, agentes y addons (MpKit, FsmKit, PlatKit, RtsKit, PropKit). AgentKit / playtester: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)

| Pieza               | Dónde                                                                          | Qué es                                                                                           |
| ------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Orquestador         | `skills/godot-studio-workflow/`                                                | El agente del chat: entrevista + `/implement-feature` (PRD/RFC opcionales)                       |
| Cómo escribir Godot | `skills/`                                                                      | Capas, composición, calidad de código, MpKit, FSM, plataformas 2D, controles de RTS, props y su navmesh, juicy, materiales, investigar features, visual, memoria, tests y CI |
| Subagentes          | `agents/`                                                                      | Tech lead, developer, reviewer; tester y visual opcionales. Playtester: módulo playtest          |
| Commands            | `commands/`                                                                    | `/implement-feature`, `/add-juicy`, `/add-state-machine`, `/add-platformer-2d`, `/add-rts-controls`, `/add-props`, `/create-prd`, … |
| MpKit               | `addons/mp_kit/`                                                               | Multiplayer con nodos y sin RPCs a mano: el juego en un `.tres` (`MpGame`), el mundo en un nodo (`MpWorld`), los verbos de la partida en `Mp`, más `MpActor`, `MpInput`, `MpState`, `MpMatch`. Predicción, buffers adaptativos, compensación de lag y calidad de red; LAN, dedicated, salas online, partida privada, web, relay para servidores sin IP pública (Railway), deploy a VPS y asistente *Setup game*. **Cero** gameplay. Empezá por `addons/mp_kit/QUICKSTART.md` (paso a paso: `GUIDE.md`); pruebas sin juego en `mpkit_lab/run/all.sh`. |
| AgentKit            | [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) | CLI de agentes + harness. Este kit lo instala; no se mantiene acá.                               |
| FsmKit              | `addons/fsm_kit/`                                                              | `FsmMachine` + `FsmState`. Sin autoload.                                                         |
| PlatKit             | `addons/plat_kit/`                                                             | Motor 2D: coyote, buffer, apex, corner, lift. Sin niveles ni puntaje.                            |
| RtsKit              | `addons/rts_kit/`                                                              | Controles de RTS para 2D y 3D: unidades, selección y grupos, órdenes tipadas en formación, entrada de comandos (panel de comandos y menú radial opcionales), cámaras de RTS. Sin red adentro; sin movimiento ni combate. Empezá por `addons/rts_kit/GUIDE.md` (incluye MpKit); tests en `rtskit_lab/`. |
| PropKit             | `addons/prop_kit/`                                                             | Props para 2D y 3D: scatter sobre cualquier suelo como nodos guardados (grupos, zonas prohibidas, máscaras, variantes), dibujo en lotes (3D) y el navmesh horneado por zonas con los props como obstrucciones baratas, rehorneando solo lo que cambió en hilos de trabajo. Sin red adentro; sin el comportamiento del prop. Empezá por `addons/prop_kit/README.md`; tests en `propkit_lab/`. |

Qué **no** entra acá: puntaje, copy, escenas de un título, `GameSession`, `SceneDirector`. Eso es glue del juego.

## Cómo funciona

El detalle (diagramas del orquestador, roles, Clean vs estándar, tipos de multiplayer, flujo de una iteración, arte/shaders) está en [docs/architecture.md](docs/architecture.md). Diagrama interactivo del flujo: [joelnicolass.github.io/godot-studio-skills](https://joelnicolass.github.io/godot-studio-skills/). En corto: entrevista → `/implement-feature` → un OK sobre el árbol (incluye `res://debug/` si hace falta) → developer → reviewer → playtester sobre esa escena → el orquestador clasifica el FAIL → cierre en `FEATURES.md`. El pase visual se pregunta. El contrato del slice es el `F<n>`, no un RFC obligatorio.

## Instalar (Claude Code o Cursor)

```bash
./install.sh --claude            # ~/.claude/skills, commands, agents
./install.sh                     # ~/.cursor/skills, commands, agents (default)
./install.sh --all               # los dos
./install.sh --claude --project  # ./.claude/ del cwd (sin --claude: ./.cursor/)
```

Desde GitHub:

```bash
npx skills add Joelnicolass/godot-studio-skills -g -a claude-code -y   # o -a cursor
npx skills add Joelnicolass/godot-studio-playtest -g -a claude-code -y
```

`npx skills` solo copia `skills/`. Commands, subagentes y los addons van con `./install.sh` (este instalador también trae el módulo playtest). Desinstalar: `./uninstall.sh` con los mismos flags (`--claude`, `--all`, `--project`).

Abrí una **sesión nueva** después de instalar. En Claude Code, `/agents` lista los `studio-*` y `/` muestra los commands.

### Qué cambia entre Claude Code y Cursor

Los mismos archivos sirven para los dos; el kit no tiene una copia por harness.

| Pieza           | Claude Code                                                                                   | Cursor                                    |
| --------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------- |
| Skills          | `~/.claude/skills/<skill>/SKILL.md`                                                           | `~/.cursor/skills/<skill>/SKILL.md`       |
| Commands        | `~/.claude/commands/*.md` → `/implement-feature`. Usa `description` / `argument-hint`         | `~/.cursor/commands/*.md`                 |
| Subagentes      | `~/.claude/agents/*.md`. Solo lectura con `disallowedTools`; `skills:` precarga las del rol   | `~/.cursor/agents/*.md`. `readonly: true` |
| Lanzar un rol   | Tool `Agent` (`subagent_type`)                                                                | Tool `Task` (`subagent_type`)             |
| Preguntar       | `AskUserQuestion`                                                                             | `AskQuestion`                             |
| MCP (opcional)  | `.mcp.json` en la raíz del juego o `claude mcp add`                                           | `.cursor/mcp.json`                        |
| Reglas del juego | `CLAUDE.md` que importa `@RULES.md` (ver [`example/CLAUDE.md`](example/CLAUDE.md))           | `AGENTS.md` o `.cursor/rules/`            |

En Claude Code los subagentes no le preguntan al usuario ni lanzan otros subagentes: devuelven la duda y el orquestador pregunta. `./install.sh --addon … agent_kit` deja además la regla del workspace en el juego (la escribe el módulo playtest): `.cursor/rules/` para Cursor y, desde playtest v0.3.0, `.claude/rules/` para Claude Code.

## Commands de producto

Camino corto (default):

1. `/implement-feature` — una feature o el slice vertical (árbol → OK → código → review). Crece `FEATURES.md`.
2. `/add-juicy` — feel jugoso (shake, VFX, post, impacto) sobre un evento que ya existe
3. `/add-state-machine` — `FsmMachine` + estados hijos (addon FsmKit)
4. `/add-platformer-2d` — coyote, jump buffer, apex, corner (addon PlatKit)
5. `/add-rts-controls` — unidades, selección, grupos, órdenes en formación, cámara de RTS (addon RtsKit)
6. `/add-props` — props plantados, dibujo en lotes, un navmesh por zonas que ellos cortan (addon PropKit)
7. `/new-mp-feature` — solo scaffold de un actor MpKit
8. `/create-material` — material / textura procedural con [Material Maker](https://github.com/RodZill4/material-maker) → `.tres`
9. `/research-feature` — entender una mecánica de un juego similar (investigación web, y decompilarlo si se puede abrir) antes de implementarla
10. `/workflow-status`

Contrato escrito, si lo pedís:

11. `/create-prd` → `PRD.md` (GDD **corto y vivo**, no el título entero)
12. `/verify-prd` → `PRD-REVIEW.md`
13. `/extract-features` → `FEATURES.md`
14. `/generate-rules` → `RULES.md`
15. `/create-visual-guide` → `VISUAL.md`
16. `/generate-rfcs` → `RFCs/` + `RFCS.md`
17. `/implement-rfc <id>`
18. `/review-rfc <id>`
19. `/manage-changes`
20. `/test-strategy` — opcional

## Instalar addons en un proyecto Godot

```bash
./install.sh --addon /path/to/godot-project            # MpKit
./install.sh --addon /path/to/godot-project fsm_kit    # FsmKit
./install.sh --addon /path/to/godot-project plat_kit   # PlatKit
./install.sh --addon /path/to/godot-project rts_kit    # RtsKit
./install.sh --addon /path/to/godot-project prop_kit   # PropKit
./install.sh --addon /path/to/godot-project agent_kit  # AgentKit (lo trae del repo playtest)
```

Habilitá cada plugin en Proyecto → Plugins. MpKit además necesita el autoload (`MpKit="*res://addons/mp_kit/mp_kit.gd"`); primeros pasos en `addons/mp_kit/QUICKSTART.md`, referencia en `addons/mp_kit/README.md`, editor en `skills/godot-mp-kit/editor.md`, online/VPS en `skills/godot-mp-kit/dedicated.md`. AgentKit vive en [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest): JSON/harness en `res://agent/` del juego; detalle en el README de ese repo. PlatKit no es un clon de Celeste: dash/stamina quedan en el juego. RtsKit manda y el juego actúa: le da a cada unidad su orden y el juego camina y pelea (`addons/rts_kit/README.md`). PropKit planta los props y mantiene barato su navmesh; lo que hace un prop queda en el juego (`addons/prop_kit/README.md`).

Herramientas externas que el flujo **ofrece** cuando hacen falta (nunca las instala sin preguntar): [Material Maker](https://github.com/RodZill4/material-maker) para materiales y texturas procedurales (skill `godot-material-maker`), y un decompilador (gdsdecomp, ILSpy, …) para abrir un juego similar al investigar una mecánica (skill `godot-feature-research`). Igual que los MCP de Aseprite y Blender.

Hay una demo lista en [`example/`](example/README.md) (1P, LAN, dedicated, mundos 2D y 3D con placeholders, flujo PRD→RFC). Snippets VS Code/Cursor: `.vscode/mpkit.code-snippets` (el instalador los copia).

## Layout

```
docs/                          # arquitectura y flujo en detalle
example/                       # demo Godot 4.7 (1P + LAN + dedicated, 2D y 3D)
addons/mp_kit/
addons/fsm_kit/
addons/plat_kit/
addons/rts_kit/
addons/prop_kit/
rtskit_lab/                    # tests y ejemplos de RtsKit, sin juego
propkit_lab/                   # tests y ejemplos de PropKit, sin juego
skills/
  godot-studio-workflow/
  godot-studio-memory/
  godot-layered-architecture/
  godot-composition-first/
  godot-code-quality/
  godot-mp-kit/
  godot-visual-qa/
  godot-testing/
  godot-animation/
  godot-juicy/
  godot-fsm/
  godot-platformer-2d/
  godot-rts-kit/
  godot-prop-kit/
  godot-material-maker/
  godot-feature-research/
agents/                        # studio-tech-lead, studio-developer, …
commands/
install.sh
```

AgentKit, `/agent-kit`, `studio-playtester` y el editor de flow: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest).

Cómo crece el framework: extraer a `addons/` o `skills/` cuando algo se reusa. No copiar un FX o un tracker de puntaje “por las dudas”.

## Licencia

[MIT](LICENSE).
