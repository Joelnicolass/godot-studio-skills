extends RefCounted

## Stands in for the editor's undo history in the paint tool's tests: it writes down every call.

var calls: Array = []


func create_action(name: String, merge: int, context: Object) -> void:
	calls.append(["create_action", name, merge, context])


func add_do_method(object: Object, method: StringName, ...args: Array) -> void:
	calls.append(["add_do_method", object, method, args])


func add_undo_method(object: Object, method: StringName, ...args: Array) -> void:
	calls.append(["add_undo_method", object, method, args])


func add_do_property(object: Object, property: StringName, value: Variant) -> void:
	calls.append(["add_do_property", object, property, value])


func add_undo_property(object: Object, property: StringName, value: Variant) -> void:
	calls.append(["add_undo_property", object, property, value])


func add_do_reference(object: Object) -> void:
	calls.append(["add_do_reference", object])


func commit_action(execute := true) -> void:
	calls.append(["commit_action", execute])
	if execute:
		for entry: Array in calls:
			if entry[0] == "add_do_property":
				(entry[1] as Object).set(entry[2], entry[3])


## Applies the undo properties that were recorded.
func undo() -> void:
	for entry: Array in calls:
		if entry[0] == "add_undo_property":
			(entry[1] as Object).set(entry[2], entry[3])


## The names of the calls, in order.
func names() -> Array[String]:
	var list: Array[String] = []
	for entry: Array in calls:
		list.append(entry[0])
	return list
