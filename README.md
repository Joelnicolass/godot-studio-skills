# Godot studio kit

Un estudio chico para **Cursor + Godot 4**: el chat no “hace el juego”, **orquesta**. Pregunta, escribe PRD/RFC, y reparte plan / código / review a subagentes. El resultado no es un `World.gd` de mil líneas: es una **base chica, jugable y clara**, que un humano (o otra IA) puede seguir desde el inspector.

Repo: https://github.com/Joelnicolass/godot-studio-skills

Dos ramas principales: `main` (inglés) y `release/spanish` (español). **Nunca** se les pushea trabajo directo. Orden: un par RC — `rc/vX.Y.Z` desde `main` y `rc/vX.Y.Z-spanish` desde `release/spanish` — y recién merge a las principales cuando la RC esté aceptada. Un segundo candidato: `rc/vX.Y.Z-rc.2`.

## Por qué existe

Sin este kit, un agente suele:

- asumir Clean Architecture o un género (wrap, CRT, plasma…)
- mezclar puntaje, spawn, FX y red en un solo script
- implementar el producto entero en un turno, sin PRD ni RFC

Con el kit:

- **vos** elegís Clean o estándar Godot **antes** de scaffoldear
- **vos** elegís si hay multiplayer y de qué tipo (sin MP · local/WiFi · online)
- cada feature es escena + `@export` + Resource `.tres`, no un `match kind`
- un RFC a la vez, con **árbol de archivos** aprobado, review, playtest y pase visual si los pedís
- MpKit aparte del gameplay; notas entre chats en Engram o `.studio/MEMORY.md` si hace falta
- el juego vive en **otro** repo; acá hay skills, commands, agentes y addons (MpKit, FsmKit, PlatKit). AgentKit / playtester: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)

| Pieza | Dónde | Qué es |
|-------|--------|--------|
| Orquestador | `skills/godot-studio-workflow/` | El agente del chat: entrevista + `/implement-feature` (PRD/RFC opcionales) |
| Cómo escribir Godot | `skills/` | Capas, composición, MpKit, FSM, plataformas 2D, juicy, visual, memoria, tests |
| Subagentes | `agents/` | Tech lead, developer, reviewer; tester y visual opcionales. Playtester: módulo playtest |
| Commands | `commands/` | `/implement-feature`, `/add-juicy`, `/add-state-machine`, `/add-platformer-2d`, `/create-prd`, … |
| MpKit | `addons/mp_kit/` | Listen o dedicated, nodos de replicación, túnel Dictionary. **Cero** gameplay. |
| AgentKit | [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) | CLI de agentes + harness. Este kit lo instala; no se mantiene acá. |
| FsmKit | `addons/fsm_kit/` | `FsmMachine` + `FsmState`. Sin autoload. |
| PlatKit | `addons/plat_kit/` | Motor 2D: coyote, buffer, apex, corner, lift. Sin niveles ni puntaje. |

Qué **no** entra acá: puntaje, copy, escenas de un título, `GameSession`, `SceneDirector`. Eso es glue del juego.

## Arquitectura del orquestador

El chat principal habla con vos. No implementa el título solo. Carga skills Godot, corre commands de producto, e invoca **un rol a la vez**.

```mermaid
flowchart TB
  you[Vos]
  orch[Chat principal — orquestador]

  you <--> orch

  subgraph kit [Este framework]
    skills[Skills Godot]
    cmds[Commands PRD / RFC]
    agents[Subagentes]
    mpkit[MpKit addon]
    fsmkit[FsmKit addon]
    platkit[PlatKit addon]
  end

  subgraph playtest [godot-studio-playtest]
    agentkit[AgentKit addon]
  end

  subgraph game [Tu proyecto Godot]
    arts[PRD FEATURES RULES VISUAL RFCs]
    code[Escenas Resources glue]
  end

  orch --> skills
  orch --> cmds
  cmds --> arts
  orch --> agents
  agents --> code
  mpkit -.-> code
  agentkit -.-> code
  fsmkit -.-> code
  platkit -.-> code
```

Roles (`Task` → `subagent_type`):

