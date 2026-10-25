# mpkit_lab

What: a small Godot project that runs MpKit's example and tests without any game (only `MpKit` and the probe are autoloads).
Not: a game. `addons/mp_kit` is a symlink to `../addons/mp_kit`: it tests the kit's canonical copy.
Talks to: `probe/lab_probe.gd` plays the `arena_2d` example from the command line (`--probe=solo|client|late|watch|lag|observe|lobby|private|invited|badcode|flood|floodwatch|basic`); `run/*.sh` starts the processes and gathers the verdicts.
Edit: nothing to configure. With a shared Godot queue (e.g. AgentKit's), `MPKIT_GODOT_GROUP=<group.sh>` and `MPKIT_GODOT_RUN=<run.sh>`.
Check: `bash mpkit_lab/run/all.sh` → `MPKIT ALL PASS` (tests, solo, LAN, dedicated, lag, flood, rooms over ENet, WebSocket and `wss://`, private match, several instances, wizard 2D and 3D). The web check is separate: `bash mpkit_lab/run/web.sh` and open the URL it prints in a visible tab.
