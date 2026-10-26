# MpKit: first steps

A multiplayer game without writing network code: nodes in the editor and a script like a single-player one. It works the same solo, on LAN (a player hosts) and with a dedicated server, over ENet (UDP) or WebSocket (TCP).

The full example is in `examples/arena_2d/`: open `boot.tscn` and press F6.

**The shortest path**: with the plugin on, **Project › Tools › MpKit: Setup game...**. Pick a folder, 2D or 3D, players, transport and whether you want online rooms; the dialog lists the files it will create (`[+]`, and `[~]` if they exist: then it writes nothing) and builds `game.tres`, the boot, the world, a predicted player and the rooms. F5 and it plays solo, on LAN, dedicated or online. The steps below are the same by hand: one resource, two scene nodes and your player.

## 1. Install

Copy `addons/mp_kit/` into your project and enable **MpKit** in Project → Project Settings → Plugins. That adds the `MpKit` autoload.

## 2. The game in one `.tres`

A new **MpGame** resource (`game.tres`). It holds everything about the network (transport, port, players, relay, TLS) and, in the **Scenes** group, your scenes: `boot_scene`, `world_scene` and, for online rooms, `lobby_scene` and `rooms_scene`. It is the one place each thing is written.

## 3. Boot (the menu)

A new scene with a `Control` root:

- An **MpFlow** child with **Game** = your `game.tres`. Nothing else.
- An instance of `res://addons/mp_kit/mp_boot_menu.tscn`: Play solo, Host LAN, Join, the LAN rooms list and, when the game has a lobby, Online rooms.

The `MpFlow` moves itself under the root of the tree and survives scene changes. No autoload needed. The flow owns the session; the menu, the lobby screen and the room server read the game from it.

## 4. World

A scene with a `Node2D` or `Node3D` root (your level) and an **MpWorld** node with **Player Scene** = your player. When you add it, the editor builds its pieces as children you can see and move:

| Piece | What for |
|---|---|
| `SpawnPoints` | one marker per seat: move them where each player starts |
| `Actors` | where the players appear (and anything a spawner makes) |
| `Players` | one player per seat, on every peer, late joiners too |
| `State` | score, clock, round: everyone sees them (`Mp.state()`) |
| `Match` | waits for everyone to load, who leaves and who comes back, the end (`Mp.finish()`) |
| `Hud/Leave` | a button to leave the match |
| `Hud/Invite` | in a private match on this PC, what friends type to join |

A piece you delete is built again when the scene opens. Do not rename them.

## 5. Player

The player scene (`CharacterBody2D`, `CharacterBody3D`...) with two children:

- **MpActor**: tick what is synced (position, rotation, visible, and under *Extra* any property, e.g. `health` or `Health:current`) and turn on **Prediction › predict** for the player. Save the scene: the editor builds the synchronizer and saves it.
- **MpInput**: the InputMap actions the player sends (the arrows and Enter by default).

## 6. Player script

