# MpKit in 6 steps

A multiplayer game without writing network code: nodes in the editor and a script like a single-player one. It works the same solo, on a LAN (one player hosts) and with a dedicated server, over ENet (UDP) or WebSocket (TCP).

The full example is in `examples/arena_2d/`: open `boot.tscn` and press F6.

**The shortest path**: with the plugin enabled, **Project › Tools › MpKit: Setup game...**. Pick a folder, 2D or 3D, players, transport and whether you want online rooms; the dialog lists the files it will create (`[+]`, and `[~]` when one exists: then it writes nothing) and builds the boot, the world, a predicted player and the network. Press F5 and it already plays solo, on a LAN, on a dedicated server or online. The steps below explain what it built, in case you want to do it by hand.

## 1. Install

Copy `addons/mp_kit/` into your project and enable **MpKit** in Project → Project Settings → Plugins. That adds the `MpKit` autoload.

## 2. Boot (the menu)

A new scene with a `Control` root:

- An **MpFlow** child. In the inspector: `boot_path` = this scene, `world_path` = your world and `net_config` = a new **MpNetConfig** (`.tres`): transport, port, players, public address and TLS in one place.
- An instance of `res://addons/mp_kit/mp_boot_menu.tscn`: Play solo, Host LAN, Join buttons and the list of LAN rooms.

The `MpFlow` moves itself under the root of the tree and survives scene changes. No autoload needed.

## 3. World

A scene with a `Node2D` or `Node3D` root:

| Node | What for |
|---|---|
| `SpawnPoints` with one `Marker2D`/`Marker3D` per player | where each one is born |
| `Actors` (empty) | the players appear there |
| **MpSlotSpawner** | `spawn_path` = `../Actors`, `pawn_scene` = your player, `spawn_points` = `../SpawnPoints` |
| **MpState** (optional) | score, clock, round: everyone sees it, late joiners too |

## 4. Player

The player scene (`CharacterBody2D`, `CharacterBody3D`...) with two children:

- **MpActor**: tick what is synced (position, rotation, visible, and under *Extra* any property, for example `health` or `Health:current`) and turn on **Prediction › predict** for the player. Save the scene: the editor builds the synchronizer and saves it.
- **MpInput**: the InputMap actions the player sends (the arrows and Enter by default).

## 5. Player script

```gdscript
extends CharacterBody2D

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput

# Movement: the server runs it and, with predict, the owner too, at once (no lag).
func mp_move(keys: MpInput, _delta: float) -> void:
	velocity = keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * 200.0
	move_and_slide()

func _physics_process(_delta: float) -> void:
	if not net.is_authority():   # the rules run on the server (or solo)
		return
	if input.is_action_just_pressed(&"ui_accept"):
		MpState.of(self).add(&"score")
		net.to_all(&"flash")      # runs mp_all_flash() everywhere

func _process(_delta: float) -> void:
	if net.is_local() and Input.is_action_just_pressed(&"ui_focus_next"):
		net.to_server(&"recolor")  # runs mp_sv_recolor() on the server

func mp_sv_recolor() -> void:
	modulate = Color(randf(), randf(), randf())

func mp_all_flash() -> void:
	$Sprite.modulate = Color.WHITE
```

| You want… | Use |
|---|---|
| something to look the same everywhere | tick it in **MpActor › Sync** |
| the player to answer without lag | **MpActor › Prediction › predict** and the movement in `mp_move(input, delta)` |
| the player's keys on the server | `input.get_vector`, `input.is_action_just_pressed`… (same API as `Input`) |
| a value of your own (aim point, cursor) | `input.set_value(&"aim", v)` on the owner, `input.get_value(&"aim")` on the server |
| a one-off order from the player | `net.to_server(&"name", args)` → `func mp_sv_name(args)` |
| an effect on everyone (sound, flash) | `net.to_all(&"name", args)` → `func mp_all_name(args)` |
| who asked for an order | `net.sender_slot()` inside `mp_sv_*` |
| a number of the match | `MpState.of(self).set_value(&"key", v)` / `.add(&"key")`, `changed` signal |
| spawning bullets, units, pickups | `$MpSpawner.spawn_actor(scene, {"position": p})` (the scene goes in *Extra Scenes*) |

Only the owner may ask for its actor's `mp_sv_*`, and only the server sends `mp_all_*`: the kit checks it.

### A real network: lag, jitter and loss

