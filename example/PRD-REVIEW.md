# PRD-REVIEW — MpKit Example

**Tipo de producto:** juego Godot (demo / guía).  
**Controles omitidos (auditables):** modelo de negocio, SQL/inyección, auth de usuarios, responsive web, REST, personas de marketing, compliance SaaS, WCAG web. No se fabricó un hallazgo de “no hay inyección SQL”.

**Paso 0 — anclaje en la realidad**

- Proyecto vacío leído: `example/project.godot` (Godot 4.7, mobile, Jolt, icono default). Sin escenas aún.
- Addon leído: `addons/mp_kit/` v0.3.0. API usada en el PRD coincide: `host` / `host_dedicated` / `join` / `send_custom` / `broadcast_custom` (sin auto-reflect) / `MpBoot` no trata `--headless` solo como dedicated / `occupied_slots` / `local_slot() == 0` en dedicated.
- Discrepancia documentada y corregida en el PRD: la política de arranque dedicated del snippet de `game-glue.md` espera 2 clientes; **esta demo arranca al primero** (explícito en supuestos).
- Versión Godot: tomada del `project.godot` existente, no de memoria.

## 1. Resumen de hallazgos

| Hueco | Impacto | Tratamiento |
|-------|---------|-------------|
| El PRD inicial de conversación no fijaba política de arranque listen vs dedicated | High | Documentado: listen al hostear; dedicated al 1.er cliente |
| No estaba el idioma de UI vs código | Medium | UI = idioma del producto; IDs en inglés; `DemoCopy` |
| Rejoin indefinido | Medium | Pawn se destruye al leave; slot reservado por el kit |
| Export VPS | Low | Won't: se documenta headless; no presets de export en el repo |
| Tests | Low | Explicitamente no pedidos |

**Evaluación:** el PRD es un GDD corto suficiente para FEATURES/RFCs. Alcance acotado a una guía, no a un título. Listo para extraer features.

## 2. Recomendaciones (aplicadas en PRD.md)

- Nombrar el addon como dependencia copiada, no forkeada.
- Separar 2D y 3D en RFCs (slice vertical = una escena 2D).
- Dedicated en RFC propio (no mezclar con el slice de movimiento 1P).
- Omitir score/armas para no ensuciar el ejemplo.

## 3. Puntajes

| Dimensión | Puntaje | Nota |
|-----------|---------|------|
| Completitud | 8/10 | Cubre loop, MP, 2D/3D, no-goals. No hay feel de título (a propósito). |
| Claridad | 9/10 | Decisiones de chat tabuladas. |
| Viabilidad | 9/10 | Encaja en APIs ya existentes del kit. |
| Enfoque en el usuario | 8/10 | Usuario = dev que aprende el framework. |

## 4. Autochequeo

- Tablas de este review: 1 de huecos (5 filas), 1 de puntajes (4 filas). Recuento verificado.
- Referencias: `MpKit.host_dedicated`, `MpBoot`, `example/project.godot` — existen.
- Sin contradicción con el PRD mejorado (misma política de arranque).
