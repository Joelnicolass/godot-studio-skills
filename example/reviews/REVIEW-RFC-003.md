# Review RFC-003 — Listen-server y autoridad

**Tipo:** juego Godot (demo).  
**Omitido:** SQL, auth de usuarios, XSS. Red: RPCs allowlist + sender vs slot (sí aplica).

**Paso 0:** Godot no disponible. Dos instancias LAN **unverified**.

## 1. Adherencia al RFC

**Veredicto:** PASS (unverified runtime)

- `host_lan` / `join_lan` + `MpLan.is_valid_ipv4`.
- Política: host arranca de inmediato; late join `load_world_to`.
- `submit_move` `any_peer` + `call_remote` + `peer_id_for(player_slot)`.
- `DemoMatch`: listen host spawn en `_ready`; clientes en `client_world_ready`; `peer_left` `queue_free`.
- `server_lost` → boot. Salir en HUD.
- Extra: dedicated/emote ya están (RFC-004). No contradice 003.

## 2. RULES

**Veredicto:** PASS — kit intacto como transporte; glue en `NetGlue`.

## 3. Seguridad

**Veredicto:** PASS para el alcance — validación de sender en submit. Sin crypto (ENet LAN, esperado).

## 4. Rendimiento

**Veredicto:** NEEDS WORK (no bloqueante) — el cliente manda `submit_move` cada physics frame, incluso en `Vector2.ZERO`. Aceptable en demo 4 jugadores; no para un título.

## 5. Mantenibilidad

**Veredicto:** PASS

**Riesgo:** Medium (handshake no corrido en máquina).  
**Bloqueantes:** ninguno por lectura. Probar Host + Join a mano.
