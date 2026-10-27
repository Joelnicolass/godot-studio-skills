extends Node

## Lab-only player robot for the arena_2d example. Inert without `--probe=`. It presses keys like a person and checks
## what comes back over the network, printing `PASS …` / `FAIL …` and a last `PROBE <role> PASS|FAIL` line.
## Roles: solo | client (the first player; `--probe-rejoin`: then it leaves and joins again, same slot) | basic (any game: move and score
## only, e.g. one the wizard wrote) | late (joins after the match started: the start gate turns it away, `--probe-reason=`) | watch (server or host:
## waits for a remote player to move and score) | lag (own player under a bad network: response and corrections) |
## observe (another player, `--probe-watch-slot=N`: how evenly it moves on screen) | pusher (server: pushes P1 sideways
## every half second, a move its owner cannot predict) | correct (own player, pushed by the server: the corrections
## must not show as jumps; `--probe-expect-jump` for the control with `--correction-smoothing-s=0`) | teleporter (server:
## teleports P2 every 0.8 s with only `net.snap()` after it; `--probe-no-snap`: without it, the control) | teleported /
## seeteleport (the owner / another player: each teleport is one jump on screen, never a slide; `--probe-expect-slide`
## for the control) | lobby (online rooms through the
## lobby screen: `--probe-lobby=host:port --probe-name=X`, `--probe-create=Room` makes the room and scores to win) |
## private (MpLocalServer on this PC; writes "port code" to `--probe-code-file`, plays and wins) | invited (joins
## with "ip:port#CODE" from that file) | badcode (same address, a wrong code: must be turned away) | flood (sends 500
## tunnel messages and 500 to_server calls at once) | floodwatch (server: only what the limits allow gets through) |
## online_host (an online room through the issuer, MpOnline: `--probe-players=N`, `--online-mode=listen|dedicated`;
## writes its code to `--probe-code-file`, waits for everyone, wins; `--probe-wait-file=F`: not before F exists;
## `--probe-ticket=JSON`: the game's match ticket for host_online) |
## online_join (joins with that code, typed "abc-def"; `--probe-expect-silence`: the host freezes meanwhile and comes
## back; after the end, back in the menu, the game's transport is untouched) | online_list (finds the room in
## the issuer's list, then joins it; `--probe-find-name=X`: the room named X,
## for a host that cannot write the code file, a browser) | online_refused (tries the code, or
## `--probe-room=`, and expects the issuer's `--probe-expect=` word) | online_stop (opens a room and closes it on
## purpose: no `failed`, `ended`, the match process gone, the issuer forgot it; `--probe-stop-early`: before the room is
## up, from the boot: the scene stays). `--probe-linger-s=N` keeps a
## passing process alive N seconds. lag and observe print `METRIC name=value` lines.

## Seconds each check may wait (`--probe-timeout-s=N` for a person opening a browser by hand).
var step_timeout_s := 20.0

var _role := ""
var _fails := 0
## What the network told this process (session cases read them).
var _join_failed := false
var _server_lost := false
var _rejected := ""
var _ever_slot := 0
var _last_status := ""
## Stand-in while the current scene has no MpState (between scenes).
var _empty_state: MpState


func _ready() -> void:
	_role = MpBoot.user_value("probe", "")
	step_timeout_s = float(MpBoot.user_value("probe-timeout-s", "20"))
	MpKit.join_failed.connect(func() -> void: _join_failed = true)
	MpKit.server_lost.connect(func() -> void: _server_lost = true)
	MpKit.admission_rejected.connect(func(reason: String) -> void: _rejected = reason)
	MpKit.slot_assigned.connect(func(slot: int) -> void: _ever_slot = slot)
	## `--probe-report-after=S` (with `--world-reports-loaded`): every world reports itself loaded S seconds after it enters, like
	## a loading screen warming shaders up; until then the start gate must hold this peer's world.
	if not MpBoot.user_value("probe-report-after", "").is_empty():
		get_tree().scene_changed.connect(_report_world_later)
	## `--probe-keep-pawns` (server): a player who drops keeps its pawn for its rejoin (despawn_on_leave off), as a game
	## whose avatar waits in the world during the grace.
	if MpBoot.user_flag("probe-keep-pawns"):
		get_tree().scene_changed.connect(_keep_pawns)
	## `--probe-physics-interpolation`: the engine's physics interpolation on, as a game with it in Project Settings.
	if MpBoot.user_flag("probe-physics-interpolation"):
		get_tree().physics_interpolation = true
	if _role.is_empty():
		return
	print("probe %s start" % _role)
	_run.call_deferred()


func _run() -> void:
	## `--probe-join=host:port`: join the way a person does, through the address field of the flow.
	var address := MpBoot.user_value("probe-join", "")
	if not address.is_empty():
		await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
		MpFlow.find_in_tree(self).status_changed.connect(func(text: String) -> void: _last_status = text)
		_check(MpFlow.find_in_tree(self).join_address(address) == OK, "join_address(%s) started" % address)
	match _role:
		"solo":
			await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
			MpFlow.find_in_tree(self).play_solo()
			await _play_as(1)
		"client":
			await _until(_networked_slot, "the server gave this client a slot")
			var slot := MpKit.local_slot()
			await _play_as(slot)
			if MpBoot.user_flag("probe-rejoin"):
				await _rejoin(slot)
		"basic":
			await _until(_networked_slot, "the server gave this client a slot")
			await _play_basic(MpKit.local_slot())
		"late":
			await _check_late()
		"watch":
			await _check_watch()
		"lag":
			await _measure_own_lag()
		"observe":
			await _measure_proxy_jitter()
		"pusher":
			await _push_player()
		"correct":
			await _measure_correction()
		"teleporter":
			await _teleport_player()
		"teleported":
			await _measure_teleports(0, true)
		"seeteleport":
			await _measure_teleports(int(MpBoot.user_value("probe-watch-slot", "2")), false)
		"lobby":
			await _play_online()
		"private":
			await _host_private()
		"flood":
			await _flood()
		"failjoin":
			await _check_fail_join()
		"refused":
			await _check_refused()
		"leaver":
			await _leave_and_return()
		"rejoinwatch":
			await _watch_leave_and_return()
		"lost":
			await _check_server_lost()
		"browse":
			await _browse_lan()
		"floodwatch":
			await _watch_flood()
		"lagtarget":
			await _walk_as_target()
		"lagshooter":
			await _shoot_moving_target()
		"private_other":
			await _other_private_server()
		"invited":
			await _join_private(true)
		"badcode":
			await _join_private(false)
		"online_host":
			await _host_online()
		"online_join":
			await _join_online(false)
		"online_list":
			await _join_online(true)
		"online_refused":
			await _refused_online()
		"online_stop":
			await _stop_online()
		_:
			_check(false, "known role %s" % _role)
	print("PROBE %s %s" % [_role, "PASS" if _fails == 0 else "FAIL"])
	var linger := float(MpBoot.user_value("probe-linger-s", "0"))
	if _fails == 0 and linger > 0.0:
		await get_tree().create_timer(linger).timeout
	get_tree().quit(0 if _fails == 0 else 1)


