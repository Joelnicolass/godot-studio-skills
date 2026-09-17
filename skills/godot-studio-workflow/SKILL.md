---
name: godot-studio-workflow
description: >-
  Orchestrates a Godot 4 game from idea to a simple scalable base: interviews
  the user (Clean vs standard, multiplayer type, 2D/3D, Aseprite/Blender MCP),
  runs product commands (optional short GDD, features, rules, RFCs), iterates
  with /implement-feature, then delegates tech-lead / developer / reviewer
  (optional tester, playtester and visual). Use when starting a game, a Godot
  project, implementing a feature, PRD, RFC, or when the user wants the studio
  workflow / orchestration.
---

# Godot studio — orquestador

El **agente principal de este chat** es el orquestador. Habla con el usuario. No descarga el producto entero en un solo subagente.

Cargar: [spec-loop.md](spec-loop.md), [compact-rules.md](compact-rules.md), [file-tree.md](file-tree.md), [godot-layered-architecture](../godot-layered-architecture/SKILL.md), [godot-composition-first](../godot-composition-first/SKILL.md). Memoria entre chats: [godot-studio-memory](../godot-studio-memory/SKILL.md). Red: [godot-mp-kit](../godot-mp-kit/SKILL.md) **solo** si hay multiplayer. Capturas / flows de agente: [godot-agent-kit](../godot-agent-kit/SKILL.md) si el addon está. Tests: [godot-testing](../godot-testing/SKILL.md) **solo** si el usuario los pide o RULES los exige. Feel jugoso: [godot-juicy](../godot-juicy/SKILL.md) + `/add-juicy`. FSM: [godot-fsm](../godot-fsm/SKILL.md) + `/add-state-machine`. Plataformas 2D: [godot-platformer-2d](../godot-platformer-2d/SKILL.md) + `/add-platformer-2d`.

Objetivo: un juego Godot 4 con **base chica y clara**. Prioridades: capas limpias, composición, editor/`@export`, componentes reutilizables.

Roles (`Task` con `subagent_type` = su `name`):

| Rol | Subagente | Cuándo |
|-----|-----------|--------|
| Tech lead | `studio-tech-lead` | Plan de un RFC / feature **antes** de código; **incluye árbol** |
| Desarrollador | `studio-developer` | Implementar **un** RFC o un cambio acotado |
| Reviewer | `studio-reviewer` | Después de implementar (un pase) |
| Tester | `studio-tester` | **Solo** si el usuario pide tests o RULES.md los exige |
| Playtester | `studio-playtester` | **Solo** si el usuario acepta jugar el build post-iteración |
| Visual | `studio-visual` | **Solo** si el usuario quiere pase UI; exige `VISUAL.md` / refs |

Cada `Task` lleva el bloque de [compact-rules.md](compact-rules.md). Los subagentes **no** ven este chat.

Al lanzar `studio-playtester` con AgentKit: el prompt debe ordenar leer [harness.md](../godot-agent-kit/harness.md) **antes** de escribir un `.gd`. Al volver: si el diff del playtest tocó `src/` / glue (salvo API de producto con caller de juego, no el flow), **FAIL de proceso** — pedí revert, no lo presentes como playtest OK.

Un typo, un `@export` o un bug con repro y 1–3 archivos: **este chat**, sin RFC nuevo. Feature nueva: `/implement-feature` (FEATURES crece). RFC solo si el corte es grande o el usuario pide contrato. Alcance que se mueve a mitad de un RFC: `/manage-changes`.

## 1. Arranque (vos preguntás y ejecutás)

Si el usuario quiere un juego / feature nueva, **no esperes** a que tipee el slash: ejecutá el command correspondiente.

**Iterar gana a un PRD con todo definido.** Un slice jugable esta semana vale más que un GDD de 20 páginas. `/create-prd` es opcional y **corto**; no entrevistas el título entero antes de código.

Si el repo ya tiene PRD/RULES, leelos y `/workflow-status` si hace falta; no regeneres artefactos.

Orden para un **juego nuevo**:

1. Arquitectura Clean vs estándar — **preguntar** (skill layered). Sin respuesta: no scaffoldear.
2. Multiplayer — **preguntar** (AskQuestion si está disponible), **antes** de copiar `addons/mp_kit` o de escribir RPCs:
   - **Sin multiplayer** — no instales MpKit. Sin RPCs, sin `MultiplayerSpawner`.
   - **Local / WiFi** (mismo dispositivo o LAN) — `MpKit.host()` listen-server (el host es jugador).
   - **Online** (internet / VPS) — **dedicated server** en el mismo proyecto: `MpKit.host_dedicated()`, clientes `join(ip)`. Desarrollá dedicated + clientes desde el día uno. Steam/WebRTC/matchmaking solo si el producto los pide después. No fingir que un listen detrás de NAT es online.
   Sin respuesta: no copies el addon.
