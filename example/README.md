# MpKit Example

Demo mínima del [Godot studio kit](../README.md): **no es un juego**. Enseña MpKit (1P, listen-server, dedicated), composición, Resources `.tres` y el flujo de producto (PRD → FEATURES → RULES → RFCs → código).

Arquitectura: **estándar Godot** (`scenes/` + script junto a la escena). Arte: placeholders. UI en español en esta rama.

## Abrir

Godot **4.7**. Abrí la carpeta `example/` como proyecto.

Si el addon falta o se desactualizó, desde la raíz del studio kit:

```bash
./install.sh --addon-only example
```

El plugin **MpKit** ya está enabled y el autoload `MpKit` va **antes** de `NetGlue`.

## Jugar

| Modo | Cómo |
|------|------|
| **1P** | F5 → Jugar solo. Toggle 2D/3D. WASD/flechas, **E** emote. |
| **LAN** | Instancia A: Host LAN (aparece en **Salas LAN**). Instancia B: click en la sala o Unirse `127.0.0.1`. Debug → Run Multiple Instances. |
| **Dedicated** | Ver abajo. El servidor **no** es un jugador. |

F6: `scenes/actors/pawn_2d.tscn`, `pawn_3d.tscn`, `scenes/world/match_2d.tscn`, `match_3d.tscn`.

## Dedicated (mismo proyecto)

```bash
godot --headless --path example -- --dedicated
# opcional: --world=3d --mp-port=7777
```

Después, un cliente editor: Unirse `127.0.0.1`.

`--headless` **solo** no es dedicated (GUT/CI también van headless). Hace falta `-- --dedicated` o un export Dedicated Server.

## Qué mirar

| Pieza | Dónde | Rol |
|-------|--------|-----|
| Transporte | `addons/mp_kit/` | ENet, slots, túnel. Cero gameplay. |
| Glue | `glue/net_glue.gd` | `extends MpFlow`: catálogo `2d`/`3d` + emote |
| Copy UI | `glue/demo_copy.gd` | Idioma del producto |
| Match | `scenes/world/demo_match.gd` | Snapshot `elapsed` (no spawn) |
| Spawn | `MpSlotSpawner` en `match_2d` / `match_3d` | Un pawn por slot |
| Pawns | `scenes/actors/` | `submit_move` / `apply_move`, `MpReplicate`, pipe |
| Looks | `resources/looks/*.tres` | Tint/badge/speed — no `if kind` |
| Producto | `PRD.md`, `FEATURES.md`, `RULES.md`, `RFCs/` | Flujo del estudio |

## Flujo de producto

Este folder **es** el resultado de `/create-prd` → `/verify-prd` → `/extract-features` → `/generate-rules` → `/generate-rfcs` → `/implement-rfc` 001–004 → `/review-rfc`. Estado: [`WORKFLOW-STATUS.md`](WORKFLOW-STATUS.md) y `reviews/`.

## No está

Puntaje, vidas, Steam, predicción, arte de producción, tests GUT. Eso no va en el kit ni en esta guía.