## Move right, score once, recolor once; every result must come back from the server.
func _play_as(slot: int) -> void:
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	var start_x: float = pawn.position.x
	Input.action_press(&"ui_right")
	await _until(func() -> bool: return pawn.position.x > start_x + 60.0, "P%d moved right (server simulated, synced back)" % slot)
	Input.action_release(&"ui_right")
	await _tap(&"ui_accept")
	var key := StringName("p%d" % slot)
	await _until(func() -> bool: return int(_state().get_value(key, 0)) == 1, "score %s reached 1 (MpState)" % key)
	await _until(func() -> bool: return pawn.flashes == 1, "the flash event arrived (to_all)")
	await _tap(&"ui_focus_next")
	await _until(func() -> bool: return pawn.color_index == 1, "recolor went to the server and back (to_server + sync)")
	var shots := get_tree().current_scene.get_node("Projectiles")
	await _tap(&"ui_select")
	await _until(func() -> bool: return shots.get_child_count() > 0, "a shot the server spawned (spawn_actor) reached this peer")
	await _until(func() -> bool: return shots.get_child_count() == 0, "the shot was removed everywhere (despawn)")
	var bell := get_tree().get_first_node_in_group(&"bell")
	await _tap(&"ui_cancel")
	await _until(func() -> bool: return bell.rings == 1, "the bell (no owner) rang through to_server")
	await _until(func() -> bool: return int(_state().get_value(&"bell_by", -1)) == _who_rang(slot), "the server knew who rang it (sender_slot)")


## Only what every MpKit game has: the arrows move the own player (server simulated) and Enter scores.
func _play_basic(slot: int) -> void:
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	var start_x: float = pawn.position.x
	Input.action_press(&"ui_right")
	await _until(func() -> bool: return pawn.position.x > start_x + 1.0, "P%d moved right" % slot)
	Input.action_release(&"ui_right")
	await _tap(&"ui_accept")
	await _until(func() -> bool: return int(_state().get_value(StringName("p%d" % slot), 0)) == 1, "the score reached 1")
	## `--probe-win`: play to the end (the arena's first to 3), then the flow leaves after the result.
	if MpBoot.user_flag("probe-win"):
		var finished: Array[Dictionary] = []
		MpFlow.find_in_tree(self).match_finished.connect(func(result: Dictionary) -> void: finished.append(result))
		await _tap(&"ui_accept")
		await _tap(&"ui_accept")
		await _until(func() -> bool: return not finished.is_empty(), "the match finished (first to 3)")
		await _until(func() -> bool: return not MpKit.is_networked(), "the player left after the result")


## The slot that rang the bell: the player, or 1 in solo / for the host (local_slot of the authority).
func _who_rang(slot: int) -> int:
	return slot


## A player who joins after the match started: the start gate turns it away (`--probe-reason=`, default match_started). It never
## gets a slot nor the world, ends offline, and the flow shows the reason (MpFlow.rejection_text).
func _check_late() -> void:
	var reason := MpBoot.user_value("probe-reason", MpMatchGate.MATCH_STARTED)
	if not await _until(func() -> bool: return _rejected != "", "the late client was turned away"):
		return
	_check(_rejected == reason, "the reason is %s (got %s)" % [reason, _rejected])
	_check(_ever_slot == 0, "the late client never got a slot")
	await _until(func() -> bool: return not MpKit.is_networked(), "the late client ends offline")
	_check(_in_world("Actors") == null, "the late client never loaded the world")
	var flow := MpFlow.find_in_tree(self)
	_check(flow != null and _last_status == flow.rejection_text(reason), "the flow shows the reason (%s)" % _last_status)


## The first player leaves (the Leave path: back to the menu, offline) and joins the same address again: the server gives it the
## same slot (its seat credential), MpMatch counts the comeback, and what it made before is still there.
func _rejoin(slot: int) -> void:
	var flow := MpFlow.find_in_tree(self)
	var address := "127.0.0.1:%d" % MpKit.port
	## `--probe-pawn-kept` (the server keeps the pawn): leave while walking, holding the key.
	var kept := MpBoot.user_flag("probe-pawn-kept")
	var left_x := 0.0
	if kept:
		var walking := await _pawn(slot)
		Input.action_press(&"ui_left")
		await get_tree().create_timer(0.4).timeout
		left_x = MpActor.of(walking).net_position.x
	flow.return_to_boot()
	Input.action_release(&"ui_left")
	await _until(func() -> bool: return get_tree().current_scene.name == "Boot" and not MpKit.is_networked(), "rejoin: left to the menu, offline")
	await get_tree().create_timer(1.0).timeout
	_ever_slot = 0
	_check(flow.join_address(address) == OK, "rejoin: join_address(%s) started" % address)
	await _until(func() -> bool: return _networked_slot() and _ever_slot != 0, "rejoin: the server let the seat back in")
	_check(MpKit.local_slot() == slot, "rejoin: the same slot (%d, got %d)" % [slot, MpKit.local_slot()])
	var back_pawn := await _pawn(slot)
	if back_pawn == null:
		return
	## The new connection's input counts from 1 again: the server must take it (it moves the pawn it kept).
	await get_tree().create_timer(0.5).timeout
	var back_net := MpActor.of(back_pawn)
	if kept:
		## Until the server knows the connection is gone it repeats the last frame (MpInputQueue: at most MAX_GUESSES
		## ticks, then no keys), plus the frames on the way: a few dozen px. With the key held on for the second or
		## more it was away, it would have gone 220 px or more.
		var went := absf(back_net.net_position.x - left_x)
		_check(went < 150.0, "rejoin: without a connection the kept pawn stopped (it went %.0f px after the leave, not on with the held key)" % went)
	var server_x := back_net.net_position.x
	Input.action_press(&"ui_right")
	await get_tree().create_timer(1.0).timeout
	Input.action_release(&"ui_right")
	_check(back_net.net_position.x - server_x > 100.0, "rejoin: the server moves the pawn with the new connection's keys (%.0f px)" % (back_net.net_position.x - server_x))
	await _until(func() -> bool: return int(_state().get_value(StringName("p%d" % slot), 0)) == 1, "rejoin: the score made before leaving is still there")
	await _until(func() -> bool: return int(_state().get_value(StringName("back_%d" % slot), 0)) == 1, "rejoin: the server counted the comeback (MpMatch.player_back)")
	var bell := get_tree().get_first_node_in_group(&"bell")
	await _until(func() -> bool: return bell.rings == 1, "rejoin: the bell rung before leaving shows (a static actor)")
	_check(get_tree().current_scene.get_node("Projectiles").get_child_count() == 0, "rejoin: no leftover shots reached the peer")
	var host_pawn := _in_world("Actors/Pawn_1") if slot != 1 else null
	if host_pawn == null:
		return
	## Bypass the client-side guard: send the RPC by hand for an actor this peer does not own.
	var color: int = host_pawn.color_index
	MpActor.of(host_pawn).rpc_server_call.rpc_id(1, &"recolor", [])
	await get_tree().create_timer(1.0).timeout
	_check(host_pawn.color_index == color, "the server refused a to_server call from a peer that does not own the actor")


## Server or host: a remote player's input moves its pawn here and its score counts here.
func _check_watch() -> void:
	await _until(func() -> bool: return MpKit.is_server(), "this process is the server")
	var slot := 2 if MpKit.is_listen_host() else 1
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	if MpBoot.user_flag("probe-server-node"):
		## A server-only node added by hand in a spawn_path (an effect the engine does not replicate): clients must not
		## be affected (no gate, nothing held for it).
		var fx := Node2D.new()
		fx.name = "ServerOnlyFx"
		get_tree().current_scene.get_node("Projectiles").add_child(fx)
		_check(fx.get_node_or_null(MpSpawner.GATE_NAME) == null, "a server-only node in spawn_path got no gate")
	var start_x: float = pawn.position.x
	var min_move := float(MpBoot.user_value("probe-min-move", "60"))
	await _until(func() -> bool: return pawn.position.x > start_x + min_move, "the remote P%d input moved it on the server" % slot)
	await _until(func() -> bool: return int(_state().get_value(StringName("p%d" % slot), 0)) >= 1, "the remote P%d scored on the server" % slot)
	_check(MpKit.ready_peers().has(MpKit.peer_id_for(slot)), "P%d, playing, is in MpKit.ready_peers()" % slot)
	if pawn.has_node("MpInput") and MpBoot.user_value("probe-min-move", "60") == "60":
		await _until(func() -> bool: return pawn.get_node("MpInput").get_value(&"aim") is Vector2, "the owner's aim (MpInput.set_value) reached the server")