| What | Where | What it does |
|---|---|---|
| Prediction | **MpActor › Prediction › predict** + `func mp_move(input, delta)` | The owner moves at once with its keys. The server runs the same `mp_move` once per frame of the owner, in order; when its state arrives, the owner goes back to it and replays the ticks the server has not seen (reconciliation). Same ticks: the correction stays at ~0. |
| Smoothing | **MpActor › Smoothing** | `BUFFERED` (default): other players are drawn `buffer_delay_s` in the past, between two real server states: they look even when packets arrive unevenly. `FOLLOW`: chases the newest state (no delay, small stutters). `NONE`: no smoothing. |
| Bandwidth | **MpActor › Sync › send_hz** | States per second (0 = every frame). `BUFFERED` hides the gaps. |
| Input buffer | automatic with predict | The server gathers a few of the owner's frames before taking them one per tick, so a player with jitter moves evenly for the others. A client that sends extra frames does not go faster. |

`mp_move` rules: movement only (it may run several times per tick while reconciling). Sounds and effects behind `if not keys.is_replaying():`. Jumps with `is_action_just_pressed` do go inside: they look the same on the owner, on the server and when replayed.

To test with a bad network, add `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` to every process (outgoing lag, jitter and loss of unreliable packets). `net.last_correction()` tells how much the server corrected the owner in the last state.

## 6. Test

| Mode | How |
|---|---|
| Solo | F5 → Play solo |
| LAN | Debug → Run Multiple Instances (2). One: Host LAN. The other: Join `127.0.0.1` |
| Dedicated | `godot --headless --path . -- --dedicated` and the clients join `127.0.0.1` |
| WebSocket | add `--transport=ws` to every process (a WS server only serves WS clients) |
| Web | export with the Web preset (no threads). The export uses WebSocket only and hides Host and the LAN list: a browser only joins. The server is a dedicated with `transport = ws` |

## Beyond the 6 steps

### Online: rooms and several matches on one server

Three scenes and no glue (the example has them: `rooms.tscn`, `lobby.tscn` and the `MpMatch` of `arena.tscn`):

| Where | Node | What it does |
|---|---|---|
| Server (a VPS or your PC) | **MpRoomServer** in a scene of its own, with an **MpLobbyConfig** (`.tres`: port, rooms, range of match ports, times) and optionally an **MpRoomRules** | Opens the lobby. When a room is full and everyone is ready, it starts **one dedicated process per match** with a ticket: only the seated players get in. Run it with `godot --headless --path . res://rooms.tscn`. Several matches at once = several processes; the cap is `max_matches` |
| Client | **MpLobbyScreen** (`rooms/ui/mp_lobby_screen.tscn`) in a scene; in the boot, `MpBootMenu.lobby_scene_path` shows the *Online rooms* button and `MpFlow.lobby_path` says where to come back | Connect with a name, see rooms, create one (public or with a code), take a seat, *ready*, chat. When the match starts it joins by itself and comes back with the result |
| World | **MpMatch** | On the server: `all_loaded`, `player_joined`, `player_left`, `player_back`, `player_abandoned`. `finish(result)` ends the match for everyone (`finished` on every peer) and tells the room |

Each match process is your own project with `--dedicated` and a ticket: `MpFlow` arms the agent that checks the ticket by itself. Room rules of your own (how many seats per mode, which characters are allowed):

```gdscript
extends MpRoomRules

func seats_for(options: Dictionary) -> int:
	return 4 if options.get("mode") == "2v2" else 2

func accept_pick(pick: Dictionary) -> bool:
	return pick.get("hero") in ["knight", "archer"]
```

### A private match on your PC (with a code)

`MpBootMenu.offer_private_server` shows *Private server*: it starts a dedicated on your PC (`MpLocalServer`, the same code as the VPS, no room server), joins you and shows `ip:port#CODE`. Your friends type that in the address field; without the code they cannot get in. From code: `MpLocalServer.start_on(get_tree(), seats)` and the `server_ready(address, port, codes)` signal.

### Web

A browser can neither open a server nor use UDP, so a web game joins a WebSocket dedicated (`MpNetConfig.transport = ws`). Desktop and web do not mix: a WebSocket server serves WebSocket clients. The menu's address field takes `192.168.1.5`, `game.example.com`, either with `:port`, or a `wss://…` URL. A page served over `https` needs `wss://`: the server carries a certificate and key (in its `MpNetConfig`, in the `MpLobbyConfig` for rooms, or with `deploy.sh --tls-cert … --tls-key …`) and the client turns on `MpNetConfig.tls_client`. A browser pauses a hidden tab: a web player who switches tabs stops for the others until they come back, and in a room match, being away longer than `rejoin_grace_s` counts as an abandon.

### Put it on a VPS

Export the Linux preset and run `addons/mp_kit/deploy/deploy.sh user@vps build/server --rooms 7700 --open-firewall`. Full guide, several instances and web over https: [deploy/README.md](deploy/README.md).

Details of every piece: [README.md](README.md).
