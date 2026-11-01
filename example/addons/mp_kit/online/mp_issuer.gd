class_name MpIssuer
extends RefCounted

## Client of the MpKit issuer (addons/mp_kit/issuer): the rooms players host, a seat in one, the list of public ones.
## Every call says who asks: the game, its version (Project Settings › Application › Config › Version), the kit's,
## the platform and this install's id (random, kept in user://); the issuer reads the IP itself. Each answers
## `{ok, status, data, error}`: `data` is the issuer's JSON, `error` its word ("room_full", "version_mismatch"…) or
## "network" when it could not be reached. Settings: `url` and `game`, from MpNetConfig (issuer_url, game_id) or
## `--issuer-url=` / `--issuer-game=`. A seat the issuer hands out is this player's own ticket: it is remembered per room
## and shown again on the next join of that room (a rejoin gets the same seat; nobody else can get it while the player
## holds it). Not: the room's life (MpOnline) or the relay connection (MpTransport).

const INSTALL_FILE := "user://mpkit_install_id"
const TIMEOUT_S := 10.0

## The issuer's address (https://issuer.example.com). Empty = online rooms are off.
static var url: String = ""
## This game's id on the issuer (its ISSUER_GAMES key). Empty = MpTransport.relay_room.
static var game: String = ""
static var _install: String = ""
static var _session: String = ""
## Room code (as the issuer writes it) -> the seat ticket this process got there.
static var _seat_tickets: Dictionary = {}


## The flags win over what an MpNetConfig set.
static func from_flags() -> void:
	var flag_url := MpBoot.user_value("issuer-url", "")
	var flag_game := MpBoot.user_value("issuer-game", "")
	if not flag_url.is_empty():
		url = flag_url
	if not flag_game.is_empty():
		game = flag_game


static func is_configured() -> bool:
	from_flags()
	return not url.is_empty()


## What every request says about this player (never the IP: the issuer takes it from the connection).
static func who() -> Dictionary:
	from_flags()
	MpTransport.relay_from_flags()
	return {
		"game": game if not game.is_empty() else MpTransport.relay_room,
		"version": game_version(),
		"kit": MpKit.VERSION,
		"platform": OS.get_name().substr(0, 24),
		"install": install_id(),
		"session": session_id(),
	}


## The game's version (Project Settings › Application › Config › Version, "0" when unset). Joining needs the host's.
static func game_version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	return v if not v.is_empty() else "0"


## A random id for this install, made once and kept in user:// (also in a browser): the issuer's limits and bans
## count installs. `--issuer-install=` replaces it (tests: several processes as several PCs).
static func install_id() -> String:
	if not _install.is_empty():
		return _install
	var flag := MpBoot.user_value("issuer-install", "")
	if not flag.is_empty():
		_install = flag
		return _install
	var saved := FileAccess.get_file_as_string(INSTALL_FILE).strip_edges()
	if saved.length() >= 16 and saved.length() <= 64 and saved.is_valid_hex_number():
		_install = saved
		return _install
	_install = Crypto.new().generate_random_bytes(16).hex_encode()
	var f := FileAccess.open(INSTALL_FILE, FileAccess.WRITE)
	if f:
		f.store_string(_install)
	return _install


## New in each process: a player asking again for a seat gets the same one, a second copy of the game on the same PC
## (the editor's Run Multiple Instances) gets its own.
static func session_id() -> String:
	if _session.is_empty():
		_session = Crypto.new().generate_random_bytes(8).hex_encode()
	return _session


## A room this player hosts. `mode` "dedicated" (a match process hosts; `seats` = one admission ticket per seat but
## the host's) or "listen" (this game hosts; no tickets).
static func create_room(tree: SceneTree, max_players: int, room_name: String, listed: bool, mode: String, seats: PackedStringArray = PackedStringArray()) -> Dictionary:
	var body := who()
	body.merge({"name": room_name, "max_players": max_players, "visibility": "public" if listed else "private", "mode": mode, "seats": Array(seats)})
	return await request(tree, HTTPClient.METHOD_POST, "/v1/rooms", body)