## Own player, predicted: it must answer the key on the next ticks whatever the lag, and the server's corrections
## must stay small while it walks.
func _measure_own_lag() -> void:
	await _until(_networked_slot, "the lag client got a slot")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	await get_tree().create_timer(1.0).timeout
	var net := MpActor.of(pawn)
	var start_x: float = pawn.position.x
	## Right: away from the other player (walking into it would push the two apart and spoil the measure).
	Input.action_press(&"ui_right")
	## The moment of the key, on the machine's wall clock: an observer on the same PC measures when it sees the move.
	var press_file := MpBoot.user_value("probe-press-file", "")
	if not press_file.is_empty():
		var pf := FileAccess.open(press_file, FileAccess.WRITE)
		pf.store_string("%d" % int(Time.get_unix_time_from_system() * 1000.0))
		pf.close()
	var frames := 0
	while pawn.position.x == start_x and frames < 120:
		await get_tree().physics_frame
		frames += 1
	print("METRIC response_ticks=%d" % frames)
	_check(frames <= 2, "the own player answered the key within 2 ticks (prediction)")
	var worst := 0.0
	var t0 := Time.get_ticks_msec()
	## Long enough for the observer's 3 s window (a blip a few times a minute shows in it).
	var end := t0 + 5000
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		if not is_instance_valid(net):
			break
		worst = maxf(worst, net.last_correction())
	Input.action_release(&"ui_right")
	await get_tree().create_timer(1.0).timeout
	print("METRIC max_correction_px=%.2f settled_correction_px=%.2f" % [worst, net.last_correction()])
	_check(worst < float(MpBoot.user_value("probe-max-correction", "2")), "server corrections stayed small while walking")
	_check(net.last_correction() < 0.5, "once stopped, the prediction and the server agree")


## Server: pushes slot 1's player sideways by --probe-push-px (40) every 0.5 s, `--probe-pushes` (6) times, from the
## moment it walks. Its owner cannot predict that: each push reaches it as a correction.
func _push_player() -> void:
	await _until(func() -> bool: return MpKit.is_server(), "this process is the server")
	var pawn := await _pawn(1)
	if pawn == null:
		return
	var start_x: float = pawn.position.x
	await _until(func() -> bool: return absf(pawn.position.x - start_x) > 20.0, "P1 started walking")
	var push := float(MpBoot.user_value("probe-push-px", "40"))
	var pushes := int(MpBoot.user_value("probe-pushes", "6"))
	for i in pushes:
		await get_tree().create_timer(0.5).timeout
		pawn.position.y += push if i % 2 == 0 else -push
	_check(true, "pushed P1 %d times by %.0f px" % [pushes, push])


## Server: teleports P2 by TELEPORT_PX (up, then down) TELEPORTS times, 0.8 s apart, from the moment it walks; the
## only network call is `net.snap()` right after moving it, as a game does.
const TELEPORT_PX := 150.0
const TELEPORTS := 4


func _teleport_player() -> void:
	await _until(func() -> bool: return MpKit.is_server(), "this process is the server")
	var pawn := await _pawn(2)
	if pawn == null:
		return
	var start_x: float = pawn.position.x
	await _until(func() -> bool: return absf(pawn.position.x - start_x) > 60.0, "P2 is walking")
	for i in TELEPORTS:
		await get_tree().create_timer(0.8).timeout
		pawn.position.y += TELEPORT_PX if i % 2 == 0 else -TELEPORT_PX
		if not MpBoot.user_flag("probe-no-snap"):
			MpActor.of(pawn).snap()
		print("METRIC teleport_%d_y=%d stamp=%.3f" % [i, roundi(pawn.position.y), MpNetClock.stamp()])
	_check(true, "teleported P2 %d times by %.0f px" % [TELEPORTS, TELEPORT_PX])


## Each of the server's teleports (teleporter) shows here as ONE frame that jumps the whole way: no frame in between
## (a slide, or a correction fading). `own`: this is the teleported player itself (predicted), walking; its slot is
## read once the server gave it one.
func _measure_teleports(slot: int, own: bool) -> void:
	await _until(_networked_slot, "this client got a slot")
	if own:
		slot = MpKit.local_slot()
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	if own:
		await get_tree().create_timer(1.0).timeout
		Input.action_press(&"ui_left")
	else:
		var start_x: float = pawn.position.x
		await _until(func() -> bool: return absf(pawn.position.x - start_x) > 20.0, "P%d started walking" % slot)
	var sampler := _Sampler.new()
	sampler.target = pawn
	sampler.process_priority = 20000
	add_child(sampler)
	## Until every teleport showed (a jump of nearly TELEPORT_PX in one frame), plus a margin; at most the whole run.
	var slide := MpBoot.user_flag("probe-expect-slide")
	var end := Time.get_ticks_msec() + int((0.8 * TELEPORTS + 4.0) * 1000.0)
	while Time.get_ticks_msec() < end and (slide or _jumps_in(sampler.ys) < TELEPORTS):
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	if own:
		Input.action_release(&"ui_left")
	sampler.queue_free()
	var jumps := 0
	var partial := 0
	var levels: Array[int] = []
	if not sampler.ys.is_empty():
		levels.append(roundi(sampler.ys[0]))
	for i in range(1, sampler.ys.size()):
		var dy := absf(sampler.ys[i] - sampler.ys[i - 1])
		if dy > TELEPORT_PX * 0.8:
			jumps += 1
			levels.append(roundi(sampler.ys[i]))
		elif dy > 10.0:
			partial += 1
	print("METRIC teleport_jumps=%d teleport_partial_frames=%d frames=%d y_levels=%s" % [jumps, partial, sampler.ys.size(), levels])
	if slide:
		_check(partial >= TELEPORTS, "control: without net.snap() the moves are drawn partway (%d frames)" % partial)
		return
	_check(jumps == TELEPORTS, "each teleport showed as one jump (%d of %d)" % [jumps, TELEPORTS])
	_check(partial == 0, "no frame drew it partway (%d frames did)" % partial)


func _jumps_in(ys: PackedFloat64Array) -> int:
	var jumps := 0
	for i in range(1, ys.size()):
		if absf(ys[i] - ys[i - 1]) > TELEPORT_PX * 0.8:
			jumps += 1
	return jumps


