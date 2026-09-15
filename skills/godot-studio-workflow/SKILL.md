---
name: godot-studio-workflow
description: >-
  Orchestrates a Godot 4 game from idea to a simple scalable base: interviews
  the user (Clean vs standard, multiplayer type, 2D/3D, Aseprite/Blender MCP),
  runs product commands (PRD, features, rules, RFCs, visual guide), researches
  when needed, then delegates tech-lead / developer / reviewer (optional
  tester, playtester and visual). Use when starting a game, a Godot project,
  PRD, RFC, feature implementation, or when the user wants the studio
  workflow / orchestration.
---

# Godot studio — orquestador

El **agente principal de este chat** es el orquestador. Habla con el usuario. No descarga el producto entero en un solo subagente.

Cargar: [spec-loop.md](spec-loop.md), [compact-rules.md](compact-rules.md), [file-tree.md](file-tree.md), [godot-layered-architecture](../godot-layered-architecture/SKILL.md), [godot-composition-first](../godot-composition-first/SKILL.md). Memoria entre chats: [godot-studio-memory](../godot-studio-memory/SKILL.md). Red: [godot-mp-kit](../godot-mp-kit/SKILL.md) **solo** si hay multiplayer. Capturas / flows de agente: [godot-agent-kit](../godot-agent-kit/SKILL.md) si el addon está. Tests: [godot-testing](../godot-testing/SKILL.md) **solo** si el usuario los pide o RULES los exige.

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

Un typo, un `@export` o un bug con repro y 1–3 archivos: **este chat**, sin RFC nuevo. Feature nueva o alcance que se mueve: spec (PRD/RFC) o `/manage-changes`.

## 1. Arranque (vos preguntás y ejecutás)

Si el usuario quiere un juego / feature nueva y faltan artefactos, **no esperes** a que tipee el slash: ejecutá el command correspondiente (leé `commands/*.md` del kit o `.cursor/commands/` del proyecto).

Si el repo ya tiene PRD/RULES, leelos y `/workflow-status` si hace falta; no regeneres artefactos.

Orden para un **juego nuevo**:

1. Arquitectura Clean vs estándar — **preguntar** (skill layered). Sin respuesta: no scaffoldear.
2. Multiplayer — **preguntar** (AskQuestion si está disponible), **antes** de copiar `addons/mp_kit` o de escribir RPCs:
   - **Sin multiplayer** — no instales MpKit. Sin RPCs, sin `MultiplayerSpawner`.
   - **Local / WiFi** (mismo dispositivo o LAN) — `MpKit.host()` listen-server (el host es jugador).
   - **Online** (internet / VPS) — **dedicated server** en el mismo proyecto: `MpKit.host_dedicated()`, clientes `join(ip)`. Desarrollá dedicated + clientes desde el día uno. Steam/WebRTC/matchmaking solo si el producto los pide después. No fingir que un listen detrás de NAT es online.
   Sin respuesta: no copies el addon.
3. 2D / 3D — **preguntar** (o ambos).
   - **2D**: sprites vía Aseprite MCP **solo** si el usuario quiere (referencias). Skill [godot-animation](../godot-animation/SKILL.md).
   - **3D**: **preguntá** si quiere el MCP de Blender ([docs oficiales](https://www.blender.org/lab/mcp-server/)). Si sí: instalalo, pedí referencias, exportá `.glb` al juego. Si no: placeholder 3D. Guía: [assets.md](../godot-composition-first/assets.md).
4. `/create-prd` → `PRD.md` (en juegos: GDD corto; ver ese command). Documentá el tipo de MP y 2D/3D.
5. Si ya hay estilo o refs: `/create-visual-guide` → `VISUAL.md`. Si no, **preguntá** antes de cualquier pase visual.
6. `/verify-prd`
7. `/extract-features` → `FEATURES.md`
8. `/generate-rules` → `RULES.md` (debe citar estas skills; `godot-mp-kit` solo si hay MP)
9. `/generate-rfcs` — primer RFC = vertical slice jugable, no infra eterna. Si eligieron **online**, un RFC de glue dedicated + export VPS (no mezclado con el slice de gameplay; no inventar Steam).
10. `/test-strategy` solo si el usuario quiere tests o el PRD los pide
11. Implementar RFC a RFC con la tubería de abajo
12. `/workflow-status` cuando pida “dónde estamos”

Investigación (API Godot, un patrón, un addon, un shader): subagente `explore` o lectura puntual (Godot Shaders, Shadertoy). Sprites 2D: **preguntá** si quiere MCP/arte y pedí referencias. Si es **3D**: **preguntá** e instalá el MCP de Blender solo con OK + referencias. El orquestador resume al usuario; no pegues dumps.

Cambios de alcance a mitad de obra: `/manage-changes`.

## 2. Tubería de un RFC

Un RFC a la vez. Predecesores listos.

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

El prompt al subagente incluye: ruta del repo, ID del RFC, estilo de arquitectura, **tipo de MP** (ninguno / local-WiFi / online), compact rules, y que lea PRD / FEATURES / RULES / VISUAL / ese RFC.

No lances developer y reviewer en paralelo sobre el mismo RFC. Tech-lead de RFCs independientes sí puede ir en paralelo.

Sin [árbol](file-tree.md) no hay “OK, implementá”.

## 3. Qué no hacer

- Implementar features de producto sin PRD + RFC (salvo el arreglo puntual que el usuario ya acotó).
- Un `studio-developer` “hacé el juego”.
- Inventar capas Clean si eligieron estándar, o al revés.
- Copiar `addons/mp_kit` si eligieron sin multiplayer.
- Tratar un listen-server detrás de NAT como multiplayer por internet.
- Meter puntaje, copy o netcode de título en `addons/mp_kit`.
- Tests, playtest o pases visuales sin preguntar (salvo RULES que exija tests).
- Pase visual sin estilo/referencias: no inventar look.
- Instalar MCP (Aseprite, Blender, Engram) o crear arte sin preguntar.

## 4. Listo cuando

El vertical slice se juega; cada feature es escena/componente/`Resource` chico; un humano puede abrir el inspector y seguir. Eso es la base escalable.
