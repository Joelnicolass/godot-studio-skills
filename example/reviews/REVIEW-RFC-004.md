# Review RFC-004 — Dedicated, túnel, snapshot y guía

**Tipo:** juego Godot (demo).  
**Omitido:** SQL, auth, browsers, export VPS (Won't del PRD).

**Paso 0:** Godot no disponible. Dedicated headless **unverified**.

## 1. Adherencia al RFC

**Veredicto:** PASS (unverified runtime)

- `MpBoot.is_dedicated_process()` → `host_dedicated`; primer cliente arranca match.
- `--world` / `--mp-port` user args.
- Emote: `send` vs `broadcast`; glue `from_peer != 1`. Kit: guard `_broadcasting_custom`.
- Snapshot `elapsed` 5 Hz; cliente apaga el ticker.
- HUD modos incluyen dedicated sin jugador local.
- `README.md` + artefactos F18.

## 2. RULES

**Veredicto:** PASS — no se usa `--headless` como señal de dedicated. Parches del kit en el addon canónico (spawner `.`, reentrancy túnel).

## 3. Seguridad

**Veredicto:** PASS para demo — túnel allowlist `emote`. Dict opaco, tamaño no limitado (aceptable en LAN/demo).

## 4. Rendimiento

**Veredicto:** PASS — snapshot 5 Hz, un dict.

## 5. Mantenibilidad

**Veredicto:** PASS — README apunta al flujo de producto.

**Riesgo:** Medium hasta probar dedicated + 2 clientes.  
**Bloqueantes:** ninguno por lectura.

**Autochequeo:** F13–F18 cubiertos en prosa vs archivos `net_glue.gd`, `demo_match.gd`, `README.md`.
