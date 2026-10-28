# MpKit: the complete guide, step by step

This guide is for a person who knows basic Godot (scenes, nodes, the inspector, scripts) and wants to build a multiplayer game with MpKit without writing network code. It expands [QUICKSTART.md](QUICKSTART.md): if something here seems to contradict it, say so, because that is a mistake.

Code names (`MpActor`, `to_server`, `owner_slot`...) are the kit's own. Editor menus are named as in an English editor.

## Contents

1. [What MpKit is](#1-what-mpkit-is)
2. [Concepts in plain words](#2-concepts-in-plain-words)
3. [Install](#3-install)
4. [Path A: the Setup game wizard](#4-path-a-the-setup-game-wizard)
5. [Path B: by hand, scene by scene](#5-path-b-by-hand-scene-by-scene) (one resource, `MpFlow` and `MpWorld`)
6. [Programming the player](#6-programming-the-player)
7. [World things: objects, spawning, score, start and end](#7-world-things-objects-spawning-score-start-and-end)
8. [Testing](#8-testing)
9. [Online with rooms](#9-online-with-rooms)
10. [A private match with a code](#10-a-private-match-with-a-code), and [online rooms your players host](#103-online-rooms-your-players-host-no-server-of-yours) (no server of yours)
11. [Web](#11-web)
12. [Relay (a tunnel through Railway or another host)](#12-relay-a-tunnel-through-railway-or-another-host)
13. [Putting it on a VPS](#13-putting-it-on-a-vps)
14. [Security and limits](#14-security-and-limits)
15. [Common problems](#15-common-problems)
16. [Glossary](#16-glossary)
17. [I want X → I use Y](#17-i-want-x--i-use-y)
18. [Where to go next](#18-where-to-go-next)

## 1. What MpKit is

MpKit is a Godot 4 addon that solves the network of a multiplayer game. You build scenes with a few nodes and write the game as if it were single-player.

What it solves:

- **One model: the server decides** (host-authoritative). Rules run in one place, the server. Clients send keys and requests; the server decides and sends them the result.
- **The same files for every mode**:

| Mode | Who the server is |
|---|---|
| Solo | Your own PC, no network |
| LAN (listen server) | A player "hosts": plays and is the server at the same time |
| Dedicated | A process without a player (your PC or a VPS); the others join |
| Online rooms | A room server (lobby) that starts one dedicated per match |
| Private with a code | A dedicated on your PC; your friends get in with a code |
| Web | A browser joins a dedicated over WebSocket |

- **Three transports**, with the same API:

| Transport | Value | What for |
|---|---|---|
| ENet | `enet` | UDP, desktop, the fastest (default) |
| WebSocket | `ws` | TCP, required for the web |
| Relay | `relay` | WebSocket through a server in the middle (Railway or another): the Godot server needs no public IP nor open ports. See [12](#12-relay-a-tunnel-through-railway-or-another-host) |

What it does **not** do: it brings no gameplay. No score, no characters, no game text. That is yours. It is also not worth installing in a single-player game.

## 2. Concepts in plain words

| Word | What it means |
|---|---|
| **Server** | The process where the rules run. On LAN it is the host's PC; dedicated, a process without a player. Solo, your PC is the server. |
| **Client** | A process that joined a server. It sends keys and requests, and draws what the server sends. |
| **Authority** | Where things are decided. In MpKit it is always the server (or solo). `net.is_authority()` is true there. |
| **Slot** | The player number: 1, 2, 3… The server assigns it. It is what your game uses ("P1", "P2"). |
| **Peer id** | Godot's internal connection number (1 = the server, other numbers after that). **Do not use it as the player**: use the slot. |
| **Owner** (`owner_slot`) | The slot of the player a node belongs to. 0 = nobody's (it is the server's: a bell, a door). |
| **Local** | The node belongs to the player sitting at this machine. `net.is_local()`. |
| **Proxy** | The copy of a node this machine only draws: on your screen, the other players are proxies. |
| **Sync** | Copying a property from the server to everyone (position, health, color). Ticked in **MpActor › Sync**. |
| **Prediction** | The owner moves its character at once with its keys, without waiting for the server. |
| **Reconciliation** | When the server's real state arrives, the owner goes back to that position and replays the keys the server has not seen yet. If everything matches, the correction is almost 0. |
| **Smoothing** | How proxies are drawn between two server states, so they do not jump. |

Slot vs peer id, with an example. On a dedicated with two players: the server is peer 1 and has no slot (`MpKit.local_slot()` gives 0). The clients are slot 1 and slot 2, even if their peer ids are, say, `1739281` and `20918377`. On LAN, the host is slot 1 **and** peer 1; the first client, slot 2.

## 3. Install

1. Copy the `addons/mp_kit/` folder to `res://addons/mp_kit/` in your project.
2. Open **Project › Project Settings › Plugins**.
3. Tick **MpKit** (Enable).
4. Check **Project Settings › Autoload**: `MpKit` must point to `res://addons/mp_kit/mp_kit.gd`. The plugin adds it by itself when enabled.

When you enable it:

- The `MpKit` autoload is added.
- Script templates are copied to `res://script_templates/` (for `CharacterBody2D`, `CharacterBody3D`, `Node`, `Node2D`, `Node3D`). When you create a new script you can pick, for example, the *MpKit actor* template.
- These entries appear in **Project › Tools**:

| Entry | What it does |
|---|---|
| **MpKit: Setup game...** | The wizard: builds a whole game (see [Path A](#4-path-a-the-setup-game-wizard)). |
| **MpKit: Make selection a network actor** | Adds an `MpActor` to every selected node and, for a `CharacterBody2D`/`3D`, an `MpInput` too. Ctrl+Z undoes it. |
| **MpKit: New replicated feature...** | Creates `res://features/<id>/<id>.gd` + `.tscn` (the low-level path). |
| **MpKit: New session flow...** | Creates an `MpFlow` as an autoload in `res://glue/session_flow.tscn`. **Not needed** if you put the `MpFlow` in the boot scene (what this guide recommends). Do not use both: see [15](#15-common-problems), "two flows". |
| **MpKit: Install Cursor/VS Code snippets** | Copies snippets to `.vscode/mpkit.code-snippets`. |

## 4. Path A: the Setup game wizard

The shortest path. In two minutes you have a game that works solo, on LAN, dedicated and online.

### 4.1 Opening the dialog

1. With the plugin on, go to **Project › Tools › MpKit: Setup game...**
2. The *MpKit: setup a multiplayer game* dialog opens.

### 4.2 Every option

| Option | What it is | Default |
|---|---|---|
| **Folder** | Where everything is written. It must start with `res://`. | `res://game` |
| **World** | `2D` or `3D`. | 2D |
| **Max players** | Players of the match (1 to 64). Goes to `max_players` in `game.tres` and to the number of spawn points. | 4 |
| **Transport** | `ENet (UDP, desktop)`, `WebSocket (TCP, web builds)` or `Relay (WebSocket tunnel: Railway…)`. Goes to `transport` in `game.tres`. | ENet |
| **Relay URL** | Shown only with Relay: the relay's address (`wss://your-relay.up.railway.app`). Goes to `relay_url`. | empty |
| **Online rooms** | Adds a room server and a lobby screen. | ticked |
| **Private server button** | Shows the *Private server* button in the menu (a match on your PC with a code). | ticked |
| **Make the boot scene the main scene** | Makes the boot the project's main scene (F5 opens it). | ticked |

### 4.3 The file tree

At the bottom, under **Files:**, the dialog shows what it will write. With the `res://game` folder, online rooms and the main scene:

```
[+] res://game/game.tres
[+] res://game/player.gd
[+] res://game/player.tscn
[+] res://game/world.tscn
[+] res://game/boot.tscn
[+] res://game/rooms_config.tres
[+] res://game/rooms.tscn
[+] res://game/lobby.tscn
[~] project.godot (main scene)
```

- `[+]` = a new file.
- `[~]` on a file of the folder = it already exists. If **even one** shows up, the **Create** button is disabled and nothing is written. It never overwrites a file of yours. Pick another folder.
- `[~] project.godot (main scene)` shows up when *Make the boot scene the main scene* is ticked: it warns that the main scene will change. That line does not disable **Create**.
- Without *Online rooms*, `rooms_config.tres`, `rooms.tscn` and `lobby.tscn` do not show up.

Press **Create**. The editor scans the files and opens `boot.tscn`.

### 4.4 What each file has

**`game.tres`**: an `MpGame`, the game in one resource. It has the network (the transport and players you picked, port 7777) and, under **Scenes**, the paths of `boot.tscn`, `world.tscn` and, with rooms, `lobby.tscn` and `rooms.tscn`. `relay_url` is what you typed in *Relay URL*, and `relay_room` is the project's name plus a random tail (`my-game-3fa9c1`): two games made with the wizard never share rooms on the same relay.

**`player.tscn`**:

```
Player (CharacterBody2D or CharacterBody3D, motion_mode = Floating, script player.gd)
├── Visual   (a square Polygon2D, or a capsule MeshInstance3D)
├── Shape    (CollisionShape2D / CollisionShape3D)
├── MpActor  (predict = on; sync_rotation only in 3D)
│   └── MpSync (a MultiplayerSynchronizer, already built)
└── MpInput  (actions ui_left, ui_right, ui_up, ui_down, ui_accept)
```

**`player.gd`**: movement in `mp_move`, and Enter (`ui_accept`) adds a point in the `MpState` and flashes it on everyone (`mp_all_flash`).

**`world.tscn`**: your level and a single network node, `MpWorld`, which built its pieces:

```
World (Node2D or Node3D)
├── Camera, Sun          (3D only)
└── MpWorld              (player_scene = player.tscn, seats = Max players)
    ├── SpawnPoints      (P1..Pn in a circle, one per player)
    ├── Actors           (empty: the players appear here)
    ├── Players          (MpSlotSpawner)
    ├── State            (MpState, with its MpSync)
    ├── Match            (MpMatch)
    └── Hud
        ├── Leave        (MpLeaveButton: leaves the match)
        ├── Invite       (MpInviteLabel: in a private match, the code for your friends)
        ├── Start        (MpStartButton: the host starts with the players already in)
        └── Waiting      (MpWaitingLabel: "Waiting for players (1/4)" while the match waits)
```

**`boot.tscn`**:

```
Boot (Control, full screen)
├── Flow  (MpFlow: game = game.tres, nothing else)
└── Menu  (an instance of mp_boot_menu.tscn: offer_private_server)
```

The menu shows *Online rooms* only because `game.tres` has a `lobby_scene`.

**`rooms_config.tres`**: an `MpLobbyConfig` with `seats_per_room` = the smaller of *Max players* and 2. The rest, default (lobby on 7700, matches on 7800-7899).

**`rooms.tscn`**: a `Rooms` node with `MpRoomServer` and `config = rooms_config.tres`. The room server takes the transport, relay and TLS from `game.tres` (through the flow that opened it with `--room-server`), and each match opens the game's boot.

**`lobby.tscn`**: an instance of `MpLobbyScreen`. Its Back button goes to the game's boot. `lobby_address` stays empty: the field starts with `game.tres`'s `public_host` on port 7700, or `127.0.0.1:7700` without one.

### 4.5 Try it at once

1. F5. The menu shows up.
2. **Play solo**: arrows to move, Enter to add a point. **Leave** goes back to the menu.
3. LAN: see [8.2](#82-lan-two-windows-on-your-pc).
4. Online: see [9.6](#96-running-the-room-server).

What the wizard does **not** add, and you should: an end of the match (`MpMatch.finish`, see [7.5](#75-start-and-end-mpmatch)). Without it, a room match does not end until everyone leaves.

## 5. Path B: by hand, scene by scene

The same thing the wizard builds, with the editor's clicks. It helps you understand what is there, or add MpKit to a game you already have. There are three things: a resource (`game.tres`), the boot with an `MpFlow`, and the world with an `MpWorld`. Plus your player.

### 5.1 The game in one resource (`MpGame`)

1. In the **FileSystem** dock, right-click your folder › **New › Resource...**
2. Search for **MpGame** and create `game.tres`. An `MpGame` is an `MpNetConfig` (the network) with your scenes.
3. In the inspector, the network:

| Property | What to set | Default |
|---|---|---|
| `transport` | `enet` (desktop), `ws` (web) or `relay` (a tunnel, see [12](#12-relay-a-tunnel-through-railway-or-another-host)) | `enet` |
| `port` | The server's port | 7777 |
| `max_players` | Players per match | 4 |
| `public_host` | Where clients find the server (`game.example.com`, `203.0.113.5:7777`). The menu's Join field and the lobby screen start with it | empty (= `127.0.0.1`) |
| `custom_channels` | Channels allowed on the `Dictionary` tunnel (empty = all) | empty |
| `lan_discovery` | Announce the match on the local network | on |
| **Relay** group | `relay_url` and `relay_room`. See [12](#12-relay-a-tunnel-through-railway-or-another-host) | empty / `mpkit` |
| **TLS (wss://)** group | See [Web](#11-web) | empty |

And the **Scenes** group:

| Property | What to set |
|---|---|
| `boot_scene` | The menu scene (5.2), e.g. `res://game/boot.tscn`. Leave and a lost server come back here |
| `world_scene` | The match scene (5.3) |
| `lobby_scene` | Optional: the online rooms screen (see [9](#9-online-with-rooms)). With it, the menu shows *Online rooms* |
| `rooms_scene` | Optional: the scene with the `MpRoomServer`, which `--room-server` opens |

Command line flags win over the `.tres`: `--transport=ws`, `--mp-port=N`, `--max-players=N`, `--relay-url=`, `--relay-room=`.

A plain `MpNetConfig` (no scenes) still works in `Flow › net_config`, with the paths set by hand on the flow. That is the older setup; the `MpGame` puts it all together.

### 5.2 Boot scene (the menu)

1. **Scene › New Scene**. Root: **User Interface** (`Control`). Rename it `Boot`.
2. Select `Boot`, **Add Child Node** (Ctrl+A), search for **MpFlow** and add it. Rename it `Flow`.
3. In the `Flow`'s inspector, **Game** = your `game.tres`. That is the only thing required.

The `Flow`'s other fields are optional. One set by hand wins over `game.tres`:

| Property | What it does |
|---|---|
| `room_name` | The name shown in the LAN list |
| `net_config`, `boot_path`, `world_path`, `lobby_path`, `room_server_path` | The same as `game.tres`, field by field. Empty = the game's |
| `start_when` | Leave it as it is. Host LAN and `--dedicated` always load the world on start; `DEDICATED_FIRST_CLIENT` and `MANUAL` only count in a *Dedicated Server* export started without `--dedicated` |

`max_players`, `custom_channels` and the port come from the `.tres`, not from the `Flow`'s fields.

4. Select `Boot` again and **Instantiate Child Scene** (Ctrl+Shift+A). Pick `res://addons/mp_kit/mp_boot_menu.tscn`. Rename it `Menu`.
5. In the `Menu`'s inspector (an `MpBootMenu`):

| Property | What it does |
|---|---|
| `title_text` | The menu's title |
| `offer_private_server` | The *Private server* button |
| `lobby_scene_path` | Another lobby scene for *Online rooms*. Empty = the game's (`lobby_scene`) |
| `play_solo_text`, `host_text`, `join_text`... | The buttons' texts, to translate |
| `world_scene`, `max_players`, `room_name`, `advertise_lan`, `drive_kit` | Only for a menu **without** an `MpFlow`. With a flow, the flow decides and these fields do nothing |

6. Save the scene as `boot.tscn`.
7. **Project › Project Settings › General › Application › Run › Main Scene**: pick `boot.tscn`.

What the menu has: **Play solo**, **Host LAN**, **Private server** (optional), **Online rooms** (optional), an address field with **Join** (it starts with `public_host` when set), and the **LAN rooms** list. On the web, Host, Private and the LAN list are hidden.

The address field takes: `192.168.1.5`, `game.example.com`, either with `:port`, `#CODE` at the end (a private match) or a `ws://…` / `wss://…` URL. The lobby screen and `MpFlow.join_address` take the same (all three use `MpAddress.parse`).

What the `MpFlow` does: it starts the network with the config, arms the start gate, changes scenes (boot ↔ world), sends the world to every admitted seat (the one coming back too) and goes back to the boot if the server is lost. It moves itself under the root of the tree and survives scene changes. No autoload needed.

### 5.3 World scene

1. **Scene › New Scene**. Root: **2D Scene** (`Node2D`) or **3D Scene** (`Node3D`). Rename it `World`. Your level goes here, as always.
2. **Add Child Node**, search for **MpWorld** and add it. When you drop it, it builds its pieces as children: `SpawnPoints` (one marker per seat), `Actors`, `Players` (an `MpSlotSpawner`), `State` (an `MpState`), `Match` (an `MpMatch`), `Hud/Leave` (an `MpLeaveButton`) and `Hud/Invite` (an `MpInviteLabel`). It finds out by itself whether the world is 2D or 3D.
3. In its inspector:

| Property | What it does | Default |
|---|---|---|
| `player_scene` | Your `player.tscn` (you build it in 5.4; you can come back later). It is the scene every seat gets | empty |
| `seats` | How many markers it builds in `SpawnPoints` (more players start over from the first) | 4 |
| `leave_button` | Builds `Hud/Leave` | on |
| `invite_label` | Builds `Hud/Invite`: in a private match of this PC it shows the code for your friends | on |
| `start_button` | Builds `Hud/Start`: in Host LAN, while the match waits for seats, the host starts with those already loaded | on |
| `waiting_label` | Builds `Hud/Waiting`: while the match waits for its seats, it says so on every peer | on |

4. Move the markers of `MpWorld/SpawnPoints` where each player should start.
5. **Save the scene** (Ctrl+S).

A piece you delete, the `MpWorld` builds again the next time you open the scene. Do not rename them: the `MpWorld` finds them by name. From a script, `Mp.state()`, `Mp.current_match()` and `Mp.player(slot)` find them.

#### Without MpWorld: every piece by hand

The `MpWorld` only builds nodes you can also add yourself. That helps when your world already has its own structure (the example's `examples/arena_2d/arena.tscn` is built this way):

1. Add a `Node2D` (or `Node3D`) child named `SpawnPoints`.
2. Inside it, one `Marker2D` (or `Marker3D`) per player: `P1`, `P2`, `P3`, `P4`. Move them where each one should appear. Slot 1 uses the first, slot 2 the second; with more players than markers they start over.
3. Add an empty `Node2D` (or `Node3D`) child named `Actors`. The players appear there.
4. Add an **MpSlotSpawner** child (search for it by name; it is a `MultiplayerSpawner`). Rename it `Players`.
5. In its inspector:

| Property | Value |
|---|---|
| `spawn_path` | `../Actors` |
| `pawn_scene` | Your `player.tscn` (you build it in 5.4; you can come back later) |
| `spawn_points` | `../SpawnPoints` |
| `despawn_on_leave` | on: removes the player when they leave |
| `hold_until_world_ready` | on (leave it) |
| `gate_unsynced_spawns` | on (leave it) |
| `room_id` | empty |

6. Optional, for the score: add an **MpState** child named `Score`.
7. Optional, for start and end: add an **MpMatch** child named `Match`.
8. To leave: add a `CanvasLayer` named `Hud` and, inside it, an **MpLeaveButton** named `Leave` (see [7.6](#76-leaving-the-match)), an **MpInviteLabel** for private matches, an **MpStartButton** so the LAN host can start without waiting for every seat, and an **MpWaitingLabel** that says the match waits.
9. **Save the scene** (Ctrl+S). On save, the `MpState` builds its `MpSync` child and it is saved.

What the `MpSlotSpawner` does: it creates one player per occupied slot. Solo, yours. On LAN, the host's at start and each client's when it finishes loading the world. Dedicated, none for the server. It names them `Pawn_1`, `Pawn_2`... and sets `MpActor.owner_slot` before they enter the tree.

### 5.4 Player scene

1. **Scene › New Scene**. Root: `CharacterBody2D` (or `CharacterBody3D`). Rename it `Player`.
2. Add the visuals and the collision as always (`Polygon2D` or `Sprite2D`, `CollisionShape2D`).
3. For a top-down game, set `motion_mode` = **Floating** in the root's inspector.
4. With the root selected: **Project › Tools › MpKit: Make selection a network actor**. It adds `MpActor` and `MpInput`. (Or add them by hand with **Add Child Node**.)
5. Set up the `MpActor` (below, every property).
6. Set up the `MpInput` (below).
7. Attach a script to the root (see [6](#6-programming-the-player)).
8. **Save the scene.** The `MpActor` builds its `MpSync` child (a `MultiplayerSynchronizer`) and it is saved in the `.tscn`. Unsaved, the `MpActor`'s inspector shows the warning *"Save the scene: the MpSync child is built in the editor."*

Important: the `MpActor` must be in the **actor's own scene** (`player.tscn`), not added on top of an instance inside the world. The `MpSync` is only built in the scene that owns the `MpActor`.

#### MpActor, property by property

**Sync group** (what everyone sees):

| Property | What it does | Default |
|---|---|---|
| `sync_position` | Syncs the position | on |
| `sync_rotation` | Syncs the rotation | on |
| `sync_visible` | Syncs `visible` | off |
| `sync_extra` | More properties: of the parent (`health`, `color_index`, `velocity`) or of a node inside it (`Health:current`) | empty |
| `send_hz` | States per second the server sends. 0 = every physics frame. Less = less bandwidth | 0 |

Transforms (and `velocity`) always travel, in the same packet as the pose; the rest only when it changes. Everything travels on spawn, so a late joiner sees the current values.

**Smoothing group** (how proxies are drawn):

| Property | What it does | Default |
|---|---|---|
| `smoothing` | `BUFFERED`: draws a little in the past, between two real states; steady even when packets arrive unevenly. `FOLLOW`: chases the newest state, no delay but small stutters. `NONE`: draws each state as it arrives | `BUFFERED` |
| `buffer_delay_s` | With `BUFFERED`: the furthest in the past it may draw (the cap). More = hides worse networks | 0.1 |
| `adaptive_buffer` | With `BUFFERED`: measures how often states arrive and how late, and draws only as far back as needed, up to `buffer_delay_s`. On a good network a few ticks; on a bad one, more. Off = always `buffer_delay_s` | on |
| `late_tolerance` | With `adaptive_buffer`: the share of states that may arrive late (3% = the 97th percentile, as Photon Fusion). Less = steadier on a bad network, a little further behind | 0.03 |
| `follow_speed` | With `FOLLOW`: how fast it chases | 14.0 |
| `freeze_rigid_if_proxy` | If the parent is a `RigidBody`, freezes it on clients (physics runs on the server) | on |

**Prediction group**:

| Property | What it does | Default |
|---|---|---|
| `predict` | The owner moves at once. It needs an `MpInput` next to it and `func mp_move(input, delta)` on the parent | off |
| `max_resim_ticks` | The most one correction replays. A high ping leaves more unconfirmed ticks; past the cap it corrects less often, to save CPU | 32 |
| `correction_smoothing_s` | How long a correction of the owner takes to fade on screen (its physics is corrected at once). 0 = drawn at once | 0.1 |
| `correction_snap_distance` | A correction longer than this (px in 2D, m in 3D) is drawn at once, as a teleport. 0 = every one fades | 0 |

**Owner group**:

| Property | What it does | Default |
|---|---|---|
| `owner_slot` | The owning slot. 0 = the server. **Do not touch it on a player**: the spawner sets it | 0 |
| `callers` | Who may ask for this node's `mp_sv_*`. `OWNER`: the player of `owner_slot` (with `owner_slot` = 0, only the server itself). `ANYONE`: any seated player (doors, bells, a shop); check what they ask inside `mp_sv_*` | `OWNER` |

**Lag compensation group**:

| Property | What it does | Default |
|---|---|---|
| `lag_compensate` | The server keeps this node's last second of poses, so a shot is checked against where the shooter saw it (see 6.8) | on |

With `smoothing` other than `NONE`, or with `predict`, the position does not travel in `position` but in `MpActor:net_position` (and `net_rotation`, `net_stamp`, `net_teleports`). If you look at the `MpSync`'s Replication panel, you will see that: it is normal. On a client, only `MpActor` moves the node.

#### MpInput

| Property | What it does | Default |
|---|---|---|
| `actor` | The `MpActor` it belongs to. Empty = the one next to it | empty |
| `actions` | The **Input Map** actions the player sends. **Only those** can be read on the server | `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_accept` |

If you use actions of your own (`jump`, `shoot`), create them in **Project Settings › Input Map** and add them to `actions`. The example adds `ui_select` (Space) to shoot.

### 5.5 Wiring it all

1. In `world.tscn`, on the `MpWorld`, set `player_scene` = `player.tscn`.
2. In `game.tres`, check `boot_scene` and `world_scene`.
3. Save everything and press F5.

## 6. Programming the player

The player script is written like a single-player one, with three rules:

- **Movement** goes in `mp_move(keys, delta)`.
- **Rules** (points, shots, damage) go behind `if net.is_authority()`.
- **Keys** are read from `input` (the `MpInput`), not from `Input`, when the server uses them.

### 6.1 The skeleton

From the example (`examples/arena_2d/player.gd`):

```gdscript
extends CharacterBody2D

const SPEED := 220.0

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput


func mp_move(keys: MpInput, _delta: float) -> void:
	velocity = keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * SPEED
	move_and_slide()


func _physics_process(_delta: float) -> void:
	if not net.is_authority():
		return
	if input.is_action_just_pressed(&"ui_accept"):
		MpState.of(self).add(StringName("p%d" % net.owner_slot))
		net.to_all(&"flash")
```

### 6.2 `mp_move` and its rules

With **Prediction › predict** on, `mp_move(keys, delta)` is run by:

- the server, once per frame of the owner's keys, in order;
- the owner, at once, with its own keys;
- the owner again, when reconciling: it replays the frames the server has not confirmed yet.

So:

1. Put **only movement** there: it may run several times in one tick.
2. Read the keys from the parameter (`keys`), not from `Input`.
3. Sounds and effects behind `if not keys.is_replaying():`.
4. Jumps with `keys.is_action_just_pressed(&"jump")` **do** go inside: they look the same on the owner, on the server and when replayed.
5. Points, damage, shots do **not** go there. They go in `_physics_process` behind `is_authority()`.
6. **Inertia or gravity**: if `mp_move` uses the previous tick's velocity (accelerating, falling), add `velocity` to **MpActor › Sync › sync_extra**. The same with any other state `mp_move` reads (a dash counter, "on the floor"). It travels in the same packet as the pose, and reconciliation starts from that value. `net.last_correction()` tells you how much was corrected.

```gdscript
# With gravity: velocity in Sync › Extra.
func mp_move(keys: MpInput, delta: float) -> void:
	velocity.x = keys.get_axis(&"ui_left", &"ui_right") * SPEED
	velocity.y += GRAVITY * delta
	if is_on_floor() and keys.is_action_just_pressed(&"jump"):
		velocity.y = -JUMP
	move_and_slide()
```

Without `predict`, `mp_move` is **not called**. Then you move in `_physics_process` behind `is_authority()`, reading `input`. It works, but the owner sees its own movement with the network's delay.

```gdscript
# No prediction: the server moves, everyone draws.
func _physics_process(_delta: float) -> void:
	if not net.is_authority():
		return
	velocity = input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * SPEED
	move_and_slide()
```

**What the server decides** (a stun, a slow, a knockback, a warp): the owner cannot predict it, so the server's state brings it and reconciliation replays from there. For that, write it on the server (in `_physics_process` behind `is_authority()`, or in an `mp_sv_*`) into a value that `mp_move` reads, and put that value in **Sync › sync_extra**:

```gdscript
var stun_ticks := 0          # sync_extra: stun_ticks, speed_mult, knock
var speed_mult := 1.0
var knock := Vector2.ZERO

func mp_move(keys: MpInput, delta: float) -> void:
	if stun_ticks > 0:
		stun_ticks -= 1      # counted inside mp_move: the server and the replay count the same
		velocity = Vector2.ZERO
	else:
		velocity = keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * SPEED * speed_mult
	velocity += knock
	knock = knock.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)
	move_and_slide()

func hit(from: Vector2) -> void:   # on the server
	knock = (position - from).normalized() * 600.0
	stun_ticks = 20
```

**Corrections on screen**: when the server decided something the owner did not predict, its node moves to the corrected pose at once (physics, `mp_move`), and what is drawn fades from where it was over `correction_smoothing_s` (0.1 s, as Source's `cl_smoothtime`; Photon Fusion and Unity Netcode do the same: only the visual pose is smoothed). A warp the server makes is not a correction to smooth: call `net.snap()` on the server right after moving the node (see 6.8), or set `correction_snap_distance`. `net.correction_offset()` says how much is still fading.

**Smooth between physics ticks**: the owner's predicted node moves in physics ticks (60 per second). On a screen at 120 Hz or more, turn on **Project Settings › Physics › Common › Physics Interpolation**: the engine draws each node between its last two ticks (Fusion's default for the local player). The kit is ready for it: proxies turn it off for themselves (`MpActor` and `MpReplicate` draw them every frame) and the correction fades per tick. Whatever follows a networked node in `_process` (a camera, a health bar) must run **after** the kit draws it: `process_priority` above 10000 (with physics interpolation, read `get_global_transform_interpolated()` in 3D).

### 6.3 Where am I? `is_authority` and `is_local`

| Call | True when | What for |
|---|---|---|
| `net.is_authority()` | Solo, or on the server (LAN host or dedicated) | The game's rules |
| `net.is_local()` | On the machine of the player that owns this node | Camera, own HUD, reading the mouse |
| `MpKit.is_networked()` | There is a network (not solo) | Texts like "Solo" / "Online" |
| `MpKit.is_server()` | This process is a networked server (false solo) | Work that only exists online: snapshots, the matchmaker, the tunnel. For the rules use `is_authority()` |
| `MpKit.is_listening()` | The server is reachable by clients (through the relay, only once the relay accepted it) | Saying "ready" |
| `MpKit.is_dedicated()` | A server without a player | No sounds, no waiting for keys |
| `MpKit.local_slot()` | This machine's slot (0 on a dedicated or before the server assigns one) | "You are P2" |

Inside any node, `is_multiplayer_authority()` (Godot's own) says the same as `net.is_authority()`: the kit keeps every node's authority on the server, so it is true solo, on the LAN host and on the dedicated, and false on a client. `MpKit.is_authority()` (or `Mp.is_server()`) is the same question from a script that is not in the world.

On a LAN host, `is_authority()` **and** `is_local()` are both true for its own player.

### 6.4 The player's keys: `input.*`

`MpInput` has the same API as `Input`. On the owner's machine (and solo, and on the host for its own player) it reads `Input` directly; on the server it reads what the owner sent.

| Method | Same as |
|---|---|
| `input.is_action_pressed(&"a")` | `Input.is_action_pressed` |
| `input.is_action_just_pressed(&"a")` | `Input.is_action_just_pressed` (never lost, even when a packet is) |
| `input.is_action_just_released(&"a")` | `Input.is_action_just_released` |
| `input.get_action_strength(&"a")` | `Input.get_action_strength` |
| `input.get_axis(&"neg", &"pos")` | `Input.get_axis` |
| `input.get_vector(&"l", &"r", &"u", &"d")` | `Input.get_vector` (length at most 1, deadzone 0.2) |
| `input.is_replaying()` | True while old frames are replayed |

An action that is not in `MpInput.actions` always gives 0 / false on the server. Strengths travel in 1/255 steps; the owner predicts with that same value, so the server agrees.

**How the keys travel** (with `predict`), nothing to set up:

- Every tick the owner sends every frame the server has not confirmed yet (as Overwatch does), delta-coded: a frame that keeps the same keys costs 5 bytes. A burst of lost packets loses no frame.
- The server takes one frame per tick and never stops a player: if the next frame is late, it repeats the last one (as Overwatch, Unity Netcode and Photon Fusion do) and drops that frame when it comes. The owner kept the same keys most of the time, so the guess is usually right; when it is not, the owner gets a correction, which fades. After 0.25 s with no frames the keys are let go.
- The server's buffer follows how late this owner's frames arrive. To resize it the server never hurries or holds the player (the others would see it hitch): the owner samples one frame more or one less now and then, and that step is smoothed on its screen too.

### 6.5 Values of your own: `set_value` / `get_value`

For what is not a key: the aim, the cursor. The owner sets it; the server reads it. What arrives was sent by the client: always check it, as the example does.

```gdscript
func _process(_delta: float) -> void:
	if not net.is_local():
		return
	input.set_value(&"aim", (get_global_mouse_position() - global_position).normalized())

# on the server, when shooting (examples/arena_2d/player.gd):
var aim: Variant = input.get_value(&"aim", Vector2.RIGHT)
var direction: Vector2 = (aim as Vector2).normalized() if aim is Vector2 and (aim as Vector2).length() > 0.01 else Vector2.RIGHT
```

`set_value` anywhere but on the owner does nothing. Up to 16 values per frame. A value travels exactly as it was set (a float, a `Vector2`, an angle in radians: no rounding), and with prediction `mp_move` reads the same value on the owner and on the server, so an aim or a facing angle is a value, not an action. More in [14](#14-security-and-limits).

### 6.6 Requests to the server: `to_server` → `mp_sv_*`

A one-off order from the player (change color, buy, use an item):

```gdscript
func _process(_delta: float) -> void:
	if net.is_local() and Input.is_action_just_pressed(&"ui_focus_next"):
		net.to_server(&"recolor")   # runs mp_sv_recolor() on the server


func mp_sv_recolor() -> void:
	color_index += 1                # color_index is in MpActor › Sync › Extra: everyone sees it
```

- `net.to_server(&"name", arg1, arg2...)` runs `mp_sv_name(arg1, arg2...)` on the server.
- Solo and on the server it runs at once.
- Only a method starting with `mp_sv_` that takes that many arguments can be called.
- Who may ask is decided by **MpActor › Owner › callers**: with `OWNER` (default), only the owner; with `ANYONE`, any seated player.
- Inside `mp_sv_*`, `net.sender_slot()` says who asked (0 = the server itself; outside an `mp_sv_*` it gives -1).

### 6.7 Effects on everyone: `to_all` → `mp_all_*`

A sound, a flash, a particle: something that happens once.

```gdscript
# on the server:
net.to_all(&"flash")


func mp_all_flash() -> void:
	body.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(body, "modulate", Color.WHITE, 0.25)
```

- Only the server may call `to_all`. It runs there and on every peer that already has the node.
- Whoever joins later does **not** get it. For something that must stay (a color, an open door), use **Sync** or `MpState`.

**An effect or a state?** An effect is a moment: a flash, a sound, a shake. It goes by `to_all` (or your own `@rpc`), and whoever was not there misses it, which is fine. A state is what is left: a mark on the ground, an open door, a score. It goes in **Sync**, in `MpState` (a list of marks under one key), or as a node a spawner makes: whoever joins or comes back gets it when it loads, without anyone sending it again. If you send effects with your own `@rpc`, send them to `MpKit.ready_peers()` (the peers whose world is loaded) with `rpc_id`, and play it on the server too if it shows there: a peer still loading would play it with no world. `MpKit.broadcast_custom(channel, data, true)` does the same for the tunnel.

### 6.8 More of the `MpActor`

| Call | What it does |
|---|---|
| `net.despawn()` | Server only, and only on nodes a spawner made: removes it everywhere (see [7.3](#73-removing-things)) |
| `net.snap()` | After a teleport or respawn, **on the server**, right after moving the node: every client jumps there instead of sliding (the others when their drawn time gets there, the owner with prediction with no fade). It travels with the pose, so no `to_all` is needed |
| `net.correction_offset()` | With prediction, on the owner: how far what is drawn still is from the real pose while a correction fades (0 = none) |
| `net.last_correction()` | With prediction, on the owner: how much the server corrected it in the last state (0 = the prediction was right) |
| `net.owner_slot` | The owning slot (to show "P1", pick a color...) |
| `MpActor.of(node)` | The `MpActor` child of a node, or `null` |
| `net.view_lag()` | On the server: how far behind this node's owner sees the others, in seconds (its ping plus what it draws in the past) |
| `net.rewound(func)` | On the server: runs `func` with the other nodes moved to where the owner saw them, then puts them back. For an instant shot: `net.rewound(func(): return space.intersect_ray(query))` |
| `net.seen_position_of(node)` | On the server: where `node` was when this node's owner saw it (a Vector2 in 2D) |

**Lag compensation** (as Valve does it): a player with ping sees the others a little in the past. If the server checked the shot against the present, it would miss what was on their screen. The kit keeps a second of poses and knows what moment each player was seeing, because it travels with every input frame and every `to_server`. Check with `net.rewound`, `net.seen_position_of` or, for a projectile, keep `net.view_lag()` when it is fired and compare with `MpLagComp.position_at_like(target, now - view_lag)`, as the example's `shot.gd` does. It never rewinds more than a second. `--lag-comp=off` on the server turns it off, to compare.

An example of `snap` after a respawn:

```gdscript
func respawn(at: Vector2) -> void:   # on the server
	position = at
	net.snap()
```

The teleport rides in the same packet as the new pose (as Source's `EF_NOINTERP` or Photon Fusion's `Teleport()`), so no client slides across it, whatever order packets arrive in. Lag compensation knows it too: a shot is never checked against a point in between.

### 6.9 The match from any script: `Mp`

The `MpActor` belongs to each actor. For what belongs to the match, the **Mp** class has the verbs, with no node to find:

| Verb | What it does |
|---|---|
| `Mp.play_solo()` | Plays solo, no network |
| `Mp.host()` | Hosts on this PC (LAN, or through the relay if the game says so) and plays |
| `Mp.join(address)` | Joins: `"192.168.1.5"`, `"game.example.com:7777"`, `"ip:port#CODE"` or `"wss://…"` |
| `Mp.leave()` | Leaves the match: to the lobby for a room match, to the boot otherwise. The same as the Leave button |
| `Mp.open_rooms()` | Opens the lobby (the game's `lobby_scene`). `false` if there is none |
| `Mp.is_server()` | Do the rules run here? The server, or your PC solo |
| `Mp.is_online()` | Is there a network? Host, dedicated or client |
| `Mp.me()` | Your seat: 1, 2, 3… (0 on a dedicated) |
| `Mp.player(slot)` | That seat's player on this machine |
| `Mp.state()` | The world's `MpState`: `Mp.state().add(&"score")` on the server, `get_value` everywhere |
| `Mp.current_match()` | The world's `MpMatch` (signals and seats) |
| `Mp.finish(result)` | On the server: ends the match for everyone |
| `Mp.net_quality()` | The connection: `rtt_ms`, `jitter_ms`, `loss` (0 to 1), `grade_name` (`good`, `fair`, `bad`). On the server, `Mp.net_quality(slot)` gives that player's |

A menu of your own instead of `mp_boot_menu.tscn` is three buttons: `Mp.play_solo()`, `Mp.host()` and `Mp.join(field.text)`.

## 7. World things: objects, spawning, score, start and end

### 7.1 An object anyone uses (the example's bell)

A door, a lever, a bell: it is in the world from the start and belongs to no player.

1. Make its scene (`bell.tscn`) with an `MpActor` child.
2. On the `MpActor`: `sync_position` off and `sync_rotation` off (it does not move), `smoothing` = `NONE`, `sync_extra` = `rings`.
3. Under **Owner**: `callers` = **ANYONE**. Without it, with `owner_slot` = 0 only the server could touch it.
4. Save the scene.
5. Instance it in the world (by hand, not through a spawner).

```gdscript
extends Node2D

@export var rings: int = 0:
	set(value):
		rings = value
		if is_node_ready():
			$Label.text = "Bell %d" % rings

@onready var net: MpActor = $MpActor


func ring() -> void:          # any player calls it on their machine
	net.to_server(&"ring")


func mp_sv_ring() -> void:    # runs on the server (callers = ANYONE)
	rings += 1
	MpState.of(self).set_value(&"bell_by", net.sender_slot())
```

`sender_slot()` says who it was. The `rings` value is in Sync: everyone sees it, a late joiner too. With `ANYONE`, check in `mp_sv_*` that the request makes sense (the player is close, the door is not locked).

A static node with an `MpActor` needs nothing else: the world's spawner holds it until each peer is ready.

### 7.2 Spawning things: bullets, units, pickups

1. In the world, add an empty `Node2D` named `Projectiles`.
2. Add an **MpSpawner** (search for it by name) named `Shots`.
3. In its inspector: `spawn_path` = `../Projectiles`.
4. Under **Extra Scenes**, add `shot.tscn`. **Required**: every peer needs the same list; it cannot be added on the server only.
5. To find it from the player, put it in a group: **Node › Groups** tab, `shot_spawner`.

The bullet (`shot.tscn`) has its `MpActor` (synced position, `sync_rotation` off). From the server:

```gdscript
const SHOT := preload("res://addons/mp_kit/examples/arena_2d/shot.tscn")

func _shoot() -> void:   # on the server
	var shots := get_tree().get_first_node_in_group(&"shot_spawner") as MpSpawner
	shots.spawn_actor(SHOT, {"position": position, "direction": direction}, net.owner_slot)
```

`spawn_actor(scene, props, owner_slot)`:

- Runs only on the server (or solo).
- `props` are applied **before** the node enters the tree (its `_ready` already sees them).
- `props` are set on the server only. What clients must see has to be in Sync (the position is; `direction` is not needed because the server moves the bullet).
- `owner_slot` > 0 makes that player the owner.

What a spawner replicates:

- A node of a scene in its list (**Extra Scenes**), or one made by `spawn(data)` with your `spawn_function`.
- A node a script adds by hand under `spawn_path` (`add_child` of something not in the list) is **not** replicated: it stays on the server only. That is useful for a server-only effect.
- If you use `spawn_function`, set it in a `_ready` of the scene (the spawner's, a sibling's or the parent's): the spawner takes it at the end of that frame, before anything spawns. Set later, a warning shows and the first node counts as added by hand.

`spawner.spawn_here(data)` is `spawn(data)` you may call from any peer: on the server (or solo) it spawns through your `spawn_function`, on a client it does nothing and returns `null`. No `if server` around it.

The player spawner (`MpSlotSpawner`, the `MpWorld`'s `Players`) gives a player to every seat whose world is ready: the ones that report it later, and the ones already ready when the spawner enters (a world loaded again, a spawner in a scene that loads later).

### 7.3 Removing things

On the bullet, when its life is over:

```gdscript
func _physics_process(delta: float) -> void:
	if not net.is_authority():
		return
	position += direction * SPEED * delta
	_age += delta
	if _age >= LIFE_S:
		net.despawn()   # removed everywhere
```

`despawn()` only works on nodes that were not saved in the world scene: the ones a spawner made. A script setting `owner` on it later does not change that. On a node saved in the world scene (the bell, a door) it gives the error *"despawn() on a node of the world scene; hide it (sync visible) or spawn it"*: a late joiner loads the scene and would see it anyway. For that, hide it (tick `sync_visible` and set `visible = false` on the server) or make it appear through a spawner.

The `MpSlotSpawner` removes the players by itself when they leave (`despawn_on_leave`).

### 7.4 Match state: `MpState`

For what everyone must see and does not belong to an actor: score, clock, round.

| Call | What it does |
|---|---|
| `MpState.of(self)` | The current scene's `MpState`, from any node. With several: `MpState.of(self, &"Score")` |
| `state.set_value(&"key", v)` | Server only: sets a value |
| `state.add(&"key", 1)` | Server only: adds (a missing key starts at 0) |
| `state.get_value(&"key", default)` | Reads it, on any peer |
| `state.values` | The whole `Dictionary` (to read). Starting values: fill them in the inspector |
| `changed(key, value)` signal | On every peer, each time a key changes |
| `state.watch(&"key", callback, default)` | On every peer: `callback(value)` now with the current value, then on each change of that key. Whoever joins or comes back gets the current value first, whatever order things start in. `unwatch(handle)` stops it |

A HUD that shows it (from the example, `hud.gd`):

```gdscript
@export var state: MpState

func _ready() -> void:
	state.changed.connect(_refresh.unbind(2))
	_refresh()
```

Or for one key, `state.watch(&"round", _show_round, 1)`: it shows the current round at once and every new one.

Do not write `state.values["x"] = 3` by hand: it is not synced. Use `set_value`.

### Who looks at this screen: `MpLocalSeat`

The HUD, the sounds, the orders, the pause and the result show one player's side. Put one **MpLocalSeat** in the world and give it to them with `@export var seat: MpLocalSeat` (something made at runtime finds it with `MpLocalSeat.of(self)`; one that only asks who looks uses `MpLocalSeat.slot_of(self)`, which gives `MpKit.local_slot()` in a scene without a seat, such as a scene run alone or a test):

| | What it says |
|---|---|
| `seat.slot` | The seat this PC plays (0 on a dedicated, or a client not seated yet) |
| `seat.is_mine(slot)` | Whether that seat is the one on this screen |
| `seat.is_online()` | Whether there is a network |
| `changed(slot)` signal | The seat on this screen changed (the server gave one) |
| `preview_slot` (inspector) | Solo only: look at the match as that seat, e.g. player 2's HUD, without a second window |

Who simulates is another question: `is_multiplayer_authority()` / `is_authority()` (6.3).

### 7.5 Start and end: `MpMatch`

An `MpMatch` in the world says when the match starts, who left and who came back, and ends it for everyone. What counts is decided by the **start gate** (`MpMatchGate`, at `/root/MpKit/Gate`, `Mp.gate()`), which the `MpFlow` arms on every path that hosts (Host LAN, a dedicated by hand, a room's dedicated):

- **Before the start** the free seats are open. The world stays **paused on every peer** until the seats it expects have loaded: every seat by default (`start_seats` = 0, in Host LAN and in a dedicated by hand alike; in a room match, every seat of the ticket). `--start-seats=N` changes that number without touching the scene. Once `load_timeout_s` (15 s) has passed since the first one came in, it starts with those who loaded; meanwhile the HUD says it waits (`MpWaitingLabel`, `Hud/Waiting`: "Waiting for players (1/4)"). In Host LAN the host does not have to wait: the HUD's **Start now** button (`MpStartButton`, in the `MpWorld`'s `Hud/Start`) starts with those already loaded.
- **After the start** only a seat that left comes back, within `rejoin_grace_s`, to the same slot (*rejoin*), unless **`late_join`** is on (`MpFlow` inspector or `--late-join`; off by default): then a newcomer still takes a free seat, and a seat abandoned past the grace is free again. A room match never has late join (the ticket names every seat). On LAN the client comes back by itself with the credential the server gave it when seating it (in memory, per `host:port`); in a room, with its ticket. If the server has not noticed yet that the client dropped, the credential (or the ticket) wins: the stale connection is dropped and the seat comes back as a rejoin. Any other peer is turned away with a reason: `match_started`, `full`, `grace_over`, `slot_taken`. The client gets `admission_rejected(reason)` and the flow shows it with `rejection_text(reason)` (override it to translate).
- A seat that does not come back in time, or never loaded, **abandons** (`player_abandoned`). If everyone left a dedicated, nobody abandons: the gate waits and, once everyone's grace has passed, emits `all_gone`. On a listen host the host keeps playing: each seat past its grace abandons and there is no `all_gone`.
- **While a seat is away** its pawn stays if the spawner keeps it (`MpSlotSpawner.despawn_on_leave` off; on by default it is removed and spawned again on the rejoin): it holds no keys and, with prediction, the server goes on simulating it with none (gravity, a knockback still run). Back, the new connection's keys move it at once.
- **A dedicated by hand serves one match after another** (a VPS started with `--dedicated`): when its match ends (`Mp.finish()`) and the last player leaves, or everyone stayed away past the grace (`all_gone`), it loads a fresh world (score and actors from zero) and opens every seat again. A game with a rematch screen can call `MpFlow.next_open_match()` itself once its players left. **If your game ends the match its own way** (not with `Mp.finish()`), tell the kit on the server with `MpKit.broadcast_session_ended(result)`, or call `MpFlow.next_open_match()` when it is over and empty; otherwise the next match only opens once everyone's grace passed, and whoever arrives before is turned away (`match_started`). Clients get the gate's state when they are admitted and pause as soon as their world loads, so their `MatchClock` starts at 0.

The knobs are in the `MpFlow` inspector, **Match start** group (`rejoin_grace_s`, `load_timeout_s`, `start_seats`, `late_join`, `pause_clients`, `match_started_status`). In a room match, the grace and the load time come from the `MpLobbyConfig`. In the editor's Remote tree, `/root/MpKit/Gate` shows `phase`, `expected`, `loaded` and `away`. In Host LAN the host can start with those already loaded: `MpStartButton`, or `Mp.gate().can_start_now()` / `Mp.gate().start_now()` from your own button.

Signals:

| Signal | Where | When |
|---|---|---|
| `all_loaded` | server | The match starts (the seats it expected loaded) or the world is ready (solo) |
| `player_joined(slot)` | server | A player entered for the first time |
| `player_left(slot)` | server | A player left |
| `player_back(slot)` | server | Came back within the grace, same slot |
| `player_abandoned(slot)` | server | Did not come back in time, or never loaded |
| `waiting_changed(waiting)` | **everyone** | The match starts or stops waiting for seats |
| `finished(result)` | **everyone** | The server called `finish` |

Methods and properties:

| Name | What it does |
|---|---|
| `finish(result)` | Server only: ends the match. Everyone gets `finished(result)`. In a room match it also writes the result for the room |
| `seats()` | The match's slots (the gate's; empty in solo) |
| `waiting` | True while it waits for seats, on every peer |

While it waits, the tree is paused. The kit's network keeps going (MpKit, the lobby, the agent, the launcher, the LAN beacon run anyway), and so do the Leave button and the invite line. Your own nodes do not: to show "Waiting for players…", give that HUD node **Process › Mode = Always** and listen to `waiting_changed`.

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$"../Match".waiting_changed.connect(func(on: bool) -> void: $Waiting.visible = on)
```

From the example (`arena.gd`): the first to 3 wins; whoever abandons loses.

```gdscript
const WIN_SCORE := 3

@onready var score: MpState = $Score
@onready var match_node: MpMatch = $Match


func _ready() -> void:
	score.changed.connect(_on_score)
	match_node.finished.connect(_on_finished)
	match_node.player_abandoned.connect(_on_abandoned)


func _on_score(key: StringName, value: Variant) -> void:
	if MpKit.is_authority() and int(value) >= WIN_SCORE:
		match_node.finish({"winner": String(key)})


func _on_abandoned(slot: int) -> void:
	for other in match_node.seats():
		if other != slot:
			match_node.finish({"winner": "p%d" % other, "abandoned": slot})
			return


func _on_finished(result: Dictionary) -> void:
	%Info.text = "%s wins!" % str(result.get("winner", "?")).to_upper()
	if MpKit.is_dedicated():
		return
	await get_tree().create_timer(2.0).timeout
	MpFlow.find_in_tree(self).leave_match()
```

`leave_match()` goes back to the lobby if the match came from a room, or to the menu otherwise.

### 7.6 Leaving the match

Add an **MpLeaveButton** to the HUD (it is a `Button`; the `MpWorld` already has one in `Hud/Leave`):

1. In the world, a `CanvasLayer` named `Hud`.
2. Inside it, **Add Child Node › MpLeaveButton**. Without a text of yours, it says *Leave*.

It calls `MpFlow.leave_match()`: to the lobby if the match came from the lobby, otherwise to the menu. It works the same solo, on the host and on a client, and also while the world is paused waiting for seats. It does not end the match for the others (that is `MpMatch.finish`).

By code, the same:

```gdscript
Mp.leave()                                  # to the lobby or the menu
MpFlow.find_in_tree(self).return_to_boot()  # always to the menu
```

### 7.7 Loading screen

The `MpFlow` loads the world on a thread (`MpWorldLoader`, an internal child of the flow and the only owner of the load): first it reads the world scene and the files your game names, then it swaps the scene and, if you asked for it, waits until **the world says it is ready** (for example after warming up shaders behind a screen). Only then does that peer count as loaded at the start gate. So nobody starts the match with the world half compiled.

1. On your flow (or its scene), tick **`world_reports_loaded`** (or start with `--world-reports-loaded`). Off (the default), "loaded" means "the world scene is in", as always.
2. In the world, once it is ready: `MpFlow.find_in_tree(self).report_world_loaded()`. Meanwhile you can report progress with `report_world_progress(0..1)`. If the world never reports, the loader goes on by itself after `report_timeout_s` (30 s), and the gate starts anyway after `load_timeout_s`.
3. For the screen, listen to the flow's `world_load_progressed(ratio, phase)`: `phase` is `MpWorldLoader.Phase` (`FILES` reading files, `WORLD` the world getting ready, `READY` done, `IDLE` the load was dropped because the scene changed elsewhere, e.g. the server was lost). `ratio` goes from 0 to 0.5 with the files and from 0.5 to 1 with the world. `world_loaded` tells the end. The screen, and whatever warms the world up, need **Process › Mode = Always**: the gate pauses the tree while it waits.
4. Two hooks to override in your `MpFlow` subclass: `_before_world_load()` (right before loading, on every peer: pick the map) and `_extra_world_loads() -> PackedStringArray` (files the world will use later, read on the same thread so nothing stalls when they appear).

With `world_reports_loaded` on, who counts changes:

- **Client**: its seat counts on `report_loaded` (an RPC to the server), not on the spawners' `world_ready`. `world_ready` stays the same for the rest (revealing spawns, `client_world_ready`), so the server can send the client what it needs to get ready.
- **Server** (LAN host, dedicated): the gate also waits for its own world (`wait_host`, `mark_host_loaded`). A dedicated with no screen reports at once.
- **Solo** ("Play solo" or against the AI): the gate is armed too, with no seats and no network (`arm([], 0)`), and waits only for the host. The tree stays paused until the world reports, so the match clock and the AI do not run behind the screen. Without `world_reports_loaded` it starts at once, as before.

If reading the world on the thread fails (a cold start right after an import, a request the engine refuses), the loader reads it on the main thread instead of staying without a world.

## 8. Testing

### 8.1 Solo

1. F5.
2. **Play solo**.

Solo, your PC is the server and the owner at once: `is_authority()` and `is_local()` are both true. All the code runs, without a network.

### 8.2 LAN: two windows on your PC

1. Menu **Debug › Run Multiple Instances** and pick 2.
2. F5. Two windows open.
3. In one: **Host LAN**.
4. In the other: pick the room under *LAN rooms*, or type `127.0.0.1` in the address field, and **Join**.

Up to 4 windows on the same PC can browse rooms at once: each listens on one of the UDP ports 7778 to 7781, and the host announces to all four. On two PCs of the same network the room shows up just the same. If it does not, type the IP the host's menu shows under the list.

### 8.3 Dedicated

In a terminal, in the project folder:

```bash
godot --headless --path . -- --dedicated
```

Then open clients (F5, or several instances) and join each one to `127.0.0.1`. The server has no player: the first client is P1.

The match starts once every seat loaded, or `load_timeout_s` (15 s) after the first one came in. To try it with a single client and no wait: `godot --headless --path . -- --dedicated --start-seats=1`.

From the editor: in the **Debug** menu's customize-instances dialog, put `--headless -- --dedicated` in one instance's arguments (tick the option to override the arguments).

### 8.4 WebSocket and relay

Add `--transport=ws` to **every** process (server and clients), or set `transport = ws` in `game.tres`. A WebSocket server only serves WebSocket clients.

```bash
godot --headless --path . -- --dedicated --transport=ws
godot --path . -- --transport=ws
```

With the relay, see [12](#12-relay-a-tunnel-through-railway-or-another-host).

### 8.5 A bad network on purpose

To feel how it plays with real lag, add to every process:

```bash
godot --path . -- --net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05
```

| Flag | What it does |
|---|---|
| `--net-lag-ms=N` | Outgoing delay, in milliseconds |
| `--net-jitter-ms=N` | Extra random delay, up to N ms |
| `--net-loss=P` | Chance of losing an unreliable packet (0.05 = 5%) |

It is outgoing only: put it on the server **and** on the clients to get both ways. On start it prints `MpLagPeer: 100 ms + 30 ms jitter, 5% loss`. Reliable packets are never lost. Never leave it in a real build.

What to tune by looking:

- The other players stutter: switch to `BUFFERED`, lower `late_tolerance` or raise the `buffer_delay_s` cap.
- The others look far behind on a good network: check that `adaptive_buffer` is on.
- Your player answers late: turn on `predict`.
- Your player "jumps" often: print `net.last_correction()`; if it is high, check that `mp_move` depends only on the keys, the position and what is in Sync (e.g. `velocity`, see [6.2](#62-mp_move-and-its-rules)).

What the kit does by itself with the network (all measured, nothing fixed):

| Piece | What it measures | What it adjusts |
|---|---|---|
| Drawing the others (`MpActor › Smoothing`) | how often states arrive and how late (97th percentile) | how far in the past they are drawn, 10% of the error per frame, never backwards |
| Input on the server | how late each player's frames arrive (97th percentile) | how many frames it gathers before using them; grows when it runs short, shrinks after 2 calm seconds |
| The owner's pace | how many frames the server has to spare or lacks | if it lacks some, the owner adds one extra frame every 16 ticks (about 6% faster), as Overwatch |
| Network quality (`Mp.net_quality()`) | 4 pings per second: RTT, jitter, loss | nothing by itself: it is for your UI (`grade_name`: `good`, `fair`, `bad`) |

On one PC, without a network, another player's movement shows on your screen about 80-90 ms after they pressed the key. With 60 ms of lag each way, 30 ms of jitter and 3% loss, about 275-335 ms, and it stays steady. `mpkit_lab/run/arena.sh` measures it on every run (`remote_delay_ms`).

### 8.6 Testing like production: `mpkit_lab`

The repo has a test project apart from any game, `mpkit_lab/` (at the root of the repo, not inside the addon). It starts the server as production does (headless) and two windows:

```bash
mpkit_lab/run/play.sh dedicated     # a headless dedicated + 2 windows
mpkit_lab/run/play.sh listen        # window 1 hosts LAN, window 2 joins
mpkit_lab/run/play.sh rooms         # a headless room server + 2 windows on the lobby
```

| Option | What it does |
|---|---|
| no options | You play in both windows (arrows, Enter, Space, Tab, Escape) |
| `--watch` | The windows play by themselves: you watch a whole match |
| `--relay` | Everything goes through a local relay (needs Node), like a Railway tunnel |

Close the windows (or Ctrl+C) to finish. The logs stay in the folder it prints on start.

The whole matrix of automatic cases: `mpkit_lab/run/all.sh` (an hour with a shared queue). For every change, `mpkit_lab/run/all.sh --quick`: one of each kind over ENet, in a few minutes. The relay's faults (a port clash, a restart, a frozen host): `mpkit_lab/run/relayfault.sh`. What each test covers: `mpkit_lab/CASES.md`.

### 8.7 How to read what happens

- **The menu** shows the status at the bottom (*Connecting to…*, *Could not join*, *Lost the server*).
- **The example's HUD** shows the role: *Solo*, *Host · P1*, *Client · P2*, *Dedicated server*. Copy it for your game (`hud.gd`).
- **Debugger › Errors panel**: the kit's warnings start with the node's name (`MpActor on 'Pawn_2': ...`). See [15](#15-common-problems).
- **Remote tree** (the Scene dock's *Remote* tab, with the game running): you see the process's nodes, `/root/MpKit`, your `Pawn_N` and their values.
- **The room server** prints one line per event: `rooms ready port 7700 (enet)` (only once reachable; through the relay, once the relay accepted it), `match for room "x" on port 7810`, `match … ended {…}`, `match … failed …`. With `--keep-match-files` it keeps each match's folder (ticket, state, result and its log).
- **The lobby client** prints `lobby client: connecting to …` and `lobby client: welcome from …`.

### 8.8 Useful flags

| Flag | What it does |
|---|---|
| `--dedicated` | Starts as a dedicated server and loads the world |
| `--listen-host` | Starts hosting LAN, without touching the menu |
| `--client1` / `--client2` + `--join-ip=IP` | Starts joining that IP (`127.0.0.1` by default) |
| `--room-server` | Opens the rooms scene (the game's `rooms_scene`, or `MpFlow.room_server_path`) |
| `--mp-port=N` | Port (wins over `game.tres`) |
| `--max-players=N` | Players (wins over `game.tres`) |
| `--transport=enet` / `ws` / `relay` | Transport |
| `--relay-url=`, `--relay-room=`, `--relay-secret=` | Relay (see [12](#12-relay-a-tunnel-through-railway-or-another-host)) |
| `--world=id` | The world, if you use the `MpFlow.worlds` catalog |
| `--keep-match-files` | Room server: does not delete each match's folder |
| `--lag-comp=off` | Server: no lag compensation (to compare) |
| `--correction-smoothing-s=0` | Client: corrections of the own player drawn at once (to compare; or another time in seconds) |
| `--relay-refused-grace-s=N` | How long a host the relay refused retries before giving up (3 s; a room server's matches use 0.5 s) |
| `--no-flow` | The `MpFlow` does nothing (tools and tests) |

They go after `--` on the command line.

### 8.9 The kit's tests

```bash
godot --headless --path . --script res://addons/mp_kit/tests/mp_test_runner.gd
```

It must end with `MPKIT TESTS PASS (n)`. They test separate pieces (slots, input frames, the synchronizer, addresses, the wizard, the adaptive buffers, lag compensation), not networked matches: that is `mpkit_lab`.

## 9. Online with rooms

To play over the internet without anybody typing IPs: a **room server** (the lobby) where people connect with a name, create or pick a room, sit down and say *ready*. When everyone is ready, the server starts **one dedicated process per match** and gives each player the address and a token. Only the seated players get in.

```
Client A ─┐                                 ┌─> Match 1 (dedicated, port 7800)
Client B ─┼─> Room server (7700) ───────────┤
Client C ─┘     lobby, rooms, chat          └─> Match 2 (dedicated, port 7801)
```

Two more scenes, written down in `game.tres`, and the `MpMatch` the `MpWorld` already has. Zero glue code. The example has them: `rooms.tscn`, `lobby.tscn` and the `MpMatch` of `arena.tscn`.

### 9.1 The server's scene: `MpRoomServer`

1. A new scene, `Node` root, name it `Rooms`.
2. Attach the script `res://addons/mp_kit/rooms/mp_room_server.gd` (or add an **MpRoomServer** node).
3. In the inspector:

| Property | What to set |
|---|---|
| `config` | An `MpLobbyConfig` (`.tres`, below) |
| `net_config` | Leave it empty: it takes the `game.tres` of the flow that opened this scene with `--room-server`. The lobby and every match take the transport, relay and TLS from there, so they talk like the game. Set it only if this server must talk differently |
| `rules` | Optional: your rules (`MpRoomRules`, below). Empty = accepts everything, 2 seats |
| `match_scene` | The scene each match opens. Empty = `game.tres`'s `boot_scene` (without an `MpGame`, the main scene) |

4. Save it as `rooms.tscn`.

### 9.2 `MpLobbyConfig`: the important fields

Create it as a new resource (**New › Resource › MpLobbyConfig**).

| Field | What it is | Default |
|---|---|---|
| `lobby_port` | The lobby's port | 7700 |
| `transport` | `enet`, `ws` or `relay`. With `game.tres` (or `MpRoomServer.net_config`), it comes from there | `enet` |
| `max_connections` | Connections to the lobby at once | 64 |
| `max_rooms` | Rooms at once | 32 |
| `seats_per_room` | Seats per room when your rules do not say otherwise | 2 |
| `max_seats_per_room` | The seats cap, whatever the rules say | 8 |
| `countdown_s` | The countdown once everyone is ready | 5.0 |
| `empty_room_close_s` | Closes an empty room after this | 120.0 |
| `resume_grace_s` | How long the lobby keeps the seat of someone who dropped from the lobby | 120.0 |
| `public_host` | The matches' address sent to clients. Empty = the one they used for the lobby | empty |
| `tls_certificate_path`, `tls_key_path` | PEM certificate and key for `wss://` (empty = `game.tres`'s `tls_*`) | empty |
| `max_matches` | Matches at once on this machine (each one is a process) | 99 |
| `match_port_min`, `match_port_max` | The matches' port range | 7800-7899 |
| `ticket_ttl_s` | How long the ticket to enter the match is valid | 60.0 |
| `rejoin_grace_s` | How long a player who dropped from the match may take to come back | 60.0 |
| `load_timeout_s` | How long the match waits for everyone to load the world | 60.0 |
| `idle_no_players_s` | The match closes if it stays empty this long | 60.0 |
| `match_max_s` | The longest a match may run (2 hours) | 7200.0 |

Any field is overridden with a flag of its name, with dashes: `max_matches` → `--max-matches=8`, `lobby_port` → `--lobby-port=7701`. A whole other `.tres`: `--lobby-config=res://other.tres`.

The example (`rooms_config.tres`) uses lobby 7700, 2 seats, a 3 s countdown, 4 matches and ports 7710-7719.

Each match is built with as many places as its ticket has seats, even more than the game's `max_players`.

### 9.3 Rules of your own: `MpRoomRules`

A script that extends `MpRoomRules` and overrides the functions you need. They all run on the room server with what a client sent: check it, do not trust it.

| Function | What for | Default |
|---|---|---|
| `seats_for(options) -> int` | Seats for the room's options. 0 or less = refused. -1 = `seats_per_room` | -1 |
| `accept_options(options) -> bool` | Are those options (map, mode) allowed? False = `bad_options` error | true |
| `accept_pick(pick) -> bool` | Is what the player picked (character, team) allowed? False = `bad_meta` | true |
| `accept_bot(pick) -> bool` | Is the bot the host added allowed? False = `bad_bot` | true |
| `build_ticket(seats, options) -> Dictionary` | What the match gets. Keep `seats`; add what you need (seed, map) | `{"options": ..., "seats": ...}` |

```gdscript
# my_rules.gd
extends MpRoomRules

func seats_for(options: Dictionary) -> int:
	return 4 if options.get("mode") == "2v2" else 2

func accept_pick(pick: Dictionary) -> bool:
	return pick.get("hero") in ["knight", "archer"]
```

1. Save the script.
2. **New › Resource**, search for your script (`my_rules.gd`), save it as `my_rules.tres`.
3. Assign it to `MpRoomServer.rules`.

Watch two things:

- For `seats_for` to see a `mode`, the room must be created with that option: set `room_options = {"mode": "2v2"}` on the lobby screen (the *Create room* button sends them), or call `create_room(name, private, {"mode": "2v2"})` from your UI.
- The default pick is `{"pick": "default"}`. With the `accept_pick` above that pick is refused: change `default_pick` on the lobby screen or call `set_pick` from your UI.

### 9.4 The client's screen: `MpLobbyScreen`

1. **Scene › New Inherited Scene…** and pick `res://addons/mp_kit/rooms/ui/mp_lobby_screen.tscn` (the example's `lobby.tscn` is made this way). Save it as `lobby.tscn`.
2. In the inspector:

| Property | What it does | Default |
|---|---|---|
| `lobby_address` | The room server: `host:port`, a name or a `wss://…` URL (editable on screen). Empty = the game's `public_host` on `lobby_port`, or `127.0.0.1` on that port | empty |
| `lobby_port` | The room server's port, when the address has none (the `MpLobbyConfig`'s `lobby_port`) | 7700 |
| `room_options` | Options every room created with *Create room* carries (map, mode); `seats_for` and `accept_options` read them | `{}` |
| `player_name` | The starting name | `Player` |
| `default_pick` | The pick every seat starts with. The lobby needs one before *ready* | `{"pick": "default"}` |
| `auto_join_match` | Join the match as soon as it starts. Off = `match_found(host, port, token)` is emitted and your UI calls `join_found()` (for a "Join" button of your own) | on |
| `back_path` | The *Back* button's scene. Empty = the game's boot | empty |
| **Texts** group | Every text, to translate | |

What it does: a connect screen (name and address), the room list, create a room (public or with a code), join with a code, seats, *Ready*, chat. When the match starts it joins by itself (through the `MpFlow`); when it ends it comes back here and shows the last result. If you dropped from a match that is still running, **Back to the match** shows up (see 9.7).

Each button calls a public method, so you can build your own screen on top:

| Method | What it does |
|---|---|
| `connect_lobby(address, name)` | Connects |
| `refresh()` | Asks for the room list |
| `create_room(name, private, options)` | Creates a room (without `options`, it uses `room_options`) |
| `join_room(id)` / `join_listed(index)` / `join_code(code)` | Enters a room |
| `set_pick(dict)` | Changes what the player picked |
| `set_ready(on)` | Ready / not ready |
| `leave_room()` | Stands up |
| `send_chat(text)` | Chat |
| `go_back()` | Closes and goes back to `back_path` (or the game's boot) |
| `join_found()` | With `auto_join_match` off: joins the match found |
| `can_rejoin()` / `rejoin_match()` | Is your match still running? / Go back to it with the same ticket |

### 9.5 Connecting the boot with the rooms

In `game.tres`, **Scenes** group: `lobby_scene` = your `lobby.tscn` and `rooms_scene` = your `rooms.tscn`. With that:

- The menu shows **Online rooms**.
- A room match, when it ends, goes back to the lobby.
- `--room-server` opens `rooms.tscn`.
- `Mp.open_rooms()` opens the lobby from a menu of your own.

(Without an `MpGame`: `lobby_path` and `room_server_path` on the `Flow`, and `lobby_scene_path` on the `Menu`.)

The `MpFlow` lives in the boot. That is why the game must start from the boot: if you open `lobby.tscn` directly with F6, there is no flow and it cannot enter the match.

In the world, the `MpMatch` does the rest: it waits for everyone to load, reports absences and writes the result.

### 9.6 Running the room server

On your PC, to test:

```bash
godot --headless --path . -- --room-server
```

It starts from the boot, and the `MpFlow` opens `game.tres`'s `rooms_scene`: that way the room server takes the game's network and every match opens the game's boot. With the example, name its boot: `godot --headless --path . res://addons/mp_kit/examples/arena_2d/boot.tscn -- --room-server`. Opening `rooms.tscn` directly works too, but without a flow: it takes the network from its own `net_config` and the matches open the main scene.

Wait for the line `rooms ready port 7700 (…)`. Then open two clients (F5 twice), **Online rooms**, **Connect**, one creates the room, the other enters, both tick **Ready**. The countdown and the match start. (Or all at once: `mpkit_lab/run/play.sh rooms`.)

Each match is your own project running with `--dedicated` and a ticket. The `MpFlow` builds the agent that checks the ticket by itself. Several matches at once are several processes, up to `max_matches`.

### 9.7 What happens when someone drops

**On the lobby**: the server keeps their seat for `resume_grace_s` (120 s).

**In the match**:

1. The server emits `player_left(slot)`. The `MpSlotSpawner` removes their player (with `despawn_on_leave`).
2. The player who dropped goes back to the lobby screen. If their match is still running, they see **Back to the match** (*Your match is still running.*). Pressed within `rejoin_grace_s` (60 s), they come back with the same ticket and get their slot back: `player_back(slot)`, and the spawner makes them a new player on their spawn point. What they keep (points, health) is up to you: what is in `MpState` is still there.
3. If they do not come back in time, or never loaded the world (`load_timeout_s`): `player_abandoned(slot)`. What it means (they lose, the match goes on without them) is up to you, as in the example.
4. If the room server goes down, its matches close by themselves within a few seconds (`parent_check_s`).
5. If a match stays empty for `idle_no_players_s`, it closes.

From your own UI, the same as the button: the screen's `rejoin_match()`, or by hand:

```gdscript
var last := MpLobbyLink.client(get_tree()).last_match()   # {host, port, token}
if not last.is_empty():
	MpFlow.find_in_tree(self).join_match(last["host"], last["port"], last["token"])
```

### 9.8 The rooms' transport

It must be the same everywhere: the lobby, every match and every client. With `game.tres` (as the wizard does it) that is already so: the room server uses that transport and passes it to each match, and the client (lobby screen and match) uses the same `.tres`. A `--transport=` flag on the room server wins over both.

## 10. A private match with a code

No VPS and no room server: a dedicated on your PC, and your friends get in with a code.

### 10.1 With the button

1. On the boot's `Menu`, tick `offer_private_server`. (The wizard leaves it ticked.)
2. F5 › **Private server**.
3. The kit starts a dedicated process on your PC (`MpLocalServer`), with as many seats as the game's `max_players`, and joins you to it.
4. In the match, the HUD shows the invite: `Friends join with 192.168.1.5:7800#K7P2QX`. An **MpInviteLabel** shows it: the `MpWorld` has one in `Hud/Invite`; in a world built by hand, add one to the HUD. It shows only on the PC that hosts the private match.
5. Your friends type that in the menu's address field and **Join**. Each seat has its code; with several, they show separated by commas.
6. Someone without a code does not get in.
7. A second click on **Private server** does not start another match: it gives back the one that runs and shows its invite again. Two programs on the same PC can each have their own private match without stepping on each other.

The match uses the same transport as your game (ENet, WebSocket or relay). Over the internet without the relay, your friends need your public IP and the port open on your router. With the relay that is not needed: the IP part is ignored and the port picks the relay room.

### 10.2 By code

```gdscript
var server := MpLocalServer.start_on(get_tree(), 2)
server.server_ready.connect(func(address: String, port: int, codes: Dictionary) -> void:
	print("%s:%d  codes: %s" % [address, port, codes]))
server.server_failed.connect(func(reason: String) -> void: print("failed: ", reason))
```

| Piece | What it is |
|---|---|
| `MpLocalServer.start_on(tree, seats, options, join_host)` | Creates the node under the root and starts. Slot 1 is you |
| `server_ready(address, port, codes)` | Ready. `codes`: slot → code for every other seat |
| `server_failed(reason)` | It could not start |
| `server_ended(result)` | The match ended |
| `stop()` | Kills the match |
| `invites()` / `invite_text()` | What friends type, one per free seat: `192.168.1.5:7801#K7P2QX` (through the relay, `:7801#K7P2QX`) |
| `MpLocalServer.running(tree)` | The private server this process runs, or `null`. `start_on` with one running gives it back |

It uses the times and ports of a default `MpLobbyConfig` (matches on 7800-7899) and the network of your `game.tres` (transport, relay, TLS). Through the relay it searches for a port from a random one in the range, and if the relay refuses it because another server uses it, it tries the next one.

### 10.3 Online rooms your players host (no server of yours)

The same private match, over the internet, with nothing of yours running the matches: a player's game hosts each one. Two small Node servers make it possible, and both fit on the cheapest machines:

- the **relay** (section 12): the tunnel, so nobody needs a public IP or an open port;
- the **issuer** (`addons/mp_kit/issuer`): hands out room codes, gives each player a seat, lists the public rooms, keeps limits and versions, and signs the short tokens the relay asks for.

```
host's game ── create a room ─► issuer ── code K7F3QX + a host token (1 minute, works once)
             └─ hosts room p-K7F3QX on the relay with that token
friend's game ── join K7F3QX ─► issuer ── a seat + a client token
             └─ joins room p-K7F3QX on the relay with that token
```

The relay's secret never leaves the servers: the issuer signs with its **private** key, the relay only holds the **public** one (it can check tokens, not make them). A token works once and dies within a minute, so a leaked one is useless.

How each build hosts:

| Host | How | If it is minimized or its tab hidden |
|---|---|---|
| Desktop | A match process on its PC (`MpLocalServer`, the same code as a VPS); the host joins it like any player | Nothing: the match process has no window |
| Browser | Its own game hosts and plays (a browser cannot start processes) | It keeps simulating: `MpWebKeepAlive` (10.6) |

When it fits: friends, co-op, casual and private rooms. When it does not: competitive matches between strangers (the host's game is the authority: it could cheat, and if it leaves the match ends). Those want a dedicated server (sections 9 and 13).

### 10.4 Setting it up

1. The relay with the issuer's public key, and the issuer with its private key: [issuer/README.md](issuer/README.md) has both, on your machine and on Fly (`node keys.mjs` makes the pair).
2. In your `game.tres` (`MpNetConfig`), group **Online rooms (issuer)**: `issuer_url` = `https://<your-issuer>.fly.dev`, `game_id` = the key of your game in the issuer's `ISSUER_GAMES`. The relay URL comes from the issuer.
3. **Project Settings › Application › Config › Version**: your game's version. Players join only rooms of their own version, and the issuer may refuse versions older than `min_version` ("Update the game").
4. For the web build: the issuer's `ISSUER_ORIGINS` = where your page is served from (`https://my-game.itch.io`).

Try it all on your machine first: `bash mpkit_lab/run/online.sh` in the kit repo runs an issuer and a relay locally and plays through them with a desktop host, a host in its own game (frozen for 3 s mid-match) and a browser host.

### 10.5 In your game

```gdscript
var flow := MpFlow.find_in_tree(self)

## Host: a room for 4 (you count), listed for everyone. The status says the code once it is up.
## The last argument is your match ticket, as for a private match (world, mode, options, seed, each seat's meta).
var online := flow.host_online(4, "Friday night", true, {"mode": "2v2", "options": {"map": "forest"},
	"seats": [{"slot": 1, "meta": {"pick": "mage"}}]})
online.room_ready.connect(func(code: String) -> void: code_label.text = code)
online.failed.connect(func(reason: String) -> void: print("could not open: ", reason))

## A friend with the code (as typed: "k7f-3qx" works).
var err: Error = await flow.join_online(code_field.text)

## The list of public rooms of this game and version with a free seat.
for row in await flow.online_rooms():
	print(row.name, " ", row.players, "/", row.max_players, " ", row.code)
```

| Piece | What it is |
|---|---|
| `flow.host_online(players, name, listed, ticket)` | Opens a room (an `MpOnline` under the root). `listed = false`: private, joined by code only. A second call gives the running one back. `ticket`: your match ticket (world, mode, options, seed, picks…, `seats: [{slot, meta}]` with the host's meta in slot 1): a desktop's match process gets it as its ticket (the kit only adds each seat's token and the relay room: `MpLocalServer.merge_ticket`); in a browser your game is the match and reads it from `MpOnline.ticket` |
| `MpOnline.room_ready(code)` / `failed(reason)` / `ended` | Players may join / the issuer refused or the match could not start / the room is closed |
| `MpOnline.stop()` | Closes the room on purpose (a Close button): the match stops and the issuer forgets the room; `ended` fires, never `failed`. From the match world the host goes back to the menu; from a screen of your game (your room screen, before the match) the scene stays: you decide where to go |
| `MpOnline.code`, `mode` | The code; `dedicated` (desktop) or `listen` (browser). `--online-mode=listen` forces the browser's way on a desktop (tests) |
| `flow.join_online(code)` | A seat from the issuer, then the relay connection. While the room is still coming up it asks again for a few seconds |
| `flow.online_rooms()` | `[{code, name, players, max_players, state, platform, age_s}]` |
| `MpFlow.online_texts` | What the status says for each refusal (`room_full`, `version_mismatch`, `version_too_old`, `too_many_rooms`, `network`…): translate them in the Inspector |
| `MpInviteLabel` | In the match HUD of the host it shows the code |
| `MpNetConfig.can_host_online()` | True once `issuer_url` is set (every build may host, a browser too) |

The room lives while the host does: the host tells the issuer every 10 s who is in, and closes the room when the match ends or it leaves. A host whose game closes without a word (a closed tab) is forgotten by the issuer 30 s later.

Your game's transport does not change: the online room's own connection goes through the relay (`MpTransport.use_relay_room`), so a LAN match or a private server afterwards uses ENet (or whatever your `game.tres` says) as before.

### 10.6 A browser hosts

A browser stops a hidden tab's frames (another tab in front, the window minimized, or covered in Chrome), and a Godot web build runs on those frames: a browser host would freeze its whole match. While a browser hosts, `MpWebKeepAlive` answers those frames from a Web Worker's timer, which the browser does not throttle, and turns drawing off until the tab is visible again. Measured in Chromium: 60 ticks per second with the tab hidden for more than 8 minutes. You do nothing: `host_online()` turns it on and off.

Mobile browsers freeze background tabs entirely; there nothing keeps the host running. For that, and for any host that freezes or whose link stalls, the clients have a safety net: the server beats 4 times a second, and after 1.5 s without a beat a client emits `MpKit.host_silent(seconds)` (and `host_back` when it beats again); `MpFlow` says "Waiting for the host…" (`host_silent_status`) and gives up after `host_silent_timeout_s` (30). Show your own overlay with those signals if you like.

### 10.7 When something fails

| What you see | What to do |
|---|---|
| "This game has no online server (MpNetConfig.issuer_url)" | Set `issuer_url` in your `game.tres` (or `--issuer-url=`) |
| "Online error (unknown_game)" | `game_id` (or, empty, `relay_room`) is not a key of the issuer's `ISSUER_GAMES` |
| "That room runs version X of the game" | The host has another version: both need the same **Application › Config › Version** |
| "Update the game (version X or newer)" | The issuer's `min_version` for your game is newer than this build |
| "You already host a room" | One room per install (`ISSUER_ROOMS_PER_INSTALL`): close it, or wait 30 s after a crash |
| "Cannot reach the online server" | The issuer's address, or (web) its `ISSUER_ORIGINS` does not list the page's origin: the browser blocks the call |
| The room never shows in the list | It is still coming up (the host is not on the relay yet), it is private, or it is full |
| The relay log says `refused for p-…: no RELAY_TOKEN_KEYS set` | The relay has no public key of the issuer: set `RELAY_TOKEN_KEYS` and redeploy it |
| The relay log says `… bad token` | The relay's public key is not the issuer's (made by another `keys.mjs` run) |

## 11. Web

### 11.1 What changes

A browser can neither open a server nor use UDP. So:

- A web export uses **WebSocket**: direct, or through the relay when `game.tres` says `transport = relay`. With `enet` in the `.tres` it uses WebSocket directly, because a browser has no ENet.
- It can neither host nor browse LAN rooms: the menu hides **Host LAN**, **Private server** and the LAN list. If something calls `host_lan()`, the status says *This build cannot host (web): join a server*.
- It only joins: a WebSocket dedicated or room server, or any server through the relay.

### 11.2 Why it does not mix with desktop

A WebSocket server only serves WebSocket clients, and an ENet one only ENet. If you want web and desktop in the same match, use WebSocket for everyone (`transport = ws` in `game.tres`), or the relay for everyone.

### 11.3 Exporting

1. Copy the *Web* preset from `addons/mp_kit/deploy/export_presets.example.cfg` into your `export_presets.cfg` (or create it in **Project › Export**).
2. It has no threads (`variant/thread_support=false`): any static hosting works, with no special headers.
3. Export to `build/web/index.html` and upload it to your hosting.
4. The server: a dedicated (or a room server) with `transport = ws`, or any server through the relay.

### 11.4 `wss://` and TLS

A page served over `https://` **cannot** open `ws://` (unencrypted): it needs `wss://`. Three paths:

**Path 1: TLS in Godot.**

On the server, one of these:

| Where | What to set |
|---|---|
| The dedicated's `game.tres` | `tls_certificate` (`X509Certificate`) and `tls_key` (`CryptoKey`). The matches of a room server get them as files: in an export, the kit copies them to `user://` |
| The dedicated's flags | `--tls-certificate-path=/path/fullchain.pem --tls-key-path=/path/privkey.pem` |
| `MpLobbyConfig` (rooms) | `tls_certificate_path` and `tls_key_path`. The lobby listens on `wss://` and every match gets the same certificate. Empty = `game.tres`'s `tls_*` |
| `deploy.sh` | `--transport ws --tls-cert … --tls-key …` (see [13](#13-putting-it-on-a-vps)) |

On the client:

| Where | What to set |
|---|---|
| The client's `game.tres` | `tls_client` = on. `tls_trusted_ca` empty for a normal certificate (Let's Encrypt). `tls_common_name` only if the certificate has another name than the address |
| Flags | `--tls-client`, `--tls-trusted-ca=file.pem`, `--tls-common-name=name` |

The address must be the certificate's **domain** (`game.example.com:7700`), not an IP. The lobby screen takes the transport and TLS from the flow's `game.tres`.

**Path 2: a reverse proxy.** nginx or Caddy terminate TLS on port 443 and forward to the local WS port. The game does not change. The menu's address field takes a whole URL: `wss://game.example.com/path`. Details in [README.md](README.md) (the *wss:// (TLS) for the VPS* section).

**Path 3: the relay.** The relay on Railway already has `wss://` with its domain; your Godot server connects to it. See [12](#12-relay-a-tunnel-through-railway-or-another-host). A web export with `transport = relay` uses it directly.

### 11.5 A hidden tab

A browser pauses a hidden tab. A web player who switches tabs freezes for the others until they come back. In a room match, staying away longer than `rejoin_grace_s` counts as abandoning it.

## 12. Relay (a tunnel through Railway or another host)

The relay is a small Node server (`relay/server.mjs`, Node 18+ and the `ws` library: `npm install` once) that works as a tunnel. Your Godot server connects **out** to the relay, so it needs no public IP nor open ports: it can run on your PC behind the router. The players connect to the same relay.

```
player ─┐
player ─┼── wss://your-relay.up.railway.app ──── Godot server (your PC, a VPS, anywhere)
player ─┘          (room my-game-7777)             connects as the room's host
```

Every kit "port" is a relay room: `<relay_room>-<port>`. So the lobby (7700) and every match are different rooms. Online rooms, matches and private matches work the same through the relay.

### 12.1 Putting the relay on Railway

1. Make a repo (or a folder in yours) with `server.mjs`, `lib/`, `package.json` and `package-lock.json` from `addons/mp_kit/relay/`.
2. On Railway: **New Project › Deploy from GitHub repo** and pick that repo. Railway installs the dependency and runs `npm start`.
3. Under **Variables**: `RELAY_HOST_SECRET` = a long random key. Without it the relay lets nobody host (`RELAY_OPEN=1` opens it, for local tests only).
4. Under **Settings › Networking**: **Generate Domain**. You get `your-relay.up.railway.app`, with TLS: the address is `wss://your-relay.up.railway.app`.
5. Optional: a healthcheck on the `/health` path.

Try it locally first:

```bash
npm install --prefix addons/mp_kit/relay   # once
PORT=8080 RELAY_HOST_SECRET=test node addons/mp_kit/relay/server.mjs
# address: ws://127.0.0.1:8080
```

Or on **Fly.io**, with a region near your players (`gru` = São Paulo; Railway has none in South America): the steps, the `Dockerfile` + `fly.toml` and every useful command (deploy, logs, secrets, stop) are in [relay/README.md](relay/README.md).

### 12.2 Setting up the game

In the game's `game.tres` (or the `MpNetConfig` you use):

| Field | Value |
|---|---|
| `transport` | `relay` |
| `relay_url` | `wss://your-relay.up.railway.app` |
| `relay_room` | your game's name (`my-game`) |

The secret does **not** go in the `.tres` (it travels with the clients). The server gets it from the environment or a flag:

```bash
MPKIT_RELAY_SECRET=the-key godot --headless --path . -- --dedicated      # a dedicated
MPKIT_RELAY_SECRET=the-key godot --headless --path . -- --room-server    # rooms: lobby and matches through the relay
```

The Godot server uses `MPKIT_RELAY_SECRET` (or `--relay-secret=`); the relay uses `RELAY_HOST_SECRET`. They must have the same value.

The matches a room server starts inherit the secret and the relay settings by themselves. The players need nothing: the menu joins with the usual address. Through the relay the host part is ignored and the port counts, which picks the room (`127.0.0.1:7777` enters `my-game-7777`). A whole URL in the field (`wss://another-relay…`) uses that relay.

Equivalent flags: `--transport=relay --relay-url=wss://… --relay-room=my-game --relay-secret=…`.

To try it all together on your PC: `mpkit_lab/run/play.sh dedicated --relay` or `mpkit_lab/run/play.sh rooms --relay`.

### 12.3 What it does and does not

- It passes packets between a room's host and its clients, all over WebSocket (reliable and ordered).
- A room with a live host is taken, like a port in use: a second host is refused (4009). A room or private match tries the next port; a dedicated or a lobby says so and stops. Each server searches for a port from a random one, so two players with a private match rarely meet.
- A host that does not answer the relay's pings for 15 s is dropped and its room is free. A refused host retries for 3 s before giving up, so a server that restarts at once gets its room back; a room server's matches retry for 0.5 s and move to the next port.
- A client of a room without a host is refused; when the host leaves, its clients are closed.
- Limits, through the relay's variables: `RELAY_MAX_CLIENTS` per room (64), `RELAY_MAX_MESSAGE` in bytes (262144).
- It stores nothing, it never sees the game. The latency is the relay's in the middle: pick a region near your players.
- Web: a web export with `transport = relay` uses the relay (it is WebSocket). With `enet` in the `.tres`, the browser uses WebSocket directly, because it has no ENet.
- The host sends the secret in the `X-Relay-Secret` header, not in the URL: it never lands in access logs.

Protocol and details: [relay/README.md](relay/README.md).

## 13. Putting it on a VPS

One Linux binary does everything: client, room server (`--room-server`) and every match (`--dedicated`). If you would rather open no ports, the server can run anywhere behind the relay ([12](#12-relay-a-tunnel-through-railway-or-another-host)). With no VPS at all, on Fly.io: [13.6](#136-without-a-vps-flyio).

### 13.1 What you need

- A Linux x86_64 VPS with systemd (Ubuntu or Debian) and a user with `sudo` you reach over SSH.
- On your PC, the Linux export templates of your Godot version (**Editor › Manage Export Templates**).
- In the project: a `game.tres` with `rooms_scene` (if you use rooms) in the boot's `MpFlow`.

### 13.2 Exporting

1. Copy the *Linux Server* preset from `deploy/export_presets.example.cfg` into your `export_presets.cfg`. It is a normal Linux export (not the *Dedicated Server* mode: the match needs collisions and the whole world).
2. Export:

```bash
godot --headless --path . --export-release "Linux Server" build/server/game.x86_64
```

You get `game.x86_64` and `game.pck`, which go together.

### 13.3 Upload and install with `deploy.sh`

```bash
addons/mp_kit/deploy/deploy.sh user@my-vps build/server --rooms 7700 --open-firewall
```

That:

1. Creates the system user `game` (the name comes from the binary).
2. Copies the build to `/opt/game`.
3. Installs the `game-rooms@.service` and `game-dedicated@.service` units.
4. Starts `game-rooms@7700`: lobby on 7700, matches on 7800-7899.
5. With `--open-firewall`, opens the ports with `ufw`.

Run it again to update: it copies what is new and restarts.

| Option | What it does | Default |
|---|---|---|
| `--name NAME` | The service and user name (lower case, digits, `-`, `_`) | the binary without `.x86_64` |
| `--rooms 7700,7701` | One room server per port. Each with 100 match ports: 7800-7899, 7900-7999… | `7700` when neither `--rooms` nor `--dedicated` is given |
| `--dedicated 7777,7787` | Dedicated servers without a lobby, one per port (join with IP and port). With only this, no rooms are installed | none |
| `--transport enet\|ws\|relay` | Passed to every instance | what the build says |
| `--relay-url URL` / `--relay-room NAME` | The relay and its rooms' prefix, if not the build's. The secret comes from `MPKIT_RELAY_SECRET` on your machine | — |
| `--tls-cert PATH` / `--tls-key PATH` | `wss://` with that PEM certificate and key. They go together and need `--transport ws` | — |
| `--open-firewall` | Opens the ports with `ufw` (UDP with ENet, TCP with WebSocket; the lobby and its matches alike; nothing with the relay) | off |
| `--dry-run` | Only prints the commands, does not run them | off |

Dedicated only, no rooms:

```bash
addons/mp_kit/deploy/deploy.sh user@my-vps build/server --dedicated 7777,7787 --open-firewall
```

Do not use 7778-7781 for dedicated servers: those are the LAN search ports.

Always try it first with `--dry-run`.

Web over https:

```bash
addons/mp_kit/deploy/deploy.sh user@my-vps build/server --rooms 7700 --transport ws \
  --tls-cert /etc/letsencrypt/live/DOMAIN/fullchain.pem \
  --tls-key /etc/letsencrypt/live/DOMAIN/privkey.pem --open-firewall
```

The service user must be able to read the certificate and key (with Let's Encrypt, for example, a group with permission on `/etc/letsencrypt/live` and `archive`).

The relay on a VPS: the VPS needs no open ports, because the server connects out. `--open-firewall` opens nothing with the relay.

```bash
MPKIT_RELAY_SECRET=the-key addons/mp_kit/deploy/deploy.sh user@my-vps build/server --rooms 7700 \
  --transport relay --relay-url wss://your-relay.up.railway.app
```

`deploy.sh` takes `MPKIT_RELAY_SECRET` from **your** machine and writes it to `/etc/game/relay.env`, which only the service user reads. Without it, that file stays as it was: a redeploy never deletes the secret. `--relay-room` changes the rooms' prefix if you do not want `game.tres`'s.

### 13.4 Several instances

- Several matches at once on a room server: automatic, up to `max_matches`.
- Several room servers on the same VPS: `--rooms 7700,7701,7702`. Each has its own port range and matches folder.
- A different number for one instance: edit `EXTRA_ARGS` in `/etc/game/rooms-7700.env` (e.g. `--max-matches=8`) and restart it.

### 13.5 Operating

```bash
ssh user@my-vps journalctl -u 'game-rooms@*' -f        # live logs
ssh user@my-vps journalctl -u 'game-dedicated@*' -f    # logs of plain dedicated servers
ssh user@my-vps sudo systemctl restart game-rooms@7700  # restart one
ssh user@my-vps sudo systemctl disable --now game-rooms@7701   # turn one off
```

If the room server goes down, systemd brings it back. Its matches close by themselves within a few seconds.

On the clients, put the VPS's address in `game.tres`'s `public_host` (e.g. `game.example.com`): the menu and the lobby screen start with it. For plain dedicated servers, players type `game.example.com:7777` in the menu.

More detail: [deploy/README.md](deploy/README.md).

### 13.6 Without a VPS: Fly.io

Fly.io runs your game's server as a small machine you never log into: no VPS to keep up, no export templates, no port to open. The server connects **out** to your relay ([12](#12-relay-a-tunnel-through-railway-or-another-host)), so players reach it through the relay as always. Your game ships with no key in it: only the server holds the relay's secret.

```
players ──── wss://my-relay.fly.dev ──── your game server on Fly
              (the relay, section 12)     (a room server: lobby + its matches)
```

**What you need**

- The relay running (section 12), its address (`wss://my-relay.fly.dev`) and its host secret (`RELAY_HOST_SECRET`).
- A Fly.io account and `flyctl` installed: `brew install flyctl` on macOS, or the line for your system on fly.io/docs/flyctl/install. Then log in once: `fly auth login`.
- Your project with the rooms set up (section 9): `game.tres` with `rooms_scene`. For a plain dedicated, nothing more.

**1. Deploy (one command, from your project folder)**

```bash
MPKIT_RELAY_SECRET=<the relay's secret> addons/mp_kit/deploy/fly.sh --app my-game-server --relay-url wss://my-relay.fly.dev
```

What it does, in order:

1. Writes `fly.toml` in your project folder (from `addons/mp_kit/deploy/fly/fly.toml`) with your app name, region (`gru`, São Paulo, unless `--region`), Godot version (the `godot` in your PATH, or `--godot 4.7.2`) and the server's flags. Commit it with your game; edit it by hand later if you like.
2. Creates the app on Fly if it does not exist yet (app names are global on Fly: pick one of your own).
3. Stores the secret as a Fly secret, `MPKIT_RELAY_SECRET`, through stdin: it never lands on a command line, in `fly.toml` or in the image.
4. Builds the image on Fly's builders (`addons/mp_kit/deploy/fly/Dockerfile`): it downloads the official Godot for Linux of that version, checks it against the release's `SHA512-SUMS.txt`, copies your project and imports it once.
5. Starts one machine, always on, that runs `godot --headless --path /app -- --room-server …`.

Try it first with `--dry-run`: it prints every command and changes nothing.

| Option | What it does | Default |
|---|---|---|
| `--app NAME` | The Fly app (lower case, digits, `-`) | required |
| `--relay-url URL` | The relay. Without it, your `game.tres` must already say `transport = relay` with its `relay_url` | — |
| `--relay-room NAME` | The relay rooms' prefix, if not your `game.tres`'s | the game's |
| `--region CODE` | Where the machine runs; the one nearest your players and your relay (`fly platform regions`) | `gru` |
| `--rooms PORT` | A room server (lobby + matches) on this kit port | `7700` |
| `--dedicated PORT` | A plain dedicated instead (one match, players join with the port) | — |
| `--godot X.Y.Z` | The Godot version of the image: the one your project uses | the `godot` in PATH |
| `--memory SIZE` | The machine's memory. A room server runs one process per match: more matches at once, more memory | `1gb` |
| `--dry-run` | Only prints the commands | off |

**2. Check that it runs**

```bash
fly logs --app my-game-server        # look for: rooms ready port 7700 (relay)
fly status --app my-game-server      # one machine, started, in your region
fly logs --app my-relay              # the relay shows: host my-game-7700
```

**3. Players**

Nothing to do: with `transport = relay` in `game.tres`, the game's **Online** button goes to the lobby through the relay. Rooms, private rooms with a code and matches work as in section 9.

**4. Update**

Run the same command again after changing the game: it builds a new image and replaces the machine (the matches running then end; players rejoin the lobby). Without `MPKIT_RELAY_SECRET` set, the secret on Fly stays as it was.

**Cost**

One machine always on: with `--memory 1gb` about USD 6 a month (fly.io/pricing has each region's price), plus outbound traffic (the arena example moves about 0.15 GB per player per hour; the matches' traffic goes out through the relay, which bills its own). `512mb` fits a dedicated or a room server with a few small matches.

**Useful commands**

```bash
fly logs --app my-game-server                 # live log: rooms, matches, results
fly status --app my-game-server               # the machine and its state
fly apps restart my-game-server               # restart it (matches end, the lobby comes back)
fly secrets set --app my-game-server MPKIT_RELAY_SECRET=<new>   # after changing the relay's secret
fly scale memory 2048 --app my-game-server    # more memory for more matches at once
fly scale count 0 --app my-game-server        # stop it (no machine billed); count 1 starts it again
fly apps destroy my-game-server               # remove it for good
```

**If something fails**

- `lobby port 7700 is in use on the relay`: another room server of the same game holds that relay room (your PC, an older app). Stop it, or use another `--rooms` port or `--relay-room`.
- The relay's log (`fly logs --app my-relay`) says `host refused for my-game-7700: wrong secret`: the secret on Fly is not the relay's. Set it again (`fly secrets set …`).
- The machine restarts with `out of memory`: more `--memory` (or fewer `max_matches`).
- `no godot in PATH`: pass `--godot 4.7.2` (the exact version your project uses; Fly downloads that one).

**Try it all on your PC first** (with Docker): [13.7](#137-your-server-in-docker-on-your-pc-end-to-end), the same image with a local relay and two windows.

### 13.7 Your server in Docker on your PC, end to end

Before putting the server on Fly (13.6), or to reproduce a problem, run the whole path on your own PC: a relay, your game's server in a container (the same image Fly runs), and two windows of the game that play through them. Four terminals, all opened in your project folder.

```
window 1 ─┐                                       ┌── container: your game's server
window 2 ─┴── ws://127.0.0.1:8080 (relay, your PC) ┘   (it reaches the relay as ws://host.docker.internal:8080)
```

**What you need**

- Docker running: Docker Desktop on macOS or Windows (open it once), Docker Engine on Linux. `docker info` must answer without errors.
- Node 18 or newer (for the relay): `node --version`.
- Godot on your PC, the same version as your project (`godot --version`; on macOS the binary is `/Applications/Godot.app/Contents/MacOS/Godot`).
- Your project with rooms (section 9), or a plain dedicated (step 6).

**1. The relay (terminal 1)**

```bash
npm install --prefix addons/mp_kit/relay      # only the first time
PORT=8080 RELAY_HOST_SECRET=local-test node addons/mp_kit/relay/server.mjs
```

You see `[relay] ready port 8080`. Leave it open: it prints every host and player that comes in. `local-test` is the host secret for this test only.

**2. Build the server image (terminal 2)**

```bash
docker build -f addons/mp_kit/deploy/fly/Dockerfile --build-arg GODOT_VERSION=4.7.2 -t my-game-server .
```

Use your project's Godot version. The first time takes a minute or two: it downloads the official Godot for Linux, checks it against the release's SHA-512 sums, copies your project and imports it. It ends with `naming to docker.io/library/my-game-server`. Run it again after every change to the game.

**3. Start the server (terminal 2)**

```bash
docker run --rm --name my-game-server --add-host=host.docker.internal:host-gateway \
  -e MPKIT_RELAY_SECRET=local-test \
  -e GAME_ARGS="--room-server --lobby-port=7700 --match-port-min=7800 --match-port-max=7899 --matches-root=/home/game/matches --transport=relay --relay-url=ws://host.docker.internal:8080 --relay-room=my-game" \
  my-game-server
```

- `host.docker.internal` is your PC as seen from inside the container; `--add-host` makes it work on Linux too.
- `MPKIT_RELAY_SECRET` must be the relay's `RELAY_HOST_SECRET`.
- `GAME_ARGS` are the kit's flags, the same ones `fly.toml` uses.

You see `rooms ready port 7700 (relay)`, and terminal 1 shows `[relay] host my-game-7700`: the server is in.

**4. Two players (terminals 3 and 4)**

```bash
godot --path . -- --transport=relay --relay-url=ws://127.0.0.1:8080 --relay-room=my-game
```

Run that line in two terminals: two windows. In each, **Online rooms** opens the lobby screen; connect (the address can stay as it is: through the relay the port, 7700, picks the room). In one window **Create room**; in the other, pick the room in the list and join. Both press **Ready**: the room server starts the match **inside the container** (terminal 2 shows `match for room "…" on port 78xx`) and both windows go into it. When it ends, both come back to the lobby with the result.

From the editor instead: put `transport = relay`, `relay_url = ws://127.0.0.1:8080` and `relay_room = my-game` in `game.tres` (only while you test), **Debug › Run Multiple Instances › 2** and F5.

**5. Stop**

`Ctrl+C` in each terminal. The container removes itself (`--rm`); if you started it in the background (`docker run -d …`), `docker stop my-game-server`. When you are done, quit Docker Desktop (or `docker desktop stop`).

**6. A plain dedicated instead of rooms**

In step 3, `GAME_ARGS="--dedicated --mp-port=7777 --transport=relay --relay-url=ws://host.docker.internal:8080 --relay-room=my-game"`. Terminal 1 shows `[relay] host my-game-7777`. In each window type `127.0.0.1:7777` in the menu's address field and **Join** (through the relay the port picks the room).

**7. Then on Fly**

The same image, built by Fly: `addons/mp_kit/deploy/fly.sh --app … --relay-url wss://…` (13.6). Locally you used `ws://` to the relay on your PC; on Fly it is your relay's `wss://` address.

**If something fails**

| What you see | What to do |
|---|---|
| `Cannot connect to the Docker daemon` | Docker is not running: open Docker Desktop (or `sudo systemctl start docker` on Linux) |
| The build stops at `the project did not import` | The errors above it say why: usually a script error. Your project must run with `godot --headless --path .` on your PC first |
| Terminal 1 never shows `[relay] host my-game-7700` | The container does not reach your PC: keep `--add-host=host.docker.internal:host-gateway` and the same port (8080) in `--relay-url` |
| Terminal 1 shows `host refused for my-game-7700: wrong secret` | `MPKIT_RELAY_SECRET` (container) is not `RELAY_HOST_SECRET` (relay) |
| The windows never reach the lobby | Same `--relay-room` (`my-game`) in the windows and the server; the windows use `ws://127.0.0.1:8080`, the container `ws://host.docker.internal:8080` |
| `lobby port 7700 is in use on the relay` | Another room server of `my-game` is on that relay (an older container, the editor): stop it, or use another `--relay-room` |
| The server ran in the background and you want its log | `docker logs -f my-game-server` |

For the kit's own repo there is an automatic version of all this: `bash mpkit_lab/run/docker.sh` builds the image from the lab, runs a dedicated and a room server in containers behind a local relay, plays through both and prints `MPKIT DOCKER PASS` (or `SKIP` without Docker).

## 14. Security and limits

### 14.1 What the kit already sets

| What | Limit |
|---|---|
| `to_server` / `mp_sv_*` | With `callers = OWNER`, only the owner (and with `owner_slot` = 0, nobody but the server). With `ANYONE`, any player with a slot. Only methods starting with `mp_sv_` and taking that many arguments. Arguments up to 4 KB. Up to 60 per second per client (bursts of 120), adding up all their `MpActor`s |
| `to_all` / `mp_all_*` | Only the server sends them |
| `MpInput` | Only the owner sends frames. Frames up to 1 KB, with checked types, each action's strength between 0 and 1, up to 16 values of your own. A client that sends extra frames does not move faster |
| `Dictionary` tunnel | Messages up to 8192 bytes, 30 per second (bursts of 60) |
| Ticket admission (room and private matches) | Only the seat's tickets get in. Tickets up to 512 characters. No ticket within 5 s, out. Up to 64 connections waiting for a ticket at once |
| Lobby | Checks the version, the name (24 characters), the size of options and picks (2048 bytes), the chat rate, and the time to say hello (`hello_timeout_s`). The client never picks the slot, port or seed |
| Slots | The server assigns them. The client never says "I am number 2" |
| Lag compensation | It never rewinds more than a second (as Valve's `sv_maxunlag`): a view time further back, or ahead of now, is clamped |
| Relay | Only whoever has the secret hosts (`RELAY_HOST_SECRET`); it travels in a header, never in the URL. The secret never goes in the `.tres`. A room with a live host cannot be taken over |
| Rooms players host (issuer) | Hosting and joining a player's room each need an issuer token for that room and role: signed with the issuer's private key (Ed25519), checked by the relay with the public one, good once and for a minute. The issuer limits rooms per IP and install, requests per minute, game versions and web origins; the IP comes from the connection (on Fly, `Fly-Client-IP`), never from the client |

### 14.2 What your game must check

1. **The arguments of every `mp_sv_*`.** They come from the client: they may be of any type. Check the type and the range.

```gdscript
func mp_sv_buy(item: Variant) -> void:
	if typeof(item) != TYPE_STRING or not SHOP.has(item):
		return
	# ...
```

2. **The values of `input.get_value`.** The client sends them too. If a vector must be a direction, normalize it and have a default, as the example's `aim` ([6.5](#65-values-of-your-own-set_value--get_value)).
3. **Room picks and options** in `MpRoomRules.accept_pick` and `accept_options`.
4. **That the request makes sense in the game**: the player has the money, is next to the door, is not dead. The kit knows who asked (`sender_slot()`), not whether the request is fair.
5. **Nodes with `callers = ANYONE`**: any player can call their `mp_sv_*`. Do not put there anything only one should do.
6. **A relay without a secret lets nobody host.** For tests on your machine there is `RELAY_OPEN=1`; on Railway, always `RELAY_HOST_SECRET`.

Never send bullet or character types as text over the network: use a `Resource` on the actor.

## 15. Common problems

### Editor warnings (a yellow triangle on the node)

**"Save the scene: the MpSync child is built in the editor."** (on `MpActor` or `MpState`)
1. Open the actor's scene (not the world's).
2. Save it (Ctrl+S).
3. If it stays: the `MpActor` was added on top of an instance in another scene. Move it into the actor's scene.

**"MpActor goes inside the node the network shares (not as a scene root)."**
The `MpActor` is the scene's root. It must be a child of the shared node (the `CharacterBody2D`, the bullet).

**"Predict is on: the parent needs func mp_move(input: MpInput, delta: float)."**
Add `func mp_move(keys: MpInput, delta: float) -> void:` to the parent's script, or turn `predict` off.

**"Put an MpActor next to this MpInput (same parent)."**
The `MpInput` must be a sibling of an `MpActor`, or have `actor` set.

**"Set Player Scene: the scene every seat gets (it needs an MpActor)."** (on `MpWorld`)
Set `player_scene` on the `MpWorld`.

### Errors while playing (Debugger panel)

**"MpActor on 'X': no MpSync child. Open the scene in the editor and save it (the editor builds it)."**
The same as the first warning: open and save the actor's scene.

**"MpWorld 'X': no Y child. Open the scene in the editor and save it (the editor builds it)."**
A piece of the `MpWorld` is missing (renamed, or the scene was never opened in the editor). Open the world scene and save it: the `MpWorld` builds what is missing.

**"MpActor on 'X': predict needs an MpInput next to it and mp_move(input, delta) on the parent"**
The `MpInput` or `mp_move` is missing. The kit turns `predict` off for that node and carries on.

**"MpInput 'X': no MpActor next to it"**
See above.

**"MpActor 'X': to_server(y) from a peer that does not own it (callers = OWNER)"**
A player called `to_server` on a node that is not theirs. If it is another player's, put the call behind `if net.is_local():`. If it is a world object anyone uses (door, bell), set `callers = ANYONE` on its `MpActor`.

**"MpActor 'X': no mp_sv_y() taking N arguments"** (or `mp_all_y`)
The name or the number of arguments does not match. `to_server(&"buy", item)` needs `func mp_sv_buy(item)`. No prefix in the call: `&"buy"`, not `&"mp_sv_buy"`.

**"… only runs on the server"** (`to_all`, `despawn`, `MpState.set_value`, `MpMatch.finish`, `spawn_actor`)
You called it on a client. Put it behind `if net.is_authority():` (or `Mp.is_server()`).

**"MpActor 'X': despawn() on a node of the world scene; hide it (sync visible) or spawn it"**
That node is saved in the world scene: it cannot be removed for everyone. Hide it with `sync_visible`, or make it appear through an `MpSpawner` to be able to remove it (see [7.3](#73-removing-things)).

**"MpSpawner 'X': add res://… to Extra Scenes"**
Add that scene to the spawner's **Extra Scenes**, in the editor.

**"MpSpawner 'X': set spawn_path to the parent of replicated actors"** / **"spawn_path does not resolve"**
Point `spawn_path` at the empty node where things appear (`../Actors`, `../Projectiles`).

**"MpSpawner 'X': spawn_function was set after the scene was set up; set it in a _ready"**
Set `spawn_function` in a `_ready` of the scene (the spawner's, a sibling's or the parent's), not later.

**"MpSlotSpawner 'X': assign pawn_scene"**
Set the player's scene.

**"MpSpawner 'X': … was added after its node was set up. Put synchronizers in the scene (or add them before add_child): the spawn packet and late joiners miss it."**
A `MultiplayerSynchronizer` was added late by code (with a timer, deferred). Put it in the scene, or in the actor's own `_ready`.

**"MpFlow: two flows (… and …); the one already running stays, this one's settings are ignored"**
You have two `MpFlow`s of different origins, for example an autoload (from *New session flow...*) and the boot's node. The one already running wins and what you set on the other is not used. Keep only one. (If it is the same boot loaded again, it does not warn: that is normal.)

**"MpKit.host_dedicated failed: …"** / status **"Could not host (port busy?)"**
The port is taken: another open server, or another instance. Close it or use `--mp-port=N`.

**"MpRoomServer: lobby port 7700: …"**
The lobby's port is taken. Close the other room server or use `--lobby-port=N`.

**"MpLanBeacon: UDP 7778-7781 are all taken (4 game windows browsing?): this LAN list stays empty"**
More than 4 windows are browsing LAN rooms on the same PC, or another program uses those ports. Close windows or type the IP by hand.

**"--transport=x: unknown, ENet is used"**
Valid values: `enet`, `ws` or `relay` (`udp`, `websocket`, `wss`, `tunnel` are accepted too).

**"MpTransport: the relay transport needs a relay URL (--relay-url=wss://… or MpNetConfig.relay_url)"**
With `transport = relay`, set `relay_url` in `game.tres` or pass `--relay-url=`.

**"MpRelayPeer: the relay closed the host (…)"**
The relay cut your server off. Common causes:
- The secret does not match (the server's `MPKIT_RELAY_SECRET` ≠ the relay's `RELAY_HOST_SECRET`): the relay does not even accept the connection.
- The relay restarted or went down.

**"MpRelayPeer: the relay room is in use by another host (like a port in use)"** / **"MpFlow: port N is in use on the relay …"** / **"MpRoomServer: lobby port N is in use on the relay …"**
Another server of the same game holds that relay room (the same `relay_room` and port). A room or private match tries another port by itself; a dedicated or a lobby stops. Use another port or another `relay_room`. If it is your own server that restarted, the kit retries for 3 s and the relay drops a silent host after 15 s.

**"MpTransport: cannot load TLS certificate … / key …"**
The path is wrong or the service user cannot read the file.

**"MpLobbyScreen: no MpFlow in the tree to join the match"**
You opened the lobby scene directly. Start from the boot (F5), which has the `MpFlow`.

**"MpMatchAgent: unusable ticket …"**
The match process could not read its ticket. That happens when you start it by hand with an old match's `--match-ticket-file`. The room server starts the matches.

**"MpKit: setup failed (…)"** / the **Create** button disabled
Some file of the folder already exists (`[~]`) or the folder does not start with `res://`. Pick another folder.

### Behaviors

**My player does not move on the client.**
1. Are the actions you use in `MpInput.actions`? If not, the server reads 0.
2. Do you read `input` (or `keys` in `mp_move`) and not `Input`? `Input` on the server reads the server's keyboard.
3. With `predict` and no `mp_move`? Look at the debugger's error: the kit turned prediction off.
4. Without `predict`, do you move behind `is_authority()`? If you move behind `is_local()`, the client moves on its screen but the server puts it back.
5. Is `sync_position` ticked? Did you save the player scene after ticking it?
6. Does the `MpSlotSpawner` (the `MpWorld`'s `Players`) have `spawn_path` and `pawn_scene`?
7. Is the match waiting for seats? The world is paused until the seats it expects load (`MpMatch.waiting`, `Mp.gate().is_waiting()`). It starts by itself once `load_timeout_s` passed; in Host LAN press **Start now** (`MpStartButton`), or try `--start-seats=1`.

**A client is turned away right away with `timeout`, only against a remote server or relay.**
The server's log says `MpKit: the server turned peer N away (timeout)`: its ticket did not arrive in `admission_timeout_s`. The kit's network timeouts count real time, so a far server is fine. If the server runs your own timers for network things, use `MpKit.after_real(seconds, callable)`, not `create_timer`: with `--fixed-fps` (it stops syncing to the clock and can run thousands of frames a second) or `Engine.time_scale`, game time is not real time.

**A second client does not get in: "The match already started" (`match_started`).**
The gate already started the match: after the start only a seat that left comes back. For several to get in, have them load before the start (`start_seats` = 0 waits for every seat, `--start-seats=N`), or turn on `late_join` (`--late-join`) for a game people drop in and out of. On a dedicated by hand, the next match opens by itself once this one ends and everyone left.

**It moves, but the other players stutter.**
Use `smoothing = BUFFERED` with `adaptive_buffer` on; if it stays, lower `late_tolerance` (0.01) or raise the `buffer_delay_s` cap (0.15, 0.2). If you lowered `send_hz`, raise it or leave it at 0.

**The others look far behind, even on a good network.**
Check that `adaptive_buffer` is on. Off, they are always drawn the whole `buffer_delay_s` behind.

**My player answers late.**
Turn on **Prediction › predict** and move the movement into `mp_move`.

**With gravity or inertia, my player gets corrected often.**
Add `velocity` (and whatever `mp_move` reads) to **Sync › sync_extra**. See [6.2](#62-mp_move-and-its-rules).

**Shots miss what was on the shooter's screen.**
Check the hit against what the shooter saw: `net.rewound(func)`, `net.seen_position_of(node)`, or, for a projectile, `net.view_lag()` as the example's `shot.gd` does ([6.8](#68-more-of-the-mpactor)).

**A late joiner does not see X.**
- If you made X with `to_all`: it is a one-off effect, it does not stay. Use a property in **Sync › Extra** or `MpState`.
- If X is a property: add it to the `MpActor`'s **Sync** and save the scene.
- If you changed `state.values` by hand: use `set_value`.
- If you add the synchronizer late by code: see the spawner's error above.
- If X is a node you added with `add_child` under `spawn_path`: it is not replicated. Use `spawn_actor` with the scene in **Extra Scenes**.

**I cannot find the LAN room.**
1. The list only shows **Host LAN** matches (not dedicated or private ones).
2. `game.tres`'s `lan_discovery` and the `Flow`'s `advertise_lan` must be on, on the host.
3. The announcement goes by UDP broadcast to ports 7778-7781: both PCs' firewalls must let it through, and they must be on the same network (it does not work over the internet nor across subnets).
4. More than 4 windows on the same PC: see the `MpLanBeacon` warning above.
5. On the web there is no LAN list.
6. You can always type the IP the host sees under its list.

**"Invalid address (an IP or a name, optionally :port)" in the status.**
The address is mistyped: a port outside 1-65535, a name with odd characters, or empty. Valid formats: `192.168.1.5`, `game.example.com`, either with `:port`, `ip:port#CODE` or a `ws://…` / `wss://…` URL. On the lobby screen the same error says *Invalid lobby address*.

**"Could not join" / it stays on "Connecting to …".**
- Is the server running, on that port?
- The same transport on both? An ENet client does not talk to a WebSocket server.
- Do the firewall and the router let the port through (UDP with ENet, TCP with WebSocket)?
- Is it full? Past `max_players`, the server cuts the connection.
- With the relay: is the server connected to the relay yet? A client of a room without a host is refused.

**The web build does not connect over https.**
1. The page is `https`: it needs `wss://`. Turn on `tls_client` in the client's `game.tres`.
2. The server must have a certificate and key (see [11.4](#114-wss-and-tls)), or a reverse proxy.
3. Use the certificate's domain, not the IP.
4. The server must be WebSocket (`transport = ws`), the room server too, or go through the relay.

**"Lost the server".**
The server closed or the network dropped. The flow goes back to the boot (or to the lobby if the match came from a room, where **Back to the match** shows up if it is still running).

**Refused when entering a room or private match (`rejected`, `slot_taken`, `slot_out_of_range`, `timeout`, `dropped`).**
- `rejected`: the ticket or code is not valid (expired, from another room, mistyped, or past the grace).
- `slot_taken`: another connected peer has that seat.
- `slot_out_of_range`: the ticket asks for a slot the match does not have. It should not happen with the kit's matches (they are sized from the ticket); check your own `admission` or `build_ticket`.
- `timeout`: it did not present a ticket in time.
Listen to them with `MpKit.admission_rejected`.

**The lobby says `Error: bad_meta`.**
Your `accept_pick` refused the pick. Check the lobby screen's `default_pick` or call `set_pick` with something valid.

**The room match does not start.**
Every seat must be taken and **Ready**. Look at the room server's log: if it says `match … failed …`, the match process did not start (port, `max_matches`, the executable). With `--keep-match-files` that match's log stays.

**I do not see the code of my private match.**
The match HUD shows it with an **MpInviteLabel** (in the `MpWorld`'s `Hud/Invite`). In a world built by hand, add one to the HUD.

**The web player freezes for the others.**
They switched tabs: the browser paused it. See [11.5](#115-a-hidden-tab).

## 16. Glossary

| Term | What it is |
|---|---|
| `MpKit` | The autoload: network, slots, session messages |
| `MpFlow` | The node that handles scenes and modes (solo, LAN, join, dedicated). It owns the session |
| `Mp` | The class with the verbs of the match: `play_solo`, `host`, `join`, `leave`, `is_server`, `me`, `state`, `finish`, `net_quality` |
| `MpGame` | The game in one `.tres`: the network (it is an `MpNetConfig`) and the scenes (boot, world, lobby, rooms) |
| `MpWorld` | A node in the world that builds spawn points, actors, the spawner, the state, the match, the Leave button, the invite, the Start now button and the waiting line |
| `MpInviteLabel` | In the HUD: in a private match of this PC, what friends type to get in |
| `MpStartButton` | In the HUD: in Host LAN, while the match waits for seats, the host starts with those already in |
| `MpWaitingLabel` | In the HUD: while the match waits for its seats, "Waiting for players (1/4)" on every peer |
| `MpNetQuality` | The connection's quality (RTT, jitter, loss, grade); read it with `Mp.net_quality()` |
| `MpLagComp` | Lag compensation: a second of poses on the server, to check a shot against what the shooter saw |
| `MpNetConfig` | A `.tres` with the game's network: transport, port, players, public address, relay, TLS |
| `MpAddress` | The address reader (IP, name, `:port`, `#CODE`, URL) used by the menu, the flow and the lobby |
| `MpBootMenu` | The ready-made menu (`mp_boot_menu.tscn`) |
| `MpActor` | A child of everything the network shares: sync, owner, calls, prediction |
| `callers` | Who may ask for an `MpActor`'s `mp_sv_*`: `OWNER` or `ANYONE` |
| `MpSync` | The `MultiplayerSynchronizer` the editor builds under an `MpActor` or `MpState` |
| `MpInput` | The owner's keys, read on the server with the `Input` API |
| `MpState` | Match values everyone sees |
| `MpMatch` | Start and end of the match, waiting for seats, absences and abandons |
| `MpLeaveButton` | A button that leaves the match (to the lobby or the menu) |
| `MpSpawner` | A spawner that creates things on everyone (`spawn_actor`, Extra Scenes) |
| `MpSlotSpawner` | A spawner of one player per slot |
| `MpRoomServer` | The room server's scene |
| `MpLobbyConfig` | A `.tres` with ports, limits and times of rooms and matches |
| `MpRoomRules` | Your room rules (seats, picks, options) |
| `MpLobbyScreen` | The client's lobby screen |
| `MpLocalServer` | A dedicated on your PC with codes (a private match) |
| Relay | A Node server in the middle; the Godot server connects out |
| Slot | A player number (1, 2, 3…) |
| Peer id | Godot's connection number. It is not the player |
| `owner_slot` | A node's owning slot. 0 = the server |
| Proxy | The copy of a node this machine only draws |
| Listen server / LAN host | A player who is also the server |
| Dedicated | A server without a player |
| Ticket / token | What a player presents to enter a room or private match |
| Pick | What a player chose in their seat (character, team) |
| Prediction | The owner moves at once |
| Reconciliation | The owner goes back to the server's state and replays what was missing |
| Lag compensation | The server checks a shot against what the shooter saw |
| `BUFFERED` / `FOLLOW` / `NONE` | Proxy smoothing modes |
| ENet | The UDP transport (desktop) |
| WebSocket / `ws` / `wss` | The TCP transport (web); `wss` = encrypted with TLS |

## 17. I want X → I use Y

| I want… | I use… |
|---|---|
| a game that works in minutes | **Project › Tools › MpKit: Setup game...** |
| the whole network and the scenes in one place | an **MpGame** (`game.tres`) in **Flow › Game** |
| a networked world without wiring nodes | an **MpWorld** with **Player Scene** |
| to play solo, host, join or leave from my own menu | `Mp.play_solo()`, `Mp.host()`, `Mp.join(text)`, `Mp.leave()` |
| a loading screen that waits for the world (shaders) | **MpFlow › world_reports_loaded** + `report_world_loaded()` in the world; listen to `world_load_progressed` ([7.7](#77-loading-screen)) |
| something to look the same everywhere | **MpActor › Sync** (position, rotation, visible, Extra) |
| to sync a property of my own (`health`) | **MpActor › Sync › sync_extra** = `health` (or `Health:current`) |
| the player to answer without lag | **MpActor › Prediction › predict** + `func mp_move(keys, delta)` |
| gravity or inertia with prediction | `velocity` in **Sync › sync_extra** |
| the others to look steady | **MpActor › Smoothing** = `BUFFERED` (with `adaptive_buffer`), and `late_tolerance` or the `buffer_delay_s` cap |
| to show the ping or the connection's quality | `Mp.net_quality()` |
| players to host online matches with no server of mine (web too) | `flow.host_online()` / `join_online(code)` / `online_rooms()` with the issuer and the relay ([10.3](#103-online-rooms-your-players-host-no-server-of-yours)) |
| to know the host froze or its link stalls | `MpKit.host_silent(seconds)` / `MpKit.host_back` |
| a shot to hit what the shooter saw | `net.rewound(func)`, `net.seen_position_of(node)` or `net.view_lag()` (lag compensation) |
| to use less bandwidth | **MpActor › Sync › send_hz** (e.g. 20) |
| to read the player's keys on the server | `input.get_vector`, `input.is_action_just_pressed`… |
| to send the aim | `input.set_value(&"aim", v)` on the owner, `input.get_value(&"aim")` on the server (check it) |
| an order from the player | `net.to_server(&"x", args)` → `func mp_sv_x(args)` |
| to know who asked for the order | `net.sender_slot()` inside `mp_sv_*` |
| an effect on everyone | `net.to_all(&"x", args)` → `func mp_all_x(args)` (server only) |
| an object anyone can use | `MpActor` with **Owner › callers = ANYONE** + `to_server` |
| to spawn bullets or pickups | **MpSpawner** with the scene in **Extra Scenes** + `spawn_actor(scene, props, owner_slot)` |
| to remove something everywhere | `net.despawn()` (server, nodes a spawner made) |
| to hide a world object | `sync_visible` + `visible = false` on the server |
| to teleport without sliding | `net.snap()` on the server, right after moving it |
| score, clock, round | `Mp.state().set_value` / `.add`, `changed` signal |
| to end the match | `Mp.finish({"winner": ...})`, `finished` signal everywhere |
| to show "waiting for players" | `MpMatch.waiting_changed` + a node with Process Mode = Always |
| to know whether someone came back or abandoned | `MpMatch.player_back` / `player_abandoned` |
| a button to leave | the `MpWorld`'s `Hud/Leave` (an **MpLeaveButton**), or `Mp.leave()` |
| to always go back to the menu | `MpFlow.find_in_tree(self).return_to_boot()` |
| to go back to a room match after dropping | the **Back to the match** button (`MpLobbyScreen.rejoin_match()`) |
| to know whether I am the server | `net.is_authority()` / `Mp.is_server()` |
| to know whether this node is mine | `net.is_local()` |
| to know which player I am | `Mp.me()`, or an **MpLocalSeat** handed to the HUD (`seat.slot`, `is_mine`, `preview_slot` solo) |
| a value of the match from the start and each change | `state.watch(&"key", callback)` |
| to spawn from any peer without asking who I am | `spawner.spawn_here(data)` |
| to play on LAN | **Host LAN** + **Join** the IP |
| a dedicated server | `godot --headless --path . -- --dedicated` |
| online rooms | `lobby_scene` and `rooms_scene` in `game.tres`: `MpRoomServer` + `MpLobbyConfig` + `MpLobbyScreen` (the `MpMatch` comes in the `MpWorld`) |
| room rules | a script that extends `MpRoomRules` |
| rooms with a mode or map | `MpLobbyScreen.room_options` + `MpRoomRules.seats_for` |
| a match with a code on my PC | `MpBootMenu.offer_private_server` or `MpLocalServer.start_on` |
| the menu to have the server's address already | `public_host` in `game.tres` |
| a server without a public IP or ports | the relay: `transport = relay`, `relay_url`, `MPKIT_RELAY_SECRET` |
| a web game | `transport = ws` (or `relay`) in `game.tres`, a WS server or the relay, a Web export |
| the web over https | `wss://`: `tls_client` on the client and a certificate on the server |
| to test with lag | `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` |
| to watch a whole match without playing | `mpkit_lab/run/play.sh dedicated --watch` |
| to put it on a VPS | `deploy/deploy.sh user@vps build/server --rooms 7700 --open-firewall` |
| to see the VPS's logs | `journalctl -u 'game-rooms@*' -f` |

## 18. Where to go next

- [QUICKSTART.md](QUICKSTART.md): the short version.
- [README.md](README.md): the reference of every piece, transport, the `Dictionary` tunnel, hub rooms and the low level.
- [deploy/README.md](deploy/README.md): deploying to a VPS in detail.
- [relay/README.md](relay/README.md): the relay, Railway, Fly.io, useful commands and its protocol.
- [examples/arena_2d/](examples/arena_2d/): the whole example. Open `boot.tscn` and press F6.
- `mpkit_lab/` (at the root of the repo): `run/play.sh` to play or watch in windows, `run/all.sh` for the whole matrix, and `CASES.md` with what each test covers.
