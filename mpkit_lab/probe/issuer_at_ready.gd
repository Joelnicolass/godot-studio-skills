extends Node

## A boot scene that lists the online rooms at start, the way a game does: MpIssuer.request from its _ready, while the
## root is still busy setting up its children. Run as the main scene:
##   godot --headless --path mpkit_lab res://probe/issuer_at_ready.tscn
## A local TCP server stands in for the issuer; the request reaching it is what counts. Prints MPKIT ISSUER AT READY
## PASS (exit 0) or FAIL (exit 1). MpKit 0.25.0 and older: add_child failed there and the request never left
## (ERR_UNCONFIGURED).

const PORT := 47913

var _server := TCPServer.new()


func _ready() -> void:
	if _server.listen(PORT, "127.0.0.1") != OK:
		_end(false, "a stand-in issuer could not listen on %d" % PORT)
		return
	MpIssuer.url = "http://127.0.0.1:%d" % PORT
	MpIssuer.request(get_tree(), HTTPClient.METHOD_GET, "/v1/rooms")
	for i in 300:
		await get_tree().process_frame
		if _server.is_connection_available():
			_server.take_connection().disconnect_from_host()
			_end(true, "a request asked from the boot scene's _ready reached the issuer")
			return
	_end(false, "a request asked from the boot scene's _ready never reached the issuer")


func _end(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	print("MPKIT ISSUER AT READY " + ("PASS" if ok else "FAIL"))
	_server.stop()
	get_tree().quit(0 if ok else 1)
