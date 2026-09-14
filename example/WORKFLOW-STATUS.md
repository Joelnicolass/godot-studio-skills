# Workflow status — MpKit Example

Generado como `/workflow-status`. Tipo: juego Godot (demo). Tests (etapa 6): **omitidos a propósito** (PRD F23 Won't; el usuario no pidió GUT/GdUnit4).

## Tabla de etapas

| # | Etapa | Artefacto | Estado |
|---|-------|-----------|--------|
| 1 | Crear PRD | `PRD.md` | Done |
| 2 | Verificar PRD | `PRD.md` + `PRD-REVIEW.md` | Done |
| 3 | Extraer features | `FEATURES.md` | Done |
| 4 | Generar rules | `RULES.md` | Done |
| 5 | Generar RFCs | `RFCS.md` + `RFCs/` | Done |
| 6 | Estrategia de testing | `TEST-STRATEGY.md` | Missing (N/A — F23) |
| 7 | Implementar RFCs | código en `glue/`, `scenes/`, `resources/` | Done (001–004) |
| 8 | Revisar | `reviews/REVIEW-RFC-00{1,2,3,4}.md` | Done (lectura; runtime Godot unverified en CI de agente) |
| 9 | Change requests | `changes/` | Missing (ninguno abierto) |
| 10 | Este reporte | `WORKFLOW-STATUS.md` | Done |

## Progreso por RFC

```
RFC-001  implemented ✅   reviewed ✅
RFC-002  implemented ✅   reviewed ✅
RFC-003  implemented ✅   reviewed ✅
RFC-004  implemented ✅   reviewed ✅
```

## Código vs criterios (lectura)

| RFC | Evidencia |
|-----|-----------|
| 001 | `boot.tscn` main scene, `play_solo` sin `host()`, pawn 2D + `ActorLook` `.tres`, InputMap |
| 002 | `match_3d.tscn`, `pawn_3d.tscn`, `demo_match.gd` en ambos mundos, toggle 2D/3D |
| 003 | `host_lan` / `join_lan`, `submit_move`, handshake `MpWorldReady`, Leave / `server_lost` |
| 004 | `MpBoot` + `host_dedicated`, canal `emote`, snapshot `elapsed`, `README.md` |

## Inconsistencias

- Los RFC se implementaron en un solo lote (el chat de producto aprobó el alcance entero). El orden topológico 001→004 se respetó en dependencias, no como PRs separados.
- Reviews marcan runtime F5/LAN/dedicated **unverified** si no hay binario `godot` en el agente. Abrí el proyecto en el editor local (cache `.godot/`, class cache OK: `ActorLook`, `DemoMatch`, nodos MpKit).
- Etapa 6 ausente: no es drift; RULES/PRD prohíben inventar tests.

## Siguiente paso

Jugar la demo a mano (no hay otro RFC):

1. Abrir `example/` en Godot 4.7 → F5 → **Jugar solo**.
2. Debug → Run Multiple Instances → Host LAN + Unirse `127.0.0.1`.
3. Opcional dedicated: `godot --headless --path example -- --dedicated`.