| Rol | Subagente | Cuándo |
|-----|-----------|--------|
| Tech lead | `studio-tech-lead` | Plan de **un** RFC **con árbol**, sin código |
| Developer | `studio-developer` | Implementa ese plan |
| Reviewer | `studio-reviewer` | Después del código (un pase) |
| Tester | `studio-tester` | Solo si pedís tests o RULES los exige |
| Playtester | `studio-playtester` | Solo si aceptás jugar el build (módulo [playtest](https://github.com/Joelnicolass/godot-studio-playtest)) |
| Visual | `studio-visual` | Solo si pedís pase UI; hace falta `VISUAL.md` o refs |

Los subagentes **no** ven este chat. El prompt les pasa repo, RFC, estilo de arquitectura, y que lean los artefactos.

## Arquitecturas Godot (siempre se pregunta)

Hay **dos** estilos válidos. El agente no asume Clean. En ambos mandan composición, editor y Resources.

```mermaid
flowchart TB
  ask{¿Clean o estándar?}

  ask -->|Clean| clean[features → core → domain]
  ask -->|Estándar| std[escenas + scripts juntos]

  clean --> feat[features: nodos, física, RPC]
  feat --> core[core: sesión, eventos, director]
  core --> domain[domain: RefCounted, testeable]

  std --> scenes[scenes/ junto al .gd]
  scenes --> match[nodo Match en el mundo]

  clean --> shared[Composición]
  std --> shared

  shared --> packed[Packed scenes + @export]
  packed --> tres[Tipos = Resource .tres]
  tres --> f6[Cada escena corre con F6]
```

| Estilo | Forma | Estado de partida |
|--------|--------|-------------------|
| **Clean** | `src/domain` + `core` + `features` | `GameSession` autoload **solo** si sobrevive el cambio de escena |
| **Estándar** | Escena + script juntos; sin `src/domain/` | Nodo `Match` hijo del mundo |

Dato de tipo → Resource. Helpers puros → `class_name` + `static func`. Comportamiento de actor → nodo hijo. Autoload solo para servicios globales (MpKit **si hay MP**, bus de eventos).

## Multiplayer (siempre se pregunta)

No copies `addons/mp_kit` “por las dudas”. Preguntá el tipo **antes** de RPCs o del addon.

```mermaid
flowchart TB
  mp{¿Qué multiplayer?}

  mp -->|Sin MP| none[No MpKit, no RPCs]
  mp -->|Local / WiFi| lan[MpKit.host listen-server]
  mp -->|Online| net[MpKit.host_dedicated + clientes / VPS]
```

| Tipo | MpKit |
|------|--------|
| **Sin multiplayer** | No se instala |
| **Local / WiFi** | `host()` — el proceso host es un jugador |
| **Online** (internet / VPS) | `host_dedicated()` — mismo proyecto, peer 1 no es jugador. Desarrollá dedicated + clientes; la VPS es el mismo binario |

Tests: skill `godot-testing` (GUT / GdUnit4) **solo** si los pedís.

## Flujo general de desarrollo

De la idea a una base **jugable**. **Iterar gana a un PRD con todo definido.** El camino corto es `/implement-feature`. PRD/RFC siguen siendo opcionales.

```mermaid
flowchart TD
  idea[Idea del juego] --> arch[Elegir Clean o estándar]
  idea --> mp[Elegir tipo de MP]
  arch --> slice["/implement-feature — slice jugable"]
  mp --> slice
  slice --> plan[studio-tech-lead: plan + árbol]
  plan --> ok{¿OK tuyo?}
  ok -->|no| plan
  ok -->|sí| dev[studio-developer]
  dev --> rev[studio-reviewer]
  rev --> play{¿Playtest?}
  play -->|sí| pt[studio-playtester]
  play -->|no| more
  pt --> more{¿Otra feature?}
  more -->|sí| slice
  more -->|no| done[Base chica, jugable, escalable]
  slice -.-> prd["/create-prd opcional — GDD corto"]
```

En un chat nuevo, con el kit instalado, pedí el juego o **una feature**. El orquestador corre `/implement-feature` **sin** exigir un GDD completo. Playtest y visual: el orquestador **pregunta**. Tester GUT solo si los pedís. Un RFC grande: `/implement-rfc`. Alcance a mitad de un RFC: `/manage-changes`. Dónde estamos: `/workflow-status`.

Listo cuando: el slice se juega; cada feature es escena / componente / `.tres`; un humano abre el inspector y entiende.

## Prioridades (siempre)

- arquitectura fácil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composición
- siempre tienen prioridad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componentes

En **estándar**, “capas” no significa carpetas `domain/core/features`. Significa scripts chicos y composición.

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

## Shaders, sprites 2D y 3D

No inventar FX ni arte de memoria.

- Shaders: [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) primero; [Shadertoy](https://www.shadertoy.com) si hay que portar. Un pass = una packed scene.
- Sprites 2D: **preguntá** si querés MCP Aseprite / crear sprites, y pedí **referencias**. Animación: skill `godot-animation`. Feel jugoso: `/add-juicy` + skill `godot-juicy`. Sin OK: placeholder.
- **3D**: **preguntá** si querés el MCP de [Blender](https://www.blender.org/lab/mcp-server/). Si sí: instalalo (Blender 5.1 + add-on Lab + server en Cursor), pedí referencias, exportá `.glb` al juego. Sin OK: placeholder. Detalle: `skills/godot-composition-first/assets.md`.

## Instalar MpKit en un proyecto Godot

```bash
./install.sh --addon /path/to/godot-project
```

Habilitá el plugin **MpKit** (autoload + Tools). CI/headless:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

Hay una demo lista en [`example/`](example/README.md) (1P, LAN, dedicated, mundos 2D y 3D con placeholders, flujo PRD→RFC).

Snippets Cursor/VS Code: `.vscode/mpkit.code-snippets` (el instalador los copia). Editor: `skills/godot-mp-kit/editor.md`. Online / VPS: `skills/godot-mp-kit/dedicated.md`.

## Instalar AgentKit (módulo aparte)

AgentKit y el playtester viven en [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest). Este kit **no** copia el addon; `./install.sh` clona o usa un checkout `../godot-studio-playtest` y corre el instalador de allá.

```bash
./install.sh --addon /path/to/godot-project agent_kit
# equivalente:
git clone https://github.com/Joelnicolass/godot-studio-playtest.git
cd godot-studio-playtest && ./install.sh --addon /path/to/godot-project
```

Habilitá el plugin **AgentKit**. JSON/harness en `res://agent/` del juego. Detalle: README de ese repo. Editor de cables: `experimental/agent-flow-editor/` **allá**, no acá.

## FsmKit / PlatKit

```bash
./install.sh --addon /path/to/godot-project fsm_kit
./install.sh --addon /path/to/godot-project plat_kit
```

Habilitá **FsmKit** / **PlatKit**. Commands: `/add-state-machine`, `/add-platformer-2d`. PlatKit no es un clon de Celeste: dash/stamina quedan en el juego.

## Layout

```
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
