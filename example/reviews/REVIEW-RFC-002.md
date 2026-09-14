# Review RFC-002 — Match 3D y spawn compartido

**Tipo:** juego Godot (demo).  
**Omitido:** SQL, auth, browsers.

**Paso 0:** Godot no disponible. Unverified runtime.

## 1. Adherencia al RFC

**Veredicto:** PASS (unverified runtime)

- `match_3d.tscn` / `pawn_3d.tscn` con `BoxMesh`, piso, cámara, markers.
- `DemoMatch` en ambos mundos. Toggle 2D/3D en `boot.gd`.
- `MpSpawner.spawn_path = ../Actors` (no `.`).
- F6 3D: `_standalone_preview` añade cámara + piso.
- Gravedad + `move_and_slide` en `pawn_3d.gd`.

## 2. RULES

**Veredicto:** PASS — placeholders, sin glTF, composición `DemoMatch`.

## 3. Seguridad

**Veredicto:** N/A

## 4. Rendimiento

**Veredicto:** PASS — un `BoxMesh` por pawn.

## 5. Mantenibilidad

**Veredicto:** PASS — `match_2d.gd` / `match_3d.gd` vacíos a propósito; la lógica vive en `DemoMatch`.

**Riesgo:** Low  
**Bloqueantes:** ninguno por lectura.
