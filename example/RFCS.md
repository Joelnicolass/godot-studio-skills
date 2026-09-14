# RFCs — MpKit Example

**Tipo de producto:** juego Godot (demo).  
**Omitido en cada RFC (auditable):** schema SQL, auth de usuarios, browsers, REST, “Database Schema Changes”. En su lugar: escenas, Resources, glue MpKit.

**Autoridad:** PRD.md > FEATURES.md > RULES.md > estos RFCs.

Cada RFC se implementa con `/implement-rfc <id>` (orquestador: tech-lead → aprobación → developer → reviewer). En esta demo el producto ya aprobó el alcance completo en el chat: se implementan en orden 001→004.

## Enfoque

El RFC-001 es el **slice vertical 1P 2D** (lobby + pawn que se mueve), no infra eterna. El 3D es gemelo (RFC-002). LAN (RFC-003) y dedicated/túnel/snapshot (RFC-004) van aparte, como pide el command para online.

```
RFC-001 (1P 2D)
  └─ RFC-002 (3D + DemoMatch extraído)
       └─ RFC-003 (listen + submit + replicate)
            └─ RFC-004 (dedicated + emote + snapshot + README)
```

## Tabla maestra

| RFC | Título | Features | Predecesores | Sucesores | Complejidad |
|-----|--------|----------|--------------|-----------|-------------|
| RFC-001 | Slice 1P 2D | F1, F2, F3, F4, F5 | — | RFC-002 | Medium |
| RFC-002 | Match 3D y spawn compartido | F6, F7, F8 | RFC-001 | RFC-003 | Medium |
| RFC-003 | Listen-server y autoridad | F9, F10, F11, F12, F16 | RFC-002 | RFC-004 | Medium |
| RFC-004 | Dedicated, túnel, snapshot, guía | F13, F14, F15, F17, F18 | RFC-003 | — | Medium |

Won't F19–F23: ningún RFC las implementa.

**Autochequeo:** 4 RFCs. Features Must+Should F1–F18 aparecen exactamente una vez. F1–F5 → 001; F6–F8 → 002; F9–F12+F16 → 003; F13–F15+F17–F18 → 004. Suma 5+3+5+5 = 18. Tabla 4 filas.
