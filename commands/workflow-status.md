Estás guiando un proyecto a través de un flujo de desarrollo basado en RFCs con estas etapas.

El orquestador (`godot-studio-workflow`) ejecuta estos pasos; el usuario no tiene que tipear cada slash si pidió hacer el juego. **Camino corto:** `/implement-feature` (no exige PRD). `/test-strategy` es opcional si no hay tests.

| # | Etapa | Artefacto | Comando / Prompt |
|---|-------|----------|------------------|
| — | Implementar una feature (default) | Código + `FEATURES.md` | `/implement-feature` |
| 1 | Crear PRD (opcional) | PRD.md | `/create-prd` |
| 2 | Verificar PRD | PRD.md (mejorado) + PRD-REVIEW.md | `/verify-prd` |
| 3 | Extraer features | FEATURES.md | `/extract-features` |
| 4 | Generar rules | RULES.md | `/generate-rules` |
| 5 | Guía visual (si hay look) | VISUAL.md | `/create-visual-guide` |
| 6 | Generar RFCs | carpeta RFCs/ + RFCS.md | `/generate-rfcs` |
| 7 | Estrategia de testing | TEST-STRATEGY.md | `/test-strategy` (opcional) |
| 8 | Implementar RFCs (uno por uno) | Código | `/implement-rfc <id>` |
| 9 | Revisar cada implementación | `reviews/REVIEW-RFC-<id>.md` | `/review-rfc <id>` |
| 10 | Gestionar cambios (cuando se mueven los requisitos) | `changes/CHANGE-REQUEST-<nnn>.md` | `/manage-changes` |
| 11 | Chequeo de estado (en cualquier momento) | este reporte | `/workflow-status` |

`/test-strategy` va **antes** de implementar a propósito: un plan de tests escrito después del código es una auditoría de cobertura, no un plan. `VISUAL.md` puede faltar si todavía no hay look; entonces el pase visual no corre.

Inspeccioná el proyecto actual para determinar el progreso del flujo:

1. Qué artefactos existen: PRD.md, PRD-REVIEW.md, FEATURES.md, RULES.md, VISUAL.md, RFCS.md, carpeta RFCs/, reviews/, changes/, `.studio/MEMORY.md`?
2. Qué RFCs aparecen implementados en el codebase versus todavía no empezados? Compará los criterios de aceptación de cada RFC contra el código real — no asumas que un RFC está hecho solo porque existe código.
3. Qué RFCs fueron revisados? Revisá `reviews/` en busca de un reporte por cada RFC implementado — un RFC implementado sin review es el hueco más común en el mundo real, y los reviews son exactamente lo que se salta bajo deadline.
4. ¿Hay change requests abiertos en `changes/` cuyas decisiones siguen pendientes?
5. ¿Algún signo de drift: código que contradice el PRD o RULES.md, features en el codebase sin RFC, RFCs salteados fuera de orden?

Si no podés inspeccionar archivos de forma directa, pedime que describa o pegue los artefactos antes de reportar.

Luego reportá:

1. **Tabla de estado** — cada etapa del flujo con su artefacto y estado (Done / In progress / Missing / Stale)
2. **Progreso por RFC** — estado de implementación y review lado a lado, una fila por RFC:

   ```
   RFC-001  implemented ✅   reviewed ❌
   RFC-002  implemented ✅   reviewed ❌
   RFC-003  implemented ✅   reviewed ✅
   ```

   Una sola fila de "reviews done" oculta qué RFCs se revisaron de verdad. Reportalos individualmente.
3. **Inconsistencias** — cualquier cosa con drift, salteada o contradictoria, con referencias de archivo
4. **Siguiente paso** — la única acción siguiente recomendada, con el comando o prompt exacto a ejecutar