3. 2D / 3D — **preguntar** (o ambos).
   - **2D**: sprites vía Aseprite MCP **solo** si el usuario quiere (referencias). Skill [godot-animation](../godot-animation/SKILL.md) (12 principios; Tween o AnimationPlayer según el clip).
   - **3D**: **preguntá** si quiere el MCP de Blender ([docs oficiales](https://www.blender.org/lab/mcp-server/)). Si sí: instalalo, pedí referencias, exportá `.glb` al juego. Si no: placeholder 3D. Guía: [assets.md](../godot-composition-first/assets.md).
4. Slice vertical: `/implement-feature` (o un RFC-001 si piden contrato). Pilares + loop + una escena. No hace falta FEATURES de todo el juego.
5. Si quieren un GDD escrito: `/create-prd` → `PRD.md` **corto y vivo** (solo el slice + no-goals). No definas sistemas futuros.
6. Si ya hay estilo o refs: `/create-visual-guide` → `VISUAL.md`. Si no, **preguntá** antes de cualquier pase visual.
7. RULES.md cuando el stack ya se eligió (`/generate-rules` o unas viñetas a mano). `godot-mp-kit` solo si hay MP.
8. Features siguientes: otra vez `/implement-feature`. `/generate-rfcs` solo si quieren un backlog de contratos.
9. `/test-strategy` solo si el usuario quiere tests o el PRD los pide
10. `/workflow-status` cuando pida “dónde estamos”

Investigación (API Godot, un patrón, un addon, un shader): subagente `explore` o lectura puntual (Godot Shaders, Shadertoy). Sprites 2D: **preguntá** si quiere MCP/arte y pedí referencias. Si es **3D**: **preguntá** e instalá el MCP de Blender solo con OK + referencias. El orquestador resume al usuario; no pegues dumps.

Cambios de alcance a mitad de un RFC grande: `/manage-changes`. Feature nueva chica: `/implement-feature`.

## 2. Tubería de una feature (o de un RFC)

Una feature / un RFC a la vez. Predecesores listos.

```
orquestador (chat)
  → studio-tech-lead     plan + árbol + mapa de responsabilidades  [sin código]
  → el usuario ve el árbol (¿más/menos piezas?) y da OK
  → studio-developer     implementa el plan
  → studio-reviewer      un pase; una corrección si hay bloqueantes
  → ¿playtest?           preguntar → studio-playtester (Godot, no GUT)
  → ¿pase visual?        preguntar; sin VISUAL.md/refs, pedirlos primero
  → orquestador          sintetiza; anotá gotchas en memoria si hace falta
```

El prompt al subagente incluye: ruta del repo, id de feature o RFC, estilo de arquitectura, **tipo de MP**, compact rules, y que lea RULES / VISUAL / FEATURES / el RFC si existe.

No lances developer y reviewer en paralelo sobre el mismo corte. Tech-lead de features independientes sí puede ir en paralelo.

Sin [árbol](file-tree.md) no hay “OK, implementá”.

## 3. Qué no hacer

- Definir el juego entero en un PRD antes de un slice jugable.
- Un `studio-developer` “hacé el juego”.
- Regenerar PRD / FEATURES / RFCs cuando pedís **una** feature (`/implement-feature`).
- Inventar capas Clean si eligieron estándar, o al revés.
- Copiar `addons/mp_kit` si eligieron sin multiplayer.
- Tratar un listen-server detrás de NAT como multiplayer por internet.
- Meter puntaje, copy o netcode de título en `addons/mp_kit`.
- Tests, playtest o pases visuales sin preguntar (salvo RULES que exija tests).
- Pase visual sin estilo/referencias: no inventar look.
- Instalar MCP (Aseprite, Blender, Engram) o crear arte sin preguntar.
- Feel hardcodeado. Elegí Tween o `AnimationPlayer` por clip, no por costumbre. Feel jugoso: `/add-juicy`, no un `World.gd` de partículas.
- `enum` + `match` de estados en el actor: `/add-state-machine`.
- Platformer sin coyote/buffer: `/add-platformer-2d`, no un `is_on_floor()` pelado.

## 4. Listo cuando

El vertical slice se juega; cada feature es escena/componente/`Resource` chico; un humano puede abrir el inspector y seguir. Eso es la base escalable.
