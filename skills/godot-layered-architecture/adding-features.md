# Cómo agregar una feature (1P + LAN)

Leer primero `SKILL.md`. Si hay red, aplicar también `godot-mp-kit`.

## Checklist

Si un ítem no aplica, escribir “N/A”. No saltearlo en silencio.

1. [ ] Alcance de producto explícito (no “de paso” un sistema entero).
2. [ ] Constantes de **negocio** solo en `GameConstants`. Look en `@export`.
3. [ ] ¿Hay regla testeable sin escena? → `src/domain/` + test **antes o junto** con el nodo.
4. [ ] Input local distingue host vs guest (`rpc_id(1, …)`).
5. [ ] RPC cliente → servidor: allowlist, `any_peer` + validar `get_remote_sender_id()` contra `MpKit.peer_id_for(slot)`. **No** `call_local` que ejecute daño/spawn dos veces.
6. [ ] Spawn de simulación: **solo host** + `MultiplayerSpawner` registrado **antes** de `add_child`.
7. [ ] Transform: `MultiplayerSynchronizer` (o `MpAuthority.ensure_sync`).
8. [ ] Colisión / `queue_free` / puntos: `is_multiplayer_authority()` / `multiplayer.is_server()`.
9. [ ] Guest no llama `GameSession.submit_*` ni muta trackers.
10. [ ] 1P: mismo código (`OfflineMultiplayerPeer`). Probar “jugar solo” sin abrir puerto.
11. [ ] 2P: cada uno ve la acción del otro; no se duplican actores.
12. [ ] Rejoin: decisión explícita (spawner reenvía, o se acepta que mueran).
13. [ ] FX locales en cada máquina; copy de UI en el idioma del producto; código en inglés.
14. [ ] El pawn no tiene RPC de score.

## Pipeline de input (copiar, no inventar)

```
Cliente (o 1P):
  1. Leer control local
  2. if not GameSession.can_control(local_slot()): return
  3. if MpAuthority.should_send_command():
        rpc_id(1, submit_X, payload)
     else:
        aplicar_en_host(payload)

Host:
  4. Validar sender == MpKit.peer_id_for(slot)
  5. Validar can_control / cooldown (dominio)
  6. Mutar física o spawn
  7. Si hay puntos/vidas: GameSession.submit_* → GameEvents
  8. FX local + RPC discreto de presentación si el cliente debe verlo
```

El nodo de input **no** instancia proyectiles ni suma puntos. Solo pide.

## Dominio: ¿hace falta?

| Pregunta | Si sí |
|----------|--------|
| ¿Cooldown / munición / i-frames deben sobrevivir rejoin y anti-cheat? | Tracker `RefCounted` en domain, uno por slot, creado en `GameSession.start` |
| ¿Solo “se siente” en UI y el guest no puede abusarlo? | Igual validar en host |
| ¿Es puramente visual? | Feature/shared, sin domain |

`submit_*` en la sesión, no `scores.add` desde el pawn.

## Presentación

- CRT, ripple, dust, flashes: cada peer los corre. No viajan en el snapshot de score.
- Componer passes/FX como nodos intercambiables (`shared/`), no un shader monolítico “de este juego”.
- HUD: `mouse_filter = IGNORE` salvo controles que deban tragar el pointer.
