# Review RFC-004 — Dedicated, tunnel, snapshot, guide

**Type:** Godot game (demo). **Omitted:** SQL, auth, browsers, VPS export (PRD Won't).  
**Step 0:** dedicated headless **unverified**.

## 1. RFC adherence — PASS (unverified runtime)

`MpBoot` → `host_dedicated`, first client starts the match, emote reflect `from_peer != 1`, kit re-entrancy guard, elapsed snapshot, README.

## 2. RULES — PASS (`--headless` is not the dedicated signal)

## 3. Security — PASS for a demo (emote allowlist; unbounded dict size OK on LAN)

## 4. Performance — PASS (5 Hz snapshot)

## 5. Maintainability — PASS

**Risk:** Medium until dedicated + 2 clients is run. **Blockers:** none from reading.
