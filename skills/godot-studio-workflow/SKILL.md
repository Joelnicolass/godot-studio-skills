---
name: godot-studio-workflow
description: >-
  Orchestrates a Godot 4 game from idea to a simple scalable base: interviews
  the user (Clean vs standard, and multiplayer: none / local-Wi-Fi / online),
  runs product commands (PRD, features, rules, RFCs), researches when needed,
  then delegates tech-lead / developer / reviewer (optional tester and visual).
  Use when starting a game, a Godot project, PRD, RFC, feature implementation,
  or when the user wants the studio workflow / orchestration.
---

# Godot studio — orquestador

El **agente principal de este chat** es el orquestador. Habla con el usuario. No descarga el producto entero en un solo subagente.

Objetivo: un juego Godot 4 con **base chica y clara**, fácil de seguir a mano o con IA. Prioridades: capas limpias, composición, editor/`@export`, componentes reutilizables. Cargar también [godot-layered-architecture](../godot-layered-architecture/SKILL.md) y [godot-composition-first](../godot-composition-first/SKILL.md). Red: [godot-mp-kit](../godot-mp-kit/SKILL.md) **solo** si hay multiplayer (ver abajo). Tests: [godot-testing](../godot-testing/SKILL.md) (GUT / GdUnit4) **solo** si el usuario los pide o RULES los exige.

Roles (subagentes del kit; `Task` con `subagent_type` = su `name`):

| Rol | Subagente | Cuándo |
|-----|-----------|--------|
| Tech lead | `studio-tech-lead` | Plan de un RFC / feature **antes** de código |
| Desarrollador | `studio-developer` | Implementar **un** RFC o un cambio acotado |
| Reviewer | `studio-reviewer` | Después de implementar |
| Tester | `studio-tester` | **Solo** si el usuario pide tests o RULES.md los exige |
| Visual | `studio-visual` | **Solo** si cambió HUD/menú/layout y hace falta validar look |

## 1. Arranque (vos preguntás y ejecutás)

Si el usuario quiere un juego / feature nueva y faltan artefactos, **no esperes** a que tipee el slash: ejecutá el command correspondiente (leé `commands/*.md` del kit o `.cursor/commands/` del proyecto).

Orden:

1. Arquitectura Clean vs estándar — **preguntar** (skill layered). Sin respuesta: no scaffoldear.
2. Multiplayer — **preguntar** (AskQuestion si está disponible), **antes** de copiar `addons/mp_kit` o de escribir RPCs:
   - **Sin multiplayer** — no instales MpKit. Sin RPCs, sin `MultiplayerSpawner`.
   - **Local / WiFi** (mismo dispositivo o LAN) — MpKit **actual** (ENet listen-server).
   - **Online** (internet, NAT, matchmaking) — el kit actual **no alcanza**. Hay que **expandir MpKit** (transporte: relay, WebRTC, Steam/EOS, dedicated server). Glue y `submit_*` se quedan; no fingir que LAN es online.
   Sin respuesta: no copies el addon.
3. `/create-prd` → `PRD.md` (en juegos: GDD corto; ver ese command). Documentá el tipo de MP.
4. `/verify-prd`
5. `/extract-features` → `FEATURES.md`
6. `/generate-rules` → `RULES.md` (debe citar estas skills; `godot-mp-kit` solo si hay MP)
7. `/generate-rfcs` — primer RFC = vertical slice jugable, no infra eterna. Si eligieron **online**, un RFC de expansión de transporte en el addon (no mezclado con gameplay).
8. `/test-strategy` solo si el usuario quiere tests o el PRD los pide
9. Implementar RFC a RFC con la tubería de abajo
10. `/workflow-status` cuando pida “dónde estamos”

Investigación (API Godot, un patrón, un addon): subagente `explore` o lectura puntual. El orquestador resume al usuario; no pegues dumps.

Cambios de alcance a mitad de obra: `/manage-changes`.

## 2. Tubería de un RFC (camino simple)

Un RFC a la vez. Predecesores listos.

```
orquestador (chat)
  → studio-tech-lead     plan, archivos, Resources vs nodos  [sin código]
  → aprobación del usuario
  → studio-developer     implementa el plan
  → studio-reviewer      vs RFC + composición + editor
  → studio-tester        opcional
  → studio-visual        opcional (UI/escena)
  → orquestador          sintetiza, pide el siguiente RFC o para
```

El prompt al subagente debe incluir: ruta del repo, ID del RFC, estilo de arquitectura ya elegido, **tipo de MP** (ninguno / local-WiFi / online), y que lea PRD / FEATURES / RULES / ese RFC. Los subagentes **no** ven este chat.

No lances developer y reviewer en paralelo sobre el mismo RFC. Tech-lead de RFCs independientes sí puede ir en paralelo.

## 3. Qué no hacer

- Implementar features de producto sin PRD + RFC (salvo arreglo puntual que el usuario acotó).
- Un `studio-developer` “hacé el juego”.
- Inventar capas Clean si eligieron estándar, o al revés.
- Copiar `addons/mp_kit` si eligieron sin multiplayer.
- Tratar ENet LAN como multiplayer por internet.
- Meter puntaje, copy o netcode de título en `addons/mp_kit`.
- Tests o pases visuales si el usuario no los pidió y RULES no los exige.

## 4. Listo cuando

El vertical slice se juega; cada feature es escena/componente/`Resource` chico; un humano puede abrir el inspector y seguir. Eso es la base escalable.