## Own player pushed by the server (pusher): the corrections it gets are as big as the pushes, and on screen no frame
## jumps by much more than a walking step (they fade, MpCorrectionSmoother). With --probe-expect-jump (the control,
## --correction-smoothing-s=0) the same pushes must show as jumps: the measure sees what it is meant to.
func _measure_correction() -> void:
	await _until(_networked_slot, "the pushed client got a slot")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	await get_tree().create_timer(1.0).timeout
	var net := MpActor.of(pawn)
	var push := float(MpBoot.user_value("probe-push-px", "40"))
	var sampler := _Sampler.new()
	sampler.target = pawn
	sampler.process_priority = 20000
	add_child(sampler)
	Input.action_press(&"ui_left")
	var worst := 0.0
	var end := Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		if not is_instance_valid(net):
			break
		worst = maxf(worst, net.last_correction())
	Input.action_release(&"ui_left")
	sampler.queue_free()
	var steps: Array = []
	for i in range(1, sampler.xs.size()):
		steps.append(Vector2(sampler.xs[i] - sampler.xs[i - 1], sampler.ys[i] - sampler.ys[i - 1]).length())
	steps.sort()
	var median: float = steps[steps.size() / 2] if not steps.is_empty() else 0.0
	var biggest: float = steps.back() if not steps.is_empty() else 0.0
	print("METRIC max_correction_px=%.1f max_step_px=%.1f median_step_px=%.2f frames=%d" % [worst, biggest, median, steps.size()])
	_check(worst > push * 0.5, "the server's pushes reached the owner as corrections (%.1f px)" % worst)
	if MpBoot.user_flag("probe-expect-jump"):
		_check(biggest > push * 0.6, "control: without smoothing a correction shows as one jump (%.1f px)" % biggest)
	else:
		_check(biggest < median + push * 0.25, "no frame jumps much more than a walking step (%.1f px, a step %.1f)" % [biggest, median])


## Another player walking at a steady speed must look steady here: low spread of its on-screen speed.
func _measure_proxy_jitter() -> void:
	var slot := int(MpBoot.user_value("probe-watch-slot", "2"))
	await _until(_networked_slot, "the observer got a slot")
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	var start_x: float = pawn.position.x
	var press_file := MpBoot.user_value("probe-press-file", "")
	if not press_file.is_empty():
		## From the other player's key to the first frame its move shows here.
		await _until(func() -> bool: return absf(pawn.position.x - start_x) > 0.5, "P%d started moving here" % slot)
		var seen_ms := int(Time.get_unix_time_from_system() * 1000.0)
		await _until(func() -> bool: return FileAccess.file_exists(press_file), "the walker wrote when it pressed")
		var delay_ms := seen_ms - int(FileAccess.get_file_as_string(press_file))
		print("METRIC remote_delay_ms=%d" % delay_ms)
		var max_delay := float(MpBoot.user_value("probe-max-remote-delay-ms", "0"))
		if max_delay > 0.0:
			_check(delay_ms <= max_delay, "another player's move shows here within %d ms (took %d)" % [max_delay, delay_ms])
	await _until(func() -> bool: return absf(pawn.position.x - start_x) > 20.0, "P%d started walking" % slot)
	await get_tree().create_timer(0.3).timeout
	## Sample after MpActor drew this frame (higher process_priority), with this frame's time.
	var sampler := _Sampler.new()
	sampler.target = pawn
	sampler.process_priority = 20000
	add_child(sampler)
	await get_tree().create_timer(3.0).timeout
	sampler.queue_free()
	var speeds := PackedFloat64Array()
	for i in range(1, sampler.xs.size()):
		var dt := (sampler.ts[i] - sampler.ts[i - 1]) / 1000000.0
		if dt > 0.0:
			speeds.append(absf(sampler.xs[i] - sampler.xs[i - 1]) / dt)
	var mean := 0.0
	for v in speeds:
		mean += v
	mean /= maxf(speeds.size(), 1)
	var spread := 0.0
	for v in speeds:
		spread += (v - mean) * (v - mean)
	var cv := sqrt(spread / maxf(speeds.size(), 1)) / maxf(mean, 0.001)
	## Robust spread: median of |speed - median| / median. Jitter on every frame raises it; one stall of a process
	## (the walker paused, then caught up: correct behaviour) does not. cv shows both.
	var sorted := Array(speeds)
	sorted.sort()
	var median: float = sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0
	var deviations := sorted.map(func(v: float) -> float: return absf(v - median))
	deviations.sort()
	var mad: float = deviations[deviations.size() / 2] / maxf(median, 0.001) if not deviations.is_empty() else 1.0
	## The 95th percentile over the median: how much faster than usual the worst frames move (1 = perfectly even).
	var p95: float = sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)] / maxf(median, 0.001) if not sorted.is_empty() else 0.0
	## Blips: frames that move more than half again (a hitch forward) or less than half (a stall) of the usual speed.
	var blips := 0
	for v in speeds:
		if v > median * 1.5 or v < median * 0.5:
			blips += 1
	print("METRIC proxy_speed_px_s=%.1f proxy_speed_median=%.1f proxy_speed_mad=%.3f proxy_speed_cv=%.3f proxy_speed_p95_over_median=%.2f proxy_blips=%d frames=%d" % [mean, median, mad, cv, p95, blips, speeds.size()])
	_check(median > 150.0, "P%d moved at about its real speed on screen" % slot)
	var q := Mp.net_quality()
	print("METRIC net_rtt_ms=%.0f net_jitter_ms=%.1f net_loss=%.3f grade=%s samples=%d" % [q["rtt_ms"], q["jitter_ms"], q["loss"], q["grade_name"], q["samples"]])
	var rtt_min := float(MpBoot.user_value("probe-rtt-min-ms", "-1"))
	var rtt_max := float(MpBoot.user_value("probe-rtt-max-ms", "-1"))
	if rtt_min >= 0.0:
		_check(q["rtt_ms"] >= rtt_min and q["rtt_ms"] <= rtt_max, "the measured round trip matches the simulated network (%.0f ms in %.0f..%.0f)" % [q["rtt_ms"], rtt_min, rtt_max])
	var loss_expected := float(MpBoot.user_value("probe-loss-expected", "-1"))
	if loss_expected >= 0.0:
		## A few pings measure loss coarsely: allow three standard deviations for that many.
		var n := maxf(float(q["samples"]), 1.0)
		var loss_max := loss_expected + 3.0 * sqrt(loss_expected * (1.0 - loss_expected) / n) + 1.0 / n
		_check(q["loss"] <= loss_max, "the measured loss fits the simulated one (%.3f <= %.3f for %d pings)" % [q["loss"], loss_max, q["samples"]])
	if MpBoot.user_flag("probe-expect-jitter"):
		_check(q["jitter_ms"] > 1.0, "jitter on the simulated network is seen (%.1f ms)" % q["jitter_ms"])
	_check(mad < float(MpBoot.user_value("probe-max-mad", "0.05")), "its on-screen speed was steady frame to frame (low jitter)")


