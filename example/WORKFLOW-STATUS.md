# Workflow status — MpKit Example

Produced as `/workflow-status`. Type: Godot game (demo). Tests (stage 6): **omitted on purpose** (PRD F23 Won't; no GUT/GdUnit4 requested).

## Stage table

| # | Stage | Artifact | Status |
|---|-------|----------|--------|
| 1 | Create PRD | `PRD.md` | Done |
| 2 | Verify PRD | `PRD.md` + `PRD-REVIEW.md` | Done |
| 3 | Extract features | `FEATURES.md` | Done |
| 4 | Generate rules | `RULES.md` | Done |
| 5 | Generate RFCs | `RFCS.md` + `RFCs/` | Done |
| 6 | Test strategy | `TEST-STRATEGY.md` | Missing (N/A — F23) |
| 7 | Implement RFCs | `glue/`, `scenes/`, `resources/` | Done (001–004) |
| 8 | Review | `reviews/REVIEW-RFC-00{1,2,3,4}.md` | Done (read; runtime unverified in the agent) |
| 9 | Change requests | `changes/` | Missing (none open) |
| 10 | This report | `WORKFLOW-STATUS.md` | Done |

## Per RFC

```
RFC-001  implemented ✅   reviewed ✅
RFC-002  implemented ✅   reviewed ✅
RFC-003  implemented ✅   reviewed ✅
RFC-004  implemented ✅   reviewed ✅
```

## Next step

Play the demo by hand (no further RFC):

1. Open `example/` in Godot 4.7 → F5 → **Play solo**.
2. Debug → Run Multiple Instances → Host LAN + Join `127.0.0.1`.
3. Optional dedicated: `godot --headless --path example -- --dedicated`.
