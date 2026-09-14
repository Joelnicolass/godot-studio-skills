# RFC-004 — Dedicated, túnel, snapshot y guía

**Complejidad:** Medium  
**Predecesores:** RFC-003  
**Sucesores:** ninguno  
**Features:** F13, F14, F15, F17, F18

**Tipo:** juego Godot. Omitido: SQL, auth, browsers.  
**Nota command:** online = RFC de glue dedicated separado del slice de gameplay (ya cumplido: este RFC no es el 001).

## Resumen

Servidor dedicado (mismo proyecto), emote por túnel `Dictionary`, snapshot de `elapsed`, HUD, README. Artefactos de producto (F18) ya escritos en este flujo; este RFC los deja en el árbol y añade README + reviews al cerrar.

## Archivos

```
example/glue/net_glue.gd              # dedicated boot, reflect emote, primer cliente arranca
example/scenes/world/demo_match.gd    # elapsed, push_snapshot, apply_snapshot
example/scenes/ui/match_hud.gd
example/scenes/ui/match_hud.tscn
example/scenes/actors/pawn_2d.tscn    # MpCustomPipe channel emote
example/scenes/actors/pawn_3d.tscn
example/scenes/actors/pawn_2d.gd      # try_emote
example/scenes/actors/pawn_3d.gd
example/scenes/components/pawn_input.gd  # emote action
example/README.md
example/PRD.md                        # ya existe (F18)
example/FEATURES.md
example/RULES.md
example/RFCS.md
example/RFCs/*.md
```

Parches del kit canónico si hacen falta para la demo (spawner warning, reentrancy de `broadcast_custom`, docs del túnel): `addons/mp_kit/` en el **repo padre**, luego re-copiar al example. No silenciar un bug forkeando el addon solo en example.

## Dedicated

```
MpBoot.is_dedicated_process()
  → configure(port, 4, 1, PackedStringArray(["emote"]))
  → host_dedicated()
  → al primer peer_joined: match_running, broadcast_load_world, goto_world
```

`-- --dedicated --world=3d --mp-port=7777` (user args). No usar `--headless` como única señal.

## Túnel

```
Cliente / 1P: pipe.send({slot, msg})
Listen host / dedicated server origin: pipe.broadcast(...)
Glue: if is_server() and from_peer != 1: broadcast_custom
```

Pawn flashea visual si `data.slot == player_slot`. Evitar doble flash: ignorar el paquete crudo del cliente (`from_peer != 1`) en el server y esperar el echo `from_peer == 1`, **o** flash en todos los peers de forma idempotente.

## Snapshot

Solo server y 1P incrementan `elapsed`. Server networked: `push_snapshot` ~5 Hz. Cliente: `snapshot_received` → asignar elapsed, `set_physics_process(false)` en el ticker.

## Criterios de aceptación

1. `godot --headless --path example -- --dedicated` bindea, sin lobby. Primer cliente Join ve el match. El proceso dedicated **no** tiene pawn (`local_slot()==0`).
2. `--world=3d` carga match 3D en dedicated + clientes.
3. Canal `emote` en allowlist. E en un cliente se ve en el otro (broadcast). Listen host también replica emote.
4. `broadcast_custom` desde glue **no** entra en recursión infinita.
5. HUD muestra modo, elapsed, `occupied_slots()`, último túnel. Dedicated: copy de “sin jugador local”, no “player 1”.
6. Cliente no tiquea `elapsed` (el valor llega por snapshot).
7. `example/README.md` documenta 1P, LAN dos instancias, dedicated, F6, re-copia del addon.
8. F18: artefactos de producto presentes (este RFC no los borra).
9. Cero puntaje, Steam, o predicción (F19–F21).

## Testing manual

Tres procesos: dedicated headless + 2 clientes. Emote. LAN host emote. HUD elapsed. README seguido al pie.

## Reglas aplicables

RULES §4 dedicated y túnel, F13–F15, F17–F18, dedicated.md del kit.