## The whole online path as a person does it, through MpLobbyScreen's buttons: connect, create or join, ready, play
## the match the room server starts, and come back to the lobby with the result. Options:
##   --probe-create=Room [--probe-private]       make the room (private: its code goes to --probe-code-file)
##   --probe-join-room=Room | --probe-join-code   join by name from the list, or with the code from the file
##   --probe-chat=text / --probe-expect-chat=text say something / wait to read it
##   --probe-leave-room-once                      leave the room once after sitting, and come back
##   --probe-leave-to-boot                        in the match: Mp.leave() to the lobby, then the lobby's Back to the boot
##   --probe-drop=rejoin|abandon                  in the match: leave it, and come back with the same ticket (or not)
##   --probe-delay-join-s=N                       join the match N seconds after the room server started it
##   --probe-check-paused                         the world must not move until every seat loaded
##   --probe-score=N (default 3 for the creator, 0 for the rest)  points this player scores (3 wins)
##   --probe-hold-s=N                             stay in the match N seconds before scoring
##   --probe-expect-back=N                        wait for MpState back_N before scoring
##   --probe-expect-error=code                    the lobby must answer this error instead of a match
##   --probe-expect-result=key:value              the room's result must have it (default winner present)
func _play_online() -> void:
	var flow_ok := await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	if not flow_ok:
		return
	await _until(func() -> bool: return _scene_has_button("Online rooms"), "the menu offers Online rooms")
	get_tree().change_scene_to_file(MpFlow.find_in_tree(self).lobby_path)
	var screens: Array[MpLobbyScreen] = []
	await _until(func() -> bool:
		if get_tree().current_scene is MpLobbyScreen:
			screens.append(get_tree().current_scene)
		return not screens.is_empty(), "the lobby screen opened")
	if screens.is_empty():
		return
	var screen := screens[0]
	await get_tree().process_frame
	_check(MpFlow.find_in_tree(self) != null, "the flow survived the scene change (it lives under the root)")
	var client := MpLobbyLink.client(get_tree())
	var errors: Array[String] = []
	client.error_received.connect(func(code: String) -> void: errors.append(code))
	var chat: Array[String] = []
	client.chat_received.connect(func(_seat: int, _who: String, text: String) -> void: chat.append(text))
	var delay := float(MpBoot.user_value("probe-delay-join-s", "0"))
	if delay > 0.0:
		screen.auto_join_match = false
		screen.match_found.connect(func(_h: String, _p: int, _t: String) -> void:
			await get_tree().create_timer(delay).timeout
			screen.join_found())
	screen.connect_lobby(MpBoot.user_value("probe-lobby", "127.0.0.1:7700"), MpBoot.user_value("probe-name", "Bot"))
	if not await _until(client.is_online, "connected to the lobby"):
		return
	await _enter_room(screen, client)
	if client.my_seat() < 0:
		return
	if MpBoot.user_flag("probe-leave-room-once"):
		screen.leave_room()
		await _until(func() -> bool: return client.my_seat() < 0, "left the room (back to the list)")
		await _enter_room(screen, client)
	var say := MpBoot.user_value("probe-chat", "")
	if not say.is_empty():
		await _until(func() -> bool: return _seated(client) >= 2, "the room is full before chatting")
		screen.send_chat(say)
	var expect_chat := MpBoot.user_value("probe-expect-chat", "")
	if not expect_chat.is_empty():
		await _until(func() -> bool: return chat.has(expect_chat), "the chat line arrived (%s)" % expect_chat)
	screen.set_ready(true)
	var expect_error := MpBoot.user_value("probe-expect-error", "")
	if not expect_error.is_empty():
		await _until(func() -> bool: return errors.has(expect_error), "the lobby answered %s" % expect_error)
		return
	await _until(_networked_slot, "the room server started the match and this client got in")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	if MpBoot.user_flag("probe-leave-to-boot"):
		await _leave_to_boot()
		return
	if MpBoot.user_flag("probe-check-paused"):
		var start_x: float = pawn.position.x
		Input.action_press(&"ui_right")
		await get_tree().create_timer(1.0).timeout
		_check(absf(pawn.position.x - start_x) < 1.0, "the world waits (paused) until every seat loaded")
		var leave_buttons := get_tree().current_scene.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b is MpLeaveButton)
		_check(not leave_buttons.is_empty() and (leave_buttons[0] as Node).can_process(), "the Leave button works while the world waits")
		Input.action_release(&"ui_right")
		await _pawn(2 if MpKit.local_slot() == 1 else 1)
		Input.action_press(&"ui_right")
		await _until(func() -> bool: return is_instance_valid(pawn) and pawn.position.x > start_x + 20.0, "once everyone loaded the match runs")
		Input.action_release(&"ui_right")
	var drop := MpBoot.user_value("probe-drop", "")
	if not drop.is_empty():
		await get_tree().create_timer(0.5).timeout
		MpKit.leave()
		_check(not MpKit.is_networked(), "left the match on purpose")
		if drop == "abandon":
			return
		## What a dropped connection does (MpKit emits server_lost): the flow takes the player back to the lobby,
		## which offers "Back to the match".
		MpKit.server_lost.emit()
		var back_screens: Array[MpLobbyScreen] = []
		await _until(func() -> bool:
			if get_tree().current_scene is MpLobbyScreen:
				back_screens.append(get_tree().current_scene)
			return not back_screens.is_empty(), "after the drop the player is back in the lobby")
		if back_screens.is_empty():
			return
		await _until(func() -> bool: return back_screens[0].can_rejoin(), "the lobby offers Back to the match")
		back_screens[0].rejoin_match()
		await _until(_networked_slot, "came back to the match with the same ticket")
		await _pawn(MpKit.local_slot())
	var back := MpBoot.user_value("probe-expect-back", "")
	if not back.is_empty():
		await _until(func() -> bool: return int(_state().get_value(StringName("back_%s" % back), 0)) >= 1, "the match saw P%s come back (player_back)" % back)
	await get_tree().create_timer(float(MpBoot.user_value("probe-hold-s", "0"))).timeout
	var creator := not MpBoot.user_value("probe-create", "").is_empty()
	## Like a person: score once the match runs (MpMatch keeps the world paused until every seat loaded, and a key
	## pressed while paused does nothing).
	await _until(func() -> bool:
		var match_node := Mp.current_match()
		return match_node != null and not match_node.waiting, "the match runs (every seat loaded)")
	for i in int(MpBoot.user_value("probe-score", "3" if creator else "0")):
		await _tap(&"ui_accept")
		await get_tree().create_timer(0.2).timeout
	await _until(func() -> bool: return get_tree().current_scene is MpLobbyScreen, "back in the lobby after the match")
	var want := MpBoot.user_value("probe-expect-result", "winner")
	await _until(func() -> bool:
		var result: Variant = client.room.get("last_result", {})
		if not result is Dictionary:
			return false
		var key := want.get_slice(":", 0)
		if not (result as Dictionary).has(key):
			return false
		return want.count(":") == 0 or str((result as Dictionary)[key]) == want.get_slice(":", 1), "the room shows the match result (%s)" % want)
	print("METRIC result=%s" % JSON.stringify(client.room.get("last_result", {})))


## Create or join a room the way the options say, and take a seat.
func _enter_room(screen: MpLobbyScreen, client: MpLobbyClient) -> void:
	var room_name := MpBoot.user_value("probe-create", "")
	var code_file := MpBoot.user_value("probe-code-file", "user://probe_room_code.txt")
	if not room_name.is_empty() and client.room.is_empty():
		screen.create_room(room_name, MpBoot.user_flag("probe-private"))
		await _until(func() -> bool: return client.my_seat() >= 0, "took a seat")
		if MpBoot.user_flag("probe-private"):
			await _until(func() -> bool: return client.room.has("code"), "the private room has a code")
			var f := FileAccess.open(code_file, FileAccess.WRITE)
			f.store_string(str(client.room["code"]))
			f.close()
		return
	if MpBoot.user_flag("probe-join-code"):
		await _until(func() -> bool: return FileAccess.file_exists(code_file), "the room's code was published")
		screen.join_code(FileAccess.get_file_as_string(code_file).to_lower())
	else:
		var wanted := MpBoot.user_value("probe-join-room", "")
		if not await _until(func() -> bool: return _listed_index(client, wanted) >= 0, "the room shows in the list"):
			return
		screen.join_room(str(client.rooms[_listed_index(client, wanted)]["id"]))
	await _until(func() -> bool: return client.my_seat() >= 0, "took a seat")


func _listed_index(client: MpLobbyClient, room_name: String) -> int:
	for i in client.rooms.size():
		if room_name.is_empty() or str(client.rooms[i]["name"]) == room_name:
			return i
	return -1


func _seated(client: MpLobbyClient) -> int:
	var n := 0
	for seat: Dictionary in client.room.get("seats", []):
		if not bool(seat["free"]):
			n += 1
	return n


