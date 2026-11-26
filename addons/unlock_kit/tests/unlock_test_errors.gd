extends Logger

## Counts the GDScript runtime errors (SCRIPT ERROR: a null access, a bad call) that happen while a
## test runs, so a test that stops on one fails instead of passing with the checks it never reached.
## The runner adds it with OS.add_logger(). Logger exists from Godot 4.5 on; older, the runner goes
## without it and only the checks count.

var _count := 0
var _lock := Mutex.new()


func _log_error(
	_function: String,
	_file: String,
	_line: int,
	_code: String,
	_rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace],
) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_lock.lock()
	_count += 1
	_lock.unlock()


## The script errors since the last call.
func take() -> int:
	_lock.lock()
	var seen := _count
	_count = 0
	_lock.unlock()
	return seen
