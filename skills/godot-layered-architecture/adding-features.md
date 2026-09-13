# Cómo agregar una feature (1P + LAN)

Leer primero `SKILL.md` (estilo Clean vs estándar ya elegido). Red: `godot-mp-kit`. Tipos de entidad: `godot-composition-first/resources.md`.

## Checklist

Si un ítem no aplica, escribir “N/A”. No saltearlo en silencio.

1. [ ] Alcance de producto explícito.
2. [ ] ¿Es un **tipo** (otra bala, otro enemigo, otro power-up)? → Resource `.tres` + la misma escena. No un script nuevo por skin de stats.
3. [ ] Reglas de **ronda** (vidas, duración, layers): un solo lugar (`GameConstants` / `MatchRules.tres`). Look de instancia: `@export` en el nodo.
4. [ ] Clean: ¿regla testeable sin escena? → `src/domain/` + test. Estándar: ¿el World se está hinchando? → nodo/componente nuevo, no domain inventado.
5. [ ] Input local distingue host vs guest (`rpc_id(1, …)`).
6. [ ] RPC cliente → servidor: allowlist, `any_peer` + `get_remote_sender_id()` vs `MpKit.peer_id_for(slot)`. No `call_local` que duplique daño/spawn.
7. [ ] Spawn de simulación: **solo host** + `MultiplayerSpawner` registrado **antes** de `add_child`.
8. [ ] Transform: `MultiplayerSynchronizer` (o `MpAuthority.ensure_sync`).
9. [ ] Colisión / `queue_free` / puntos: autoridad del servidor.
10. [ ] Guest no muta score/vidas/trackers.
11. [ ] 1P: mismo código (`OfflineMultiplayerPeer`).
12. [ ] 2P: no se duplican actores.
13. [ ] Rejoin: decisión explícita.
14. [ ] FX locales; copy de UI en el idioma del producto; código en inglés.
15. [ ] El pawn no tiene RPC de score.

## Pipeline de input

```
Cliente (o 1P):
  1. Leer control local
  2. if not puede_actuar(local_slot()): return
  3. if MpAuthority.should_send_command():
        rpc_id(1, submit_X, payload)
     else:
        aplicar_en_host(payload)

Host:
  4. Validar sender == MpKit.peer_id_for(slot)
  5. Validar cooldown / munición (sesión o nodo Match)
  6. Mutar física o spawn (Resource del tipo decide damage/speed/scene)
  7. Puntos/vidas: un solo dueño de estado → eventos
  8. FX local + RPC discreto de presentación si hace falta
```

El nodo de input **no** instancia proyectiles ni suma puntos. Solo pide.

## Presentación

- Post-proceso, flashes: cada peer. No van en el snapshot de score.
- Passes/FX como nodos intercambiables.
- HUD: `mouse_filter = IGNORE` salvo controles que traguen el pointer.
