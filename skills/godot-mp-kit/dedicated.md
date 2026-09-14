# Dedicated server (online / VPS)

Godot 4: the **same project** is server and client. A dedicated server is not a second repo. Docs: [Exporting for dedicated servers](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html).

## Model

```
[VPS / editor headless]   MpKit.host_dedicated()   peer 1, local_slot() == 0, no pawn
[Client]                  MpKit.join(ip)           slots 1..N, submit_* to peer 1
[1P]                      do not host()            OfflineMultiplayerPeer
[LAN]                     MpKit.host()             listen-server; the host is a player
```

ENet UDP is enough on the internet if the server has a **public IP** (or a forwarded port) and the firewall opens that port. That is “online” in this kit. A listen `host()` behind NAT is **not** online.

Several concurrent rooms in **one** dedicated process (`MpRoomDirectory` / `MpMatchmaker`) **are** the kit. Steam, WebRTC, and process-per-match (one Godot process per match) stay out of scope.

## How you develop (same as production)

Do not write a listen-server and “move it to a VPS later”. If they chose **online**, the happy path is dedicated + clients from day one.

Local:

```bash
# Server (no window). --dedicated is a user arg (after --).
godot --headless --path . -- --dedicated

# Clients: another instance, Join 127.0.0.1
```

In the editor: Debug → Customize Run Instances. `MpBoot.is_dedicated_process()` is true with:

- feature tag **`dedicated_server`** (or `dedicated`) on **that** instance
- `--dedicated` on the command line (user args `-- --dedicated` **or** a loose flag; the kit reads `get_cmdline_args` and `get_cmdline_user_args`)
- **Dedicated Server** export → `OS.has_feature("dedicated_server")`

If **Override Main Run Args** is unchecked, Godot **may ignore** that row’s Launch Arguments. Check override on the hub instance, or use the `dedicated_server` tag (tags still combine when override is off).

Do **not** treat `--headless` alone as dedicated: GUT/CI also run headless, and a headless client does not open the port.

Optional port in glue: `int(MpBoot.user_value("mp-port", "7777"))`.

## Glue on boot

```gdscript
func _ready() -> void:
	var port := int(MpBoot.user_value("mp-port", "7777"))
	MpKit.configure(port, 4, 1)
	# signals…

	if MpBoot.is_dedicated_process():
		var err := MpKit.host_dedicated()
		if err != OK:
			push_error("MpKit.host_dedicated failed: %s" % err)
			get_tree().quit(1)
			return
		# no menus; load the world when match policy says so
		return

	# client / 1P: lobby, Join, or play solo
```

HUD: if `MpKit.local_slot() == 0`, there is no local player (dedicated process). Do not read `get_unique_id() == 1` as “I am player 1”.

Spawn: `for slot in MpKit.occupied_slots()`. Dedicated does not include peer 1. Listen: the host slot is occupied.

`rpc_load_world` is `call_remote`: the server **does not** receive it. Dedicated also enters the world via glue (`goto_world()`), same as the listen host.

## Export and VPS

1. Linux preset (typical on a VPS). Resources → **Export Mode: Export as dedicated server**. That forces headless and the `dedicated_server` feature. You may strip textures/audio.
2. Export the binary. On the VPS: UDP `port` open (firewall / security group). Bind is `0.0.0.0`.
3. Run the binary (dedicated export is already headless). Clients: `join(PUBLIC_IP)`.
4. systemd or Docker: one process, one port. Several hub rooms in that process (`MpKit.rooms`). One process per match or Steam: outside the kit.

Same scene, same `submit_*`, same authority. The server simulates; clients paint.

## Anti-patterns

- Dedicated spawning a pawn for itself (`local_slot() == 0`).
- Developing only with listen `host()` and expecting that to run on a VPS with no player.
- Treating test `--headless` as dedicated.
- Steam or one Godot process per match inside `mp_kit.gd` (in-process rooms already live on `MpKit.rooms`).
- A second “server-only” project.