func _host_private() -> void:
	await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	var server := MpLocalServer.start_on(get_tree(), 2)
	var info: Array = []
	server.server_ready.connect(func(_address: String, p_port: int, codes: Dictionary) -> void: info.append([p_port, codes[2]]))
	if not await _until(func() -> bool: return not info.is_empty(), "the private match process listens"):
		return
	var f := FileAccess.open(MpBoot.user_value("probe-code-file", "user://probe_code.txt"), FileAccess.WRITE)
	f.store_string("%d %s" % info[0])
	f.close()
	await _until(_networked_slot, "the host joined its own private match")
	_check(MpLocalServer.start_on(get_tree(), 2) == server, "a second Private server gives the running one back")
	var code: String = info[0][1]
	await _until(func() -> bool:
		var labels := get_tree().current_scene.find_children("*", "Label", true, false).filter(func(l: Node) -> bool: return l is MpInviteLabel)
		return not labels.is_empty() and (labels[0] as Label).visible and (labels[0] as Label).text.contains("%d#%s" % [info[0][0], code]), "the match HUD shows the invite (port and code)")
	var other := await _pawn(2)
	if other == null:
		return
	for i in 3:
		await _tap(&"ui_accept")
		await get_tree().create_timer(0.2).timeout
	await _until(func() -> bool: return not MpKit.is_networked(), "after the win the host left the match")
	await _until(func() -> bool: return get_tree().root.get_node_or_null("MpLocalServer") == null, "the private server cleaned up")


## An online room this process hosts through the issuer: the code goes to the code file, every seat fills, the host wins
## and the room closes.
func _host_online() -> void:
	await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	var flow := MpFlow.find_in_tree(self)
	var players := int(MpBoot.user_value("probe-players", "2"))
	var ticket: Variant = JSON.parse_string(MpBoot.user_value("probe-ticket", "{}"))
	var online := flow.host_online(players, MpBoot.user_value("probe-room-name", "Lab room"), true, ticket if ticket is Dictionary else {})
	_check(online != null, "host_online opened a room")
	if online == null:
		return
	if ticket is Dictionary and not (ticket as Dictionary).is_empty():
		_check(online.ticket == ticket, "the room keeps the game's ticket (MpOnline.ticket)")
	var codes: Array = []
	online.room_ready.connect(func(c: String) -> void: codes.append(c))
	online.failed.connect(func(reason: String) -> void: print("online failed: ", reason))
	if not await _until(func() -> bool: return not codes.is_empty(), "the online room is up (%s)" % online.mode):
		return
	var code: String = codes[0]
	_check(flow.host_online(players) == online, "a second host_online gives the running room back")
	var f := FileAccess.open(MpBoot.user_value("probe-code-file", "user://probe_code.txt"), FileAccess.WRITE)
	f.store_string(code)
	f.close()
	await _until(func() -> bool: return MpKit.is_networked() and MpKit.has_local_slot(), "the host plays in its own room")
	await _until(func() -> bool:
		var labels := get_tree().current_scene.find_children("*", "Label", true, false).filter(func(l: Node) -> bool: return l is MpInviteLabel)
		return not labels.is_empty() and (labels[0] as Label).visible and (labels[0] as Label).text.contains(code), "the match HUD shows the room code")
	for slot in range(2, players + 1):
		if await _pawn(slot) == null:
			return
	var wait_file := MpBoot.user_value("probe-wait-file", "")
	if not wait_file.is_empty():
		await _until(func() -> bool: return FileAccess.file_exists(wait_file), "the script let the match go on")
	## Score until the win, as a person would: a press before the match started (the gate waits for the other world
	## to load) counts for nothing.
	var taps := 0
	while MpKit.is_networked() and taps < 80:
		await _tap(&"ui_accept")
		await get_tree().create_timer(0.25).timeout
		taps += 1
	_check(not MpKit.is_networked(), "the host won and left the match (%d presses)" % taps)
	await _until(func() -> bool: return MpOnline.running(get_tree()) == null, "the room closed on the issuer once the match ended")


## A friend: the code from the host's file (as a person types it: lower case, a dash), or the room found in the list.
func _join_online(from_list: bool) -> void:
	var transport_before := MpKit.transport
	var path := MpBoot.user_value("probe-code-file", "user://probe_code.txt")
	var by_name := MpBoot.user_value("probe-find-name", "")
	var code := ""
	if by_name.is_empty():
		if not await _until(func() -> bool: return FileAccess.file_exists(path), "the host published its code"):
			return
		code = FileAccess.get_file_as_string(path).strip_edges()
	await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	var flow := MpFlow.find_in_tree(self)
	var finished: Array = []
	flow.match_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	var statuses: Array = []
	flow.status_changed.connect(func(text: String) -> void: statuses.append(text))
	var silent: Array = []
	MpKit.host_silent.connect(func(seconds: float) -> void: silent.append(seconds))
	MpKit.host_back.connect(func() -> void: silent.append(-1.0))
	var typed := code
	if from_list:
		var rows: Array = []
		var found: Array = []
		while found.is_empty() and rows.size() < 160:
			var listed: Array = await flow.online_rooms()
			found = listed.filter(func(r: Dictionary) -> bool: return r.get("code", "") == code if by_name.is_empty() else r.get("name", "") == by_name)
			rows.append(listed.size())
			if found.is_empty():
				await get_tree().create_timer(0.25).timeout
		_check(not found.is_empty(), "the room is in the issuer's list")
		if found.is_empty():
			return
		_check(found[0].get("name", "") == (by_name if not by_name.is_empty() else "Lab room") and int(found[0].get("max_players", 0)) >= 2, "the list shows its name and seats")
		code = str(found[0].get("code", ""))
		print("PROBE online_list host %s" % found[0].get("platform", "?"))
		typed = code
	else:
		typed = (code.substr(0, 3) + "-" + code.substr(3)).to_lower()
	var err: Error = await flow.join_online(typed)
	_check(err == OK, "join_online(%s) connects" % typed)
	await _until(_networked_slot, "the friend got a seat in the online room")
	await _pawn(MpKit.local_slot())
	if MpBoot.user_flag("probe-expect-silence"):
		print("PROBE online_join seated")
		await _until(func() -> bool: return silent.has(-1.0) and silent.any(func(s: float) -> bool: return s > 0.0), "the host froze (host_silent) and came back (host_back)")
		_check(statuses.has(flow.host_silent_status), "the menu said it waits for the host")
		_check(MpKit.is_networked(), "the friend stayed in the match through the freeze")
	await _until(func() -> bool: return not finished.is_empty(), "the friend saw the match end")
	flow.return_to_boot()
	await _until(func() -> bool: return MpKit.transport == transport_before, "back in the menu the game's transport is still %s (the online room used the relay for its own connection)" % transport_before)


