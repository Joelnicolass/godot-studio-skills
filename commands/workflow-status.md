Estás guiando un proyecto a través de un flujo de desarrollo basado en RFCs con estas etapas.

El orquestador (`godot-studio-workflow`) ejecuta estos pasos; el usuario no tiene que tipear cada slash si pidió hacer el juego. La etapa 6 es opcional si no hay tests.

| # | Etapa | Artefacto | Comando / Prompt |
|---|-------|----------|------------------|
| 1 | Crear PRD | PRD.md | `/create-prd` (interactive-prd-creation-prompt.md) |
| 2 | Verificar PRD | PRD.md (mejorado) + PRD-REVIEW.md | `/verify-prd` (prd-comprehensive-verification-prompt.md) |
| 3 | Extraer features | FEATURES.md | `/extract-features` (prd-to-features-prompt.md) |
| 4 | Generar rules | RULES.md | `/generate-rules` (prd-to-rules-prompt.md) |
| 5 | Generar RFCs | carpeta RFCs/ + RFCS.md | `/generate-rfcs` (prd-to-rfcs-prompt.md) |
| 6 | Estrategia de testing | TEST-STRATEGY.md | `/test-strategy` (testing-strategy-prompt.md) |
| 7 | Implementar RFCs (uno por uno, en orden) | Código | `/implement-rfc <id>` (implementation-prompt-template.md) |
| 8 | Revisar cada implementación | `reviews/REVIEW-RFC-<id>.md` | `/review-rfc <id>` (code-review-prompt.md) |
| 9 | Gestionar cambios (cuando se mueven los requisitos) | `changes/CHANGE-REQUEST-<nnn>.md` | `/manage-changes` (prd-change-management-prompt.md) |
| 10 | Chequeo de estado (en cualquier momento) | este reporte | `/workflow-status` (workflow-status-prompt.md) |

La etapa 6 va antes de la etapa 7 a propósito: un plan de tests escrito después del código es una auditoría de cobertura, no un plan.

Inspeccioná el proyecto actual para determinar el progreso del flujo:

1. Qué artefactos existen: PRD.md, PRD-REVIEW.md, FEATURES.md, RULES.md, RFCS.md, carpeta RFCs/, reviews/, changes/?
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
