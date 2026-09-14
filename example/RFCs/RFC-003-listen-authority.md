# RFC-003 — Listen-server and authority

**Complexity:** Medium  
**Predecessors:** RFC-002  
**Successors:** RFC-004  
**Features:** F9, F10, F11, F12, F16

**Type:** Godot game. Omitted: SQL, auth, browsers.

## Summary

Host LAN and Join. Spawn handshake. Host-authoritative `submit_move` / `apply_move`. Leave and `server_lost` / `join_failed`. Host uses `MpKit.host()`, not `host_dedicated()`.

Policy: `host_lan` → `host()` → `match_running` → `broadcast_load_world` → `goto_world`. Late join: `load_world_to`. Listen host spawns its pawn in `DemoMatch._ready`. Clients: `MpWorldReady` → `client_world_ready` → `ensure_pawn`.

RPC: `any_peer` + `call_remote`; validate `get_remote_sender_id() == MpKit.peer_id_for(player_slot)`. Input only if `player_slot == MpKit.local_slot()` and slot != 0.

## Acceptance

1. Host LAN: host enters the world and drives slot 1.
2. Second process Join `127.0.0.1`: same `world_kind`, two pawns, distinct looks, no duplicate actor per peer.
3. Guest does not apply movement as authority; transform comes from server + `MpReplicate`.
4. Invalid IP does not call `join`; shows `DemoCopy.STATUS_BAD_IP`.
5. `join_failed` and `server_lost` return to boot with a message.
6. Leave in match: `leave` + boot.
7. `peer_left`: pawn `queue_free`; kit keeps the slot reserved.
8. Late join: `load_world_to` only; host is not reset.
9. `MpSpawner` has the pawn packed scene registered before the first `add_child`.
10. No `call_local` on `submit_move`. No score RPC.

Manual: two editor instances Host + Join. Kill host → client to lobby. 1P still works.
