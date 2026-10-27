# mpkit_lab

What: a small Godot project that runs MpKit's example and tests without any game (only `MpKit` and the probe are autoloads).
Not: a game. `addons/mp_kit` is a symlink to the kit's canonical copy. `addons/lab_editor_check` is a lab-only plugin that does nothing without `MPKIT_EDITOR_CHECK`.
Talks to: `probe/lab_probe.gd` plays the `arena_2d` example from the command line (`--probe=solo|client|late|watch|lag|observe|lagshooter|lagtarget|lobby|private|private_other|invited|badcode|online_host|online_join|online_list|online_refused|flood|floodwatch|basic|…`); `run/*.sh` starts the processes and gathers the verdicts.
Edit: nothing to configure. With a shared Godot queue (e.g. AgentKit's), `MPKIT_GODOT_GROUP=<group.sh>` and `MPKIT_GODOT_RUN=<run.sh>`. The local relay needs Node; the web check needs the Web export templates and a Chrome or Chromium (without one it says SKIP).
Check: `bash mpkit_lab/run/all.sh` → `MPKIT ALL PASS`. It covers the kit's tests, solo, session, the relay's rules, the arena (LAN, dedicated, lag with network quality and remote delay, shots with lag compensation, flood), rooms and the private match over ENet, WebSocket and the relay, rooms players host through the issuer (a desktop host, a host in its own game frozen mid-match, a browser host), rooms over `wss://`, a web client over WebSocket and over the relay, several instances, the wizard in 2D and 3D, and `MpWorld` and the wizard in the real editor. What each case tests: [CASES.md](CASES.md).
For every change: `bash mpkit_lab/run/all.sh --quick` (a few minutes). The relay's faults: `bash mpkit_lab/run/relayfault.sh`.
The server image (deploy/fly) in Docker: `bash mpkit_lab/run/docker.sh` (a dedicated and a room server in containers behind a local relay; SKIP without Docker). By hand, for any game: GUIDE 13.7.
Watch in windows: `bash mpkit_lab/run/play.sh dedicated|listen|rooms [--watch] [--relay]` (without `--watch` you play).