## A host opens a room and stops it on purpose (a Close button): it ends, never fails, and leaves nothing behind.
func _stop_online() -> void:
	await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	var flow := MpFlow.find_in_tree(self)
	var online := flow.host_online(2, "Closing room")
	var codes: Array = []
	var failed: Array = []
	var ended: Array = []
	online.room_ready.connect(func(c: String) -> void: codes.append(c))
	online.failed.connect(func(reason: String) -> void: failed.append(reason))
	online.ended.connect(func() -> void: ended.append(true))
	if MpBoot.user_flag("probe-stop-early"):
		## The game's own room screen: Back before the match (here the boot scene stands in for it).
		await _until(func() -> bool: return not online.code.is_empty(), "the issuer gave the room a code")
		var early_code := online.code
		var scene := get_tree().current_scene
		online.stop()
		await _until(func() -> bool: return not ended.is_empty(), "stop() ends the room before its match started")
		await get_tree().create_timer(1.0).timeout
		_check(get_tree().current_scene == scene and not flow.in_world(), "the scene stays where the game was (no trip to the world or the boot)")
		_check(failed.is_empty(), "stop() is not a failure (failed: %s)" % [failed])
		await _until(func() -> bool: return MpLocalServer.running(get_tree()) == null and MpOnline.running(get_tree()) == null, "no private server or online room left")
		var early: Dictionary = await MpIssuer.join_room(get_tree(), early_code)
		_check(str(early.get("error", "")) == "no_such_room", "the issuer forgot the room (%s)" % early.get("error", "joined"))
		return
	if not await _until(func() -> bool: return not codes.is_empty(), "the room is up (%s)" % online.mode):
		return
	await _until(func() -> bool: return flow.in_world() and MpKit.has_local_slot(), "the host is in its match world (MpFlow.in_world)")
	online.stop()
	await _until(func() -> bool: return not ended.is_empty(), "stop() ends the room")
	await _until(func() -> bool: return not MpKit.is_networked() and get_tree().current_scene.name == "Boot" and not flow.in_world(), "from the match world the host is back in the menu, offline")
	_check(failed.is_empty(), "stop() is not a failure (failed: %s)" % [failed])
	await _until(func() -> bool: return MpLocalServer.running(get_tree()) == null and MpOnline.running(get_tree()) == null, "no private server or online room left")
	var gone: Dictionary = await MpIssuer.join_room(get_tree(), str(codes[0]))
	_check(str(gone.get("error", "")) == "no_such_room", "the issuer forgot the room (%s)" % gone.get("error", "joined"))


## The issuer turns this join away with `--probe-expect=` (room_full, no_such_room…), and nothing connects.
func _refused_online() -> void:
	var path := MpBoot.user_value("probe-code-file", "user://probe_code.txt")
	var code := MpBoot.user_value("probe-room", "")
	if code.is_empty():
		if not await _until(func() -> bool: return FileAccess.file_exists(path), "the host published its code"):
			return
		code = FileAccess.get_file_as_string(path).strip_edges()
	var word := MpBoot.user_value("probe-expect", "room_full")
	await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	var flow := MpFlow.find_in_tree(self)
	var statuses: Array = []
	flow.status_changed.connect(func(text: String) -> void: statuses.append(text))
	var err: Error = await flow.join_online(code)
	_check(err != OK and not MpKit.is_networked(), "the join of %s was turned away" % code)
	_check(statuses.has(flow.online_text(word)), "the menu said why: %s" % flow.online_text(word))


## Walks down and up at a steady speed, in legs of LEG_S: the lag shooter's moving target.
func _walk_as_target() -> void:
	await _until(_networked_slot, "the target got a slot")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	await get_tree().create_timer(1.0).timeout
	var legs := int(MpBoot.user_value("probe-legs", "8"))
	for i in legs:
		var key := &"ui_down" if i % 2 == 0 else &"ui_up"
		Input.action_press(key)
		await get_tree().create_timer(1.0 if i == 0 else 2.0).timeout
		Input.action_release(key)
	print("METRIC target_hits=%d" % pawn.hits)


## Shoots, with a lead, at another player walking past (as a person aims at what is on the screen). With lag
## compensation the server checks against what this player saw, so the shots hit; `--probe-expect-hits=N` / with
## `--probe-expect-misses` the server runs without it and most shots must miss.
func _shoot_moving_target() -> void:
	await _until(_networked_slot, "the shooter got a slot")
	var me := await _pawn(MpKit.local_slot())
	var target := await _pawn(2 if MpKit.local_slot() == 1 else 1)
	if me == null or target == null:
		return
	## Closer first, so every shot reaches it within its life.
	Input.action_press(&"ui_right")
	await _until(func() -> bool: return absf(target.position.x - me.position.x) < 180.0, "the shooter walked near the target")
	Input.action_release(&"ui_right")
	var start_y: float = target.position.y
	await _until(func() -> bool: return absf(target.position.y - start_y) > 30.0, "the target walks")
	var aimer := _Aimer.new()
	aimer.process_priority = 30000
	add_child(aimer)
	aimer.input = me.get_node("MpInput") as MpInput
	var shots := int(MpBoot.user_value("probe-shots", "4"))
	var hits_before: int = target.hits
	for i in shots:
		## Mid-leg (after it turns, as a person waits for a steady target): its velocity on screen, then lead it.
		var y0: float = target.position.y
		await get_tree().create_timer(0.05).timeout
		var dir0 := signf(target.position.y - y0)
		var last := [target.position.y]
		await _until(func() -> bool:
			var moved: float = target.position.y - float(last[0])
			last[0] = target.position.y
			return absf(moved) > 0.5 and signf(moved) == -dir0, "the target turned (shot %d)" % (i + 1))
		await get_tree().create_timer(0.35).timeout
		var p0: Vector2 = target.position
		await get_tree().create_timer(0.1).timeout
		var velocity: Vector2 = (target.position - p0) / 0.1
		var aim_at: Vector2 = target.position
		for _iter in 3:
			aim_at = target.position + velocity * (me.position.distance_to(aim_at) / 600.0)
		aimer.aim = (aim_at - me.position).normalized()
		print("LAGSHOT me=%s target=%s v=%s aim=%s" % [me.position, target.position, velocity, aimer.aim])
		await get_tree().create_timer(0.05).timeout
		await _tap(&"ui_select")

		await get_tree().create_timer(0.9).timeout
	var hits: int = target.hits - hits_before
	print("METRIC lag_shots=%d lag_hits=%d view_delay_ms=%.0f" % [shots, hits, MpNetClock.view_delay * 1000.0])
	aimer.queue_free()
	if MpBoot.user_flag("probe-expect-misses"):
		_check(hits <= 1, "without lag compensation most led shots miss (%d of %d hit)" % [hits, shots])
	else:
		_check(hits >= int(MpBoot.user_value("probe-expect-hits", str(shots - 1))), "with lag compensation the led shots hit (%d of %d)" % [hits, shots])


## Another process of this PC runs its own private server for a moment: the first one's match must survive it.
func _other_private_server() -> void:
	await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	var server := MpLocalServer.start_on(get_tree(), 2, {}, false)
	var ready: Array = []
	server.server_ready.connect(func(_a: String, _p: int, _c: Dictionary) -> void: ready.append(true))
	await _until(func() -> bool: return not ready.is_empty(), "a second private server on the same PC listens too")
	server.stop()


func _join_private(right_code: bool) -> void:
	var path := MpBoot.user_value("probe-code-file", "user://probe_code.txt")
	if not await _until(func() -> bool: return FileAccess.file_exists(path), "the host published its code"):
		return
	var parts := FileAccess.get_file_as_string(path).split(" ")
	var code := parts[1] if right_code else "WRONG9"
	var rejected: Array = []
	MpKit.admission_rejected.connect(func(reason: String) -> void: rejected.append(reason))
	await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	var flow := MpFlow.find_in_tree(self)
	var finished: Array = []
	flow.match_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	flow.join_address("127.0.0.1:%s#%s" % [parts[0], code.to_lower()])
	if not right_code:
		await _until(func() -> bool: return not rejected.is_empty(), "a wrong code is turned away")
		return
	await _until(_networked_slot, "the friend got in with the code (typed in lower case)")
	await _pawn(2)
	await _until(func() -> bool: return not finished.is_empty(), "the friend saw the match end")


## Joining an address nobody serves fails cleanly: the failure is reported and the menu still plays solo.
func _check_fail_join() -> void:
	await _until(func() -> bool: return _join_failed or _server_lost, "joining a dead address is reported as failed")
	await _until(func() -> bool: return not MpKit.is_networked(), "after the failure this process is offline again")
	MpFlow.find_in_tree(self).play_solo()
	await _pawn(1)


