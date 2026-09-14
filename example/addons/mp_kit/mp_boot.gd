class_name MpBoot
extends RefCounted

## Detect a dedicated-server process. Does not start the peer — glue calls MpKit.host_dedicated().
## Do not treat `--headless` alone as dedicated (CI / GUT also run headless).


static func is_dedicated_process() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	return user_flag("dedicated")


static func user_flag(name: String) -> bool:
	var needle := "--%s" % name
	for arg in OS.get_cmdline_user_args():
		if arg == needle or arg.begins_with(needle + "="):
			return true
	return false


static func user_value(name: String, default: String = "") -> String:
	var prefix := "--%s=" % name
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return default