```gdscript
extends CharacterBody2D

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput

# Movement: the server runs it and, with predict, the owner too, at once (no lag).
func mp_move(keys: MpInput, _delta: float) -> void:
	velocity = keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * 200.0
	move_and_slide()

func _physics_process(_delta: float) -> void:
	if not net.is_authority():   # rules run on the server (or solo)
		return
	if input.is_action_just_pressed(&"ui_accept"):
		Mp.state().add(&"score")
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
| to read the player's keys on the server | `input.get_vector`, `input.is_action_just_pressed`… (the same API as `Input`) |
| to send a value of your own (aim, cursor) | `input.set_value(&"aim", v)` on the owner, `input.get_value(&"aim")` on the server |
| a one-off order from the player | `net.to_server(&"name", args)` → `func mp_sv_name(args)` |
| an effect on everyone (sound, flash) | `net.to_all(&"name", args)` → `func mp_all_name(args)` |
| to know who asked for an order | `net.sender_slot()` inside `mp_sv_*` |
| a number of the match | `Mp.state().set_value(&"key", v)` / `.add(&"key")`, `changed` signal |
| to spawn bullets, units, pickups | `$MpSpawner.spawn_actor(scene, {"position": p})` (the scene goes in *Extra Scenes*) |

From any script, the **Mp** class has the verbs of the match:

| You want… | Use |
|---|---|
| to play solo, host, join, leave | `Mp.play_solo()`, `Mp.host()`, `Mp.join("192.168.1.5")` (or `"ip:port#CODE"`, or `"wss://…"`), `Mp.leave()` |
| to open the online rooms | `Mp.open_rooms()` |
| to know whether the rules run here | `Mp.is_server()` (the server, or your PC solo) |
| your seat, your player | `Mp.me()`, `Mp.player(Mp.me())` |
| the numbers of the match | `Mp.state()` |
| to end the match for everyone | `Mp.finish({"winner": slot})` (on the server) |

Only the owner may ask for its actor's `mp_sv_*` (`MpActor › Owner › callers = OWNER`), and only the server sends `mp_all_*`: the kit checks it. For world things anyone uses (a door, the example's bell), `callers = ANYONE`, and check what they ask inside `mp_sv_*`. To leave the match, the `MpWorld`'s Leave button (an **MpLeaveButton**) or `Mp.leave()`.

### A real network: lag, jitter and loss

| What | Where | What it does |
|---|---|---|
| Prediction | **MpActor › Prediction › predict** + `func mp_move(input, delta)` | The owner moves at once with its keys. The server runs the same `mp_move` once per owner frame, in order; when its state arrives, the owner goes back to it and replays the ticks the server has not seen (reconciliation). Same ticks: the correction stays at ~0. |
| Smoothing | **MpActor › Smoothing** | `BUFFERED` (default): the other players are drawn a little in the past, between two real server states: they look steady even when packets arrive unevenly. With `adaptive_buffer` (on) that "little" is measured: a few ticks on a good network, more on a bad one, up to the `buffer_delay_s` cap. `FOLLOW`: chases the newest state (no delay, small stutters). `NONE`: no smoothing. |
| Bandwidth | **MpActor › Sync › send_hz** | States per second (0 = every frame). `BUFFERED` hides the gaps. |
| Input buffer | automatic with predict | The server gathers as many of the owner's frames as the way they arrive needs (one on a good network) before taking one per tick, so a player with jitter moves steadily for the others. If the server runs short, the owner speeds up a little to fill it. A client that sends extra frames does not go faster. |
| Shots with ping | **MpActor › Lag compensation** + `net.rewound(func)` or `net.view_lag()` | The server checks a shot against where the shooter SAW the others (a second of history), not against the present. |
| Network quality | `Mp.net_quality()` | RTT, jitter, loss and a grade (`good`, `fair`, `bad`) for your UI. |

`mp_move` rules: movement only (it may run several times per tick while reconciling). If it uses inertia or gravity, add `velocity` to *Sync › Extra*: it travels with the pose and reconciliation starts from it. Sounds and effects behind `if not keys.is_replaying():`. Jumps with `is_action_just_pressed` do go inside: they look the same on the owner, on the server and when replayed.

To test with a bad network, add `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` to every process (outgoing lag, jitter and loss of unreliable packets). `net.last_correction()` says how much the server corrected the owner in the last state.

## 7. Test

| Mode | How |
|---|---|
| Solo | F5 → Play solo |
| LAN | Debug → Run multiple instances (2). One: Host LAN. The other: Join `127.0.0.1` |
| Dedicated | `godot --headless --path . -- --dedicated` and the clients join `127.0.0.1` |
| WebSocket | add `--transport=ws` to every process (a WS server only serves WS clients) |
| Web | export with the Web preset (no threads). The export uses WebSocket (direct, or through the relay when the game says `relay`) and hides Host and the LAN list: a browser only joins. The server is a dedicated with `transport = ws`, or any server through the relay |

## Beyond the basics

### Online: rooms and several matches on one server

Two more scenes, written down in `game.tres` (`lobby_scene`, `rooms_scene`); the `MpMatch` already comes with the `MpWorld`. The example has them: `rooms.tscn` and `lobby.tscn`.

| Where | Node | What it does |
|---|---|---|
| Server (VPS or your PC) | **MpRoomServer** in a scene of its own, with an **MpLobbyConfig** (`.tres`: port, rooms, match port range, times) and optionally an **MpRoomRules** | Opens the lobby. When a room is full and everyone is ready, it starts **one dedicated process per match** with a ticket: only the seated players get in. It takes the game's network. Run it with `godot --headless --path . -- --room-server`. Several matches at once = several processes; the cap is `max_matches` |
| Client | **MpLobbyScreen** (`rooms/ui/mp_lobby_screen.tscn`) in a scene. With `lobby_scene` in the game, the menu shows *Online rooms* and the Back button goes to the boot | Connect with a name, see rooms, create one (public or with a code), sit, *ready*, chat. When the match starts it joins by itself, and when it ends it comes back with the result |
| World | **MpMatch** | On the server: `all_loaded`, `player_joined`, `player_left`, `player_back`, `player_abandoned`. `finish(result)` ends the match for everyone (`finished` on every peer) and tells the room |

Each match process is your own project with `--dedicated` and a ticket: `MpFlow` builds the agent that checks the ticket by itself. Room rules of your own (how many seats per mode, which characters are allowed):

```gdscript
extends MpRoomRules

