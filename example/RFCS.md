# RFCs — MpKit Example

**Product type:** Godot game (demo).  
**Omitted on every RFC (auditable):** SQL schema, user auth, browsers, REST, “Database Schema Changes”. Instead: scenes, Resources, MpKit glue.

**Authority:** PRD.md > FEATURES.md > RULES.md > these RFCs.

Each RFC is implemented with `/implement-rfc <id>`. This demo’s product chat approved the full scope: implement 001→004 in order.

RFC-001 is the **vertical 1P 2D slice**. 3D is RFC-002. LAN is RFC-003. Dedicated / tunnel / snapshot is RFC-004 (online glue is not mixed into the gameplay slice).

| RFC | Title | Features | Predecessors | Successors | Complexity |
|-----|--------|----------|--------------|------------|------------|
| RFC-001 | 1P 2D slice | F1, F2, F3, F4, F5 | — | RFC-002 | Medium |
| RFC-002 | 3D match and shared spawn | F6, F7, F8 | RFC-001 | RFC-003 | Medium |
| RFC-003 | Listen-server and authority | F9, F10, F11, F12, F16 | RFC-002 | RFC-004 | Medium |
| RFC-004 | Dedicated, tunnel, snapshot, guide | F13, F14, F15, F17, F18 | RFC-003 | — | Medium |

Won't F19–F23: no RFC implements them.

**Autocheck:** 4 RFCs. Must+Should F1–F18 each appear once. 5+3+5+5 = 18.
