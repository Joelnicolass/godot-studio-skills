extends "res://addons/mp_kit/tests/mp_test.gd"

## A web build's `?issuer=` (a local issuer for tests): only a local address is taken, never another server.


func test_only_a_local_issuer_is_taken() -> void:
	var read := MpIssuer.local_issuer_from_query
	check(read.call("?issuer=http://127.0.0.1:8891") == "http://127.0.0.1:8891", "127.0.0.1 with its port")
	check(read.call("?x=1&issuer=http%3A%2F%2Flocalhost%3A8891%2F") == "http://localhost:8891", "localhost, encoded")
	check(read.call("?issuer=http://[::1]:8891") == "http://[::1]:8891", "[::1]")
	check(read.call("?issuer=https://127.0.0.1") == "https://127.0.0.1", "https, no port")
	check(read.call("?issuer=https://issuer.example.com") == "", "another server: no")
	check(read.call("?issuer=http://127.0.0.1.evil.com:80") == "", "a name that starts like 127.0.0.1: no")
	check(read.call("?issuer=http://localhost@evil.com") == "", "a user part: no")
	check(read.call("?issuer=ws://127.0.0.1:8891") == "", "not http(s): no")
	check(read.call("") == "" and read.call("?other=http://127.0.0.1") == "", "no issuer: nothing")