## A peer the server turns away (full, wrong transport) never gets a slot and ends offline.
func _check_refused() -> void:
	var waited := Time.get_ticks_msec()
	await _until(func() -> bool: return _join_failed or _server_lost or _rejected != "" or Time.get_ticks_msec() - waited > 6000, "the connection ended or timed out")
	_check(not (MpKit.is_networked() and MpKit.has_local_slot()), "the refused peer never got a slot")
	await _until(func() -> bool: return not MpKit.is_networked() or Time.get_ticks_msec() - waited > 15000, "the refused peer ends offline (or still waiting, harmless)")


## Leave to the menu (the Leave button) and come back: a new pawn, the server forgot the old one.
func _leave_and_return() -> void:
	await _until(_networked_slot, "the leaver got a slot")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	var flow := MpFlow.find_in_tree(self)
	flow.return_to_boot()
	await _until(func() -> bool: return get_tree().current_scene.name == "Boot" and not MpKit.is_networked(), "Leave goes back to the menu, offline")
	await get_tree().create_timer(1.0).timeout
	flow.join_address("127.0.0.1:%s" % MpBoot.user_value("mp-port", "7777"))
	await _until(_networked_slot, "joining again gets a slot")
	await _pawn(MpKit.local_slot())


## Server side of the leaver: the pawn goes when its player leaves and comes back when it joins again.
func _watch_leave_and_return() -> void:
	await _until(func() -> bool: return MpKit.is_server(), "this process is the server")
	await _pawn(1)
	await _until(func() -> bool: return _in_world("Actors/Pawn_1") == null, "the pawn of a player who left is removed")
	await _pawn(1)


## The server goes away: the client is told and lands on the menu.
func _check_server_lost() -> void:
	await _until(_networked_slot, "the client got a slot")
	await _pawn(MpKit.local_slot())
	print("READY for the server to go")
	await _until(func() -> bool: return _server_lost, "the client noticed the server went away")
	await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "Boot", "and is back on the menu")


## A listen host advertises on the LAN; this client finds it in the boot menu's list and joins from there.
func _browse_lan() -> void:
	var menus: Array[MpBootMenu] = []
	await _until(func() -> bool:
		var found := get_tree().get_nodes_in_group(MpBootMenu.GROUP)
		if not found.is_empty():
			menus.append(found[0])
		return not menus.is_empty(), "the boot menu is up")
	if menus.is_empty():
		return
	var menu := menus[0]
	if not await _until(func() -> bool: return not menu.lan_rooms().is_empty(), "the menu's LAN list shows the host (MpLan)"):
		return
	menu.join_lan_room(0)
	await _until(_networked_slot, "joining from the LAN list gets a slot")
	await _pawn(MpKit.local_slot())


func _flood() -> void:
	await _until(_networked_slot, "the flooding client got a slot")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	var net := MpActor.of(pawn)
	for i in 500:
		MpKit.send_custom(&"spam", {"i": i})
		net.to_server(&"recolor")
	print("PASS sent 500 tunnel messages and 500 server calls")


func _watch_flood() -> void:
	await _until(func() -> bool: return MpKit.is_server(), "this process is the server")
	var got: Array[int] = [0]
	MpKit.custom_received.connect(func(_c: StringName, _d: Dictionary, from_peer: int) -> void:
		if from_peer != 1:
			got[0] += 1)
	var pawn := await _pawn(1)
	if pawn == null:
		return
	await _until(func() -> bool: return got[0] > 0, "the first tunnel messages arrived")
	await get_tree().create_timer(2.0).timeout
	print("METRIC tunnel_accepted=%d server_calls_accepted=%d (of 500 each)" % [got[0], pawn.color_index])
	_check(got[0] >= 50 and got[0] <= 60 + 30 * 4, "the tunnel let the burst in and dropped the flood")
	_check(pawn.color_index >= 100 and pawn.color_index <= 120 + 60 * 4, "to_server let the burst in and dropped the flood")


func _pawn(slot: int) -> Node:
	var found: Array[Node] = []
	var ok := await _until(func() -> bool:
		var scene := get_tree().current_scene
		var node := _in_world("Actors/Pawn_%d" % slot) if scene else null
		if node:
			found.append(node)
		return node != null, "P%d exists here" % slot)
	return found[0] if ok else null


## In a match: Mp.leave() goes back to the lobby, and the lobby's Back goes to the game's boot scene.
func _leave_to_boot() -> void:
	await _until(func() -> bool: return Mp.current_match() != null and not Mp.current_match().waiting, "the match runs (every seat loaded)")
	await get_tree().create_timer(0.5).timeout
	Mp.leave()
	var back: Array[MpLobbyScreen] = []
	await _until(func() -> bool:
		if get_tree().current_scene is MpLobbyScreen:
			back.append(get_tree().current_scene)
		return not back.is_empty(), "Mp.leave() took the player back to the lobby")
	if back.is_empty():
		return
	back[0].go_back()
	var boot := MpFlow.find_in_tree(self).boot_path
	await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == boot, "the lobby's Back went to the game's boot scene (%s)" % boot)


func _scene_has_button(text: String) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return not scene.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == text).is_empty()


func _keep_pawns() -> void:
	for spawner in get_tree().current_scene.find_children("*", "MpSlotSpawner", true, false):
		spawner.despawn_on_leave = false
		if MpKit.peer_left.is_connected(spawner._on_slot_peer_left):
			MpKit.peer_left.disconnect(spawner._on_slot_peer_left)


func _report_world_later() -> void:
	if _in_world("Actors") == null:
		return
	await get_tree().create_timer(float(MpBoot.user_value("probe-report-after", "1"))).timeout
	var flow := MpFlow.find_in_tree(self)
	if flow == null or _in_world("Actors") == null:
		return
	_check(get_tree().paused, "the world held (paused) until it reported itself loaded")
	flow.report_world_loaded()
	await get_tree().process_frame
	_check(not get_tree().paused or MpKit.gate.is_waiting(), "after its report the world runs, or waits only for others")


## A node of the world by its path: under the MpWorld when the world has one, under the scene otherwise.
func _in_world(path: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var world := MpWorld.of(scene)
	return world.get_node_or_null(path) if world else scene.get_node_or_null(path)


func _networked_slot() -> bool:
	return MpKit.is_networked() and not MpKit.is_server() and MpKit.has_local_slot()


func _state() -> MpState:
	var state := MpState.of(get_tree().current_scene)
	if state == null and _empty_state == null:
		_empty_state = MpState.new()
	return state if state else _empty_state


func _tap(action: StringName) -> void:
	Input.action_press(action)
	for i in 3:
		await get_tree().physics_frame
	Input.action_release(action)


func _until(cond: Callable, what: String) -> bool:
	var end := Time.get_ticks_msec() + int(step_timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if get_tree().current_scene != null and cond.call():
			_check(true, what)
			return true
		await get_tree().process_frame
	_check(false, what)
	return false


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


## Holds the owner's aim after the player script set it from the mouse (runs later in the frame).
class _Aimer extends Node:
	var input: MpInput
	var aim: Vector2 = Vector2.RIGHT

	func _process(_delta: float) -> void:
		if input:
			input.set_value(&"aim", aim)


class _Sampler extends Node:
	var target: Node2D
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	var ts := PackedInt64Array()

	func _process(_delta: float) -> void:
		if not is_instance_valid(target):
			return
		xs.append(target.position.x)
		ys.append(target.position.y)
		ts.append(Time.get_ticks_usec())