func seats_for(options: Dictionary) -> int:
	return 4 if options.get("mode") == "2v2" else 2

func accept_pick(pick: Dictionary) -> bool:
	return pick.get("hero") in ["knight", "archer"]
```

### No public IP: the relay (Railway or another host)

If your server has no public IP (your PC behind the router) or you want a domain with TLS for the web, use the relay: a small Node server (`relay/server.mjs`, no dependencies) that works as a tunnel. The Godot server connects out, and so do the players. In `game.tres`: `transport = relay`, `relay_url = wss://your-relay.up.railway.app`, `relay_room = my-game`; the server gets the secret from `MPKIT_RELAY_SECRET`. Rooms, matches and private matches work the same. Steps for Railway: [relay/README.md](relay/README.md).

### A private match on your PC (with a code)

`MpBootMenu.offer_private_server` shows *Private server*: it starts a dedicated on your PC (`MpLocalServer`, the same code as the VPS, no room server), joins you to it, and the match HUD (an `MpInviteLabel`, already in the `MpWorld`) shows `ip:port#CODE`. Your friends type that in the address field; without the code they cannot get in. A second click gives back the match that already runs. By code: `MpLocalServer.start_on(get_tree(), seats)` and the `server_ready(address, port, codes)` signal.

### Web

A browser can neither open a server nor use UDP, so a web game joins a WebSocket dedicated (`transport = ws` in `game.tres`) or goes through the relay (`transport = relay`). Desktop and web do not mix: a WebSocket server serves WebSocket clients. The menu's address field takes `192.168.1.5`, `game.example.com`, either with `:port`, or a `wss://…` URL. A page served over `https` needs `wss://`: the server carries a certificate and key (in its `game.tres`, or in the `MpLobbyConfig` for rooms, or with `deploy.sh --tls-cert … --tls-key …`) and the client turns on `tls_client` in `game.tres`. A browser pauses a hidden tab: a web player who switches tabs freezes for the others until they come back, and staying away longer than `rejoin_grace_s` in a room match counts as abandoning it.

### Put it on a VPS

Export the Linux preset and run `addons/mp_kit/deploy/deploy.sh user@vps build/server --rooms 7700 --open-firewall`. The full guide, several instances and web over https: [deploy/README.md](deploy/README.md).

The detail of every piece: [README.md](README.md). Step by step, for a person: [GUIDE.md](GUIDE.md).
