# Review RFC-003 — Listen-server and authority

**Type:** Godot game (demo). **Omitted:** SQL, user auth, XSS. RPCs: sender vs slot **does** apply.  
**Step 0:** two LAN instances **unverified**.

## 1. RFC adherence — PASS (unverified runtime)

`host_lan` / `join_lan`, IPv4 check, handshake, `submit_move` without `call_local`, leave / `server_lost`.

## 2. RULES — PASS

## 3. Security — PASS for this scope (sender check; no ENet crypto, expected on LAN)

## 4. Performance — NEEDS WORK (non-blocking)

Client sends `submit_move` every physics frame, including `Vector2.ZERO`. Fine for a 4-player demo.

## 5. Maintainability — PASS

**Risk:** Medium until Host+Join is run by hand. **Blockers:** none from reading.