## A seat in room `code` (as typed: lower case and dashes are fine): its relay room, a token and (dedicated) the ticket,
## this player's own. `ticket` (or, empty, the one this process got in that room before) asks for that seat back: the
## issuer gives it to whoever shows it, from this machine or another.
static func join_room(tree: SceneTree, code: String, ticket: String = "") -> Dictionary:
	var room := normalize_code(code)
	var body := who()
	var own := ticket if not ticket.is_empty() else str(_seat_tickets.get(room, ""))
	if not own.is_empty():
		body["ticket"] = own
	var answer: Dictionary = await request(tree, HTTPClient.METHOD_POST, "/v1/rooms/%s/join" % room.uri_encode(), body)
	## A ticket remembered from an earlier room that had this code: ask for a seat as a newcomer.
	if not answer["ok"] and str(answer["error"]) == "bad_ticket" and ticket.is_empty() and body.has("ticket"):
		_seat_tickets.erase(room)
		body.erase("ticket")
		answer = await request(tree, HTTPClient.METHOD_POST, "/v1/rooms/%s/join" % room.uri_encode(), body)
	if answer["ok"] and answer["data"].get("ticket") != null:
		_seat_tickets[room] = str(answer["data"]["ticket"])
	return answer


## The seat ticket this process got in room `code` ("" if none): show it to let the player come back from another machine
## (join_online(code, ticket)). It is a secret: whoever has it takes that seat.
static func seat_ticket(code: String) -> String:
	return str(_seat_tickets.get(normalize_code(code), ""))


## A room code as the issuer writes it: upper case, no spaces or dashes ("k7f-3qx" -> "K7F3QX").
static func normalize_code(code: String) -> String:
	return code.strip_edges().to_upper().replace("-", "").replace(" ", "")


## The public rooms of this game and version with a free seat: `data.rooms` = [{code, name, players, max_players, state, platform, age_s}].
static func list_rooms(tree: SceneTree) -> Dictionary:
	var query := PackedStringArray()
	var asker := who()
	for k in asker.keys():
		query.append("%s=%s" % [k, str(asker[k]).uri_encode()])
	return await request(tree, HTTPClient.METHOD_GET, "/v1/rooms?" + "&".join(query))


## The host's fresh token for its own room ("host" for the match process, "client" for the host player).
static func tokens(tree: SceneTree, code: String, key: String, role: String) -> Dictionary:
	return await request(tree, HTTPClient.METHOD_POST, "/v1/rooms/%s/tokens" % code, {"role": role}, key)


## The host is alive: players in (the host counts), "open" or "playing", and (dedicated) the tickets nobody else may get
## (`taken`: connected, or closed) and the ones a player holds, connected or away within its grace (`held`: the issuer
## gives those to their own player only).
static func heartbeat(tree: SceneTree, code: String, key: String, players: int, state: String, taken: PackedStringArray = PackedStringArray(), held: PackedStringArray = PackedStringArray()) -> Dictionary:
	return await request(tree, HTTPClient.METHOD_PUT, "/v1/rooms/%s" % code, {"players": players, "state": state, "taken": Array(taken), "held": Array(held)}, key)


static func close_room(tree: SceneTree, code: String, key: String) -> Dictionary:
	return await request(tree, HTTPClient.METHOD_DELETE, "/v1/rooms/%s" % code, {}, key)


## One HTTP call to the issuer. `key` (the room key) goes as `Authorization: Bearer`.
static func request(tree: SceneTree, method: int, path: String, body: Dictionary = {}, key: String = "") -> Dictionary:
	from_flags()
	if url.is_empty():
		return {"ok": false, "status": 0, "data": {}, "error": "no_issuer"}
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_S
	## A match pauses the tree while it waits for its seats: the call that brings them must go on.
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	var text := ""
	if method != HTTPClient.METHOD_GET and not body.is_empty():
		headers.append("Content-Type: application/json")
		text = JSON.stringify(body)
	if not key.is_empty():
		headers.append("Authorization: Bearer " + key)
	var err := http.request(url.trim_suffix("/") + path, headers, method, text)
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": {}, "error": "network"}
	var answer: Array = await http.request_completed
	http.queue_free()
	return read_answer(int(answer[0]), int(answer[1]), answer[3] as PackedByteArray)


## `request_completed`'s result, code and body as `{ok, status, data, error}` (public for tests).
static func read_answer(result: int, status: int, bytes: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": {}, "error": "network"}
	var json := JSON.new()
	var data: Dictionary = {}
	if not bytes.is_empty() and json.parse(bytes.get_string_from_utf8()) == OK and json.data is Dictionary:
		data = json.data
	var ok := status >= 200 and status < 300
	return {"ok": ok, "status": status, "data": data, "error": "" if ok else str(data.get("error", "http_%d" % status))}
