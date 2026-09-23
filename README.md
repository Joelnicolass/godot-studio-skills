# Godot studio kit

Un estudio chico para **Cursor + Godot 4**: el chat no “hace el juego”, **orquesta**. Pregunta, escribe PRD/RFC, y reparte plan / código / review a subagentes. El resultado no es un `World.gd` de mil líneas: es una **base chica, jugable y clara**, que un humano (o otra IA) puede seguir desde el inspector.

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
- Se prioriza la estructura desacoplada: cada feature es escena(s) con prioridad a los `@export`, Resources `.tres`, no un `match kind`. El editor expone para mayor comodidad.
- Un RFC a la vez, con **árbol de archivos** aprobado, review, playtest y pase visual si los pedís
- MpKit aparte del gameplay; notas entre chats en Engram o `.studio/MEMORY.md` si hace falta.
- El juego vive en **otro** repo; acá hay skills, commands, agentes y addons (MpKit, FsmKit, PlatKit). AgentKit / playtester: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)

| Pieza               | Dónde                                                                          | Qué es                                                                                           |
| ------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Orquestador         | `skills/godot-studio-workflow/`                                                | El agente del chat: entrevista + `/implement-feature` (PRD/RFC opcionales)                       |
| Cómo escribir Godot | `skills/`                                                                      | Capas, composición, MpKit, FSM, plataformas 2D, juicy, visual, memoria, tests                    |
| Subagentes          | `agents/`                                                                      | Tech lead, developer, reviewer; tester y visual opcionales. Playtester: módulo playtest          |
| Commands            | `commands/`                                                                    | `/implement-feature`, `/add-juicy`, `/add-state-machine`, `/add-platformer-2d`, `/create-prd`, … |
| MpKit               | `addons/mp_kit/`                                                               | Listen o dedicated, nodos de replicación, túnel Dictionary. **Cero** gameplay.                   |
| AgentKit            | [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) | CLI de agentes + harness. Este kit lo instala; no se mantiene acá.                               |
| FsmKit              | `addons/fsm_kit/`                                                              | `FsmMachine` + `FsmState`. Sin autoload.                                                         |
| PlatKit             | `addons/plat_kit/`                                                             | Motor 2D: coyote, buffer, apex, corner, lift. Sin niveles ni puntaje.                            |

Qué **no** entra acá: puntaje, copy, escenas de un título, `GameSession`, `SceneDirector`. Eso es glue del juego.

## Cómo funciona

El detalle (diagramas del orquestador, roles, Clean vs estándar, tipos de multiplayer, flujo de una iteración, arte/shaders) está en [docs/architecture.md](docs/architecture.md). Diagrama interactivo del flujo: [joelnicolass.github.io/godot-studio-skills](https://joelnicolass.github.io/godot-studio-skills/). En corto: entrevista → `/implement-feature` → un OK sobre el árbol (incluye `res://debug/` si hace falta) → developer → reviewer → playtester sobre esa escena → el orquestador clasifica el FAIL → cierre en `FEATURES.md`. El pase visual se pregunta. El contrato del slice es el `F<n>`, no un RFC obligatorio.

## Instalar (Cursor)

```bash
./install.sh                 # ~/.cursor/skills, commands, agents
./install.sh --project       # ./.cursor/ del cwd
```

Desde GitHub:

```bash
npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y
npx skills add Joelnicolass/godot-studio-playtest -g -a cursor -y
```

`npx skills` solo copia `skills/`. Commands, subagentes y los addons van con `./install.sh` (este instalador también trae el módulo playtest).

Abrí un **chat nuevo** en Cursor después de instalar.

## Commands de producto

Camino corto (default):

1. `/implement-feature` — una feature o el slice vertical (árbol → OK → código → review). Crece `FEATURES.md`.
2. `/add-juicy` — feel jugoso (shake, VFX, post, impacto) sobre un evento que ya existe
3. `/add-state-machine` — `FsmMachine` + estados hijos (addon FsmKit)
4. `/add-platformer-2d` — coyote, jump buffer, apex, corner (addon PlatKit)
5. `/new-mp-feature` — solo scaffold de un actor MpKit
6. `/workflow-status`

Contrato escrito, si lo pedís:

7. `/create-prd` → `PRD.md` (GDD **corto y vivo**, no el título entero)
8. `/verify-prd` → `PRD-REVIEW.md`
9. `/extract-features` → `FEATURES.md`
10. `/generate-rules` → `RULES.md`
11. `/create-visual-guide` → `VISUAL.md`
12. `/generate-rfcs` → `RFCs/` + `RFCS.md`
13. `/implement-rfc <id>`
14. `/review-rfc <id>`
15. `/manage-changes`
16. `/test-strategy` — opcional

## Instalar addons en un proyecto Godot

```bash
./install.sh --addon /path/to/godot-project            # MpKit
./install.sh --addon /path/to/godot-project fsm_kit    # FsmKit
./install.sh --addon /path/to/godot-project plat_kit   # PlatKit
./install.sh --addon /path/to/godot-project agent_kit  # AgentKit (lo trae del repo playtest)
```

Habilitá cada plugin en Proyecto → Plugins. MpKit además necesita el autoload (`MpKit="*res://addons/mp_kit/mp_kit.gd"`); guía completa en `addons/mp_kit/README.md`, editor en `skills/godot-mp-kit/editor.md`, online/VPS en `skills/godot-mp-kit/dedicated.md`. AgentKit vive en [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest): JSON/harness en `res://agent/` del juego; detalle en el README de ese repo. PlatKit no es un clon de Celeste: dash/stamina quedan en el juego.

Hay una demo lista en [`example/`](example/README.md) (1P, LAN, dedicated, mundos 2D y 3D con placeholders, flujo PRD→RFC). Snippets Cursor/VS Code: `.vscode/mpkit.code-snippets` (el instalador los copia).

## Layout

```
docs/                          # arquitectura y flujo en detalle
example/                       # demo Godot 4.7 (1P + LAN + dedicated, 2D y 3D)
addons/mp_kit/
addons/fsm_kit/
addons/plat_kit/
skills/
  godot-studio-workflow/
  godot-studio-memory/
  godot-layered-architecture/
  godot-composition-first/
  godot-mp-kit/
  godot-visual-qa/
  godot-testing/
  godot-animation/
  godot-juicy/
  godot-fsm/
  godot-platformer-2d/
agents/                        # studio-tech-lead, studio-developer, …
commands/
install.sh
```

AgentKit, `/agent-kit`, `studio-playtester` y el editor de flow: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest).

Cómo crece el framework: extraer a `addons/` o `skills/` cuando algo se reusa. No copiar un FX o un tracker de puntaje “por las dudas”.
