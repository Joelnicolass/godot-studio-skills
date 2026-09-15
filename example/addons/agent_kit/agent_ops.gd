class_name AgentOps
extends RefCounted


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func fs_path(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return ""
	if (
		trimmed.begins_with("res://")
		or trimmed.begins_with("user://")
	):
		return ProjectSettings.globalize_path(trimmed)
	return trimmed


static func ensure_parent_dir(path: String) -> void:
	var abs_path := fs_path(path)
	var dir_path := abs_path.get_base_dir()
	if dir_path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir_path)


static func current_scene(tree: SceneTree) -> Node:
	return tree.current_scene


static func resolve(from: Node, spec: String) -> Node:
	if from == null:
		return null
	var trimmed := spec.strip_edges()
	if trimmed.is_empty():
		return from
	var node := from
	for part in trimmed.split("/"):
		if part.is_empty():
			continue
		var next := node.get_node_or_null(NodePath(part))
		if next == null and part.begins_with("%"):
			next = find_unique(node, part.substr(1))
		if next == null:
			return null
		node = next
	return node


static func find_unique(from: Node, unique: String) -> Node:
	if from == null or unique.strip_edges().is_empty():
		return null
	if from.is_unique_name_in_owner() and from.name == unique:
		return from
	for child in from.get_children():
		var found := find_unique(child, unique)
		if found != null:
			return found
	return null


static func read_prop(object: Object, dotted: String) -> Variant:
	if object == null:
		return null
	var current: Variant = object
	for key in dotted.split("."):
		if current == null:
			return null
		if current is Object:
			current = (current as Object).get(key)
		else:
			return null
	return current


static func screenshot(tree: SceneTree, path: String) -> String:
	if is_headless():
		return "headless (need a window for pixels)"
	if path.strip_edges().is_empty():
		return "missing --out="
	ensure_parent_dir(path)
	var img := tree.root.get_viewport().get_texture().get_image()
	if img == null:
		return "viewport image is null"
	var err := img.save_png(fs_path(path))
	if err != OK:
		return "save_png failed (%d)" % err
	return ""


static func click(scene: Node, spec: String) -> String:
	var node := resolve(scene, spec)
	if node == null:
		return "missing node %s" % spec
	if node is BaseButton:
		(node as BaseButton).pressed.emit()
		return ""
	return "%s is %s, not a BaseButton" % [spec, node.get_class()]


static func try_click(scene: Node, spec: String) -> String:
	var node := resolve(scene, spec)
	if node == null:
		print("AGENT_SKIP try_click missing ", spec)
		return ""
	if not (node is BaseButton):
		return "%s is %s, not a BaseButton" % [spec, node.get_class()]
	var btn := node as BaseButton
	if btn.disabled or not btn.is_visible_in_tree():
		print("AGENT_SKIP try_click ", spec)
		return ""
	btn.pressed.emit()
	print("AGENT_CLICK ", spec)
	return ""


static func type_in(scene: Node, spec: String, text: String) -> String:
	var node := resolve(scene, spec)
	if node == null:
		return "missing node %s" % spec
	if node is LineEdit:
		var edit := node as LineEdit
		edit.text = text
		edit.text_changed.emit(text)
		edit.text_submitted.emit(text)
		return ""
	if node is TextEdit:
		(node as TextEdit).text = text
		return ""
	return "%s is %s, not LineEdit/TextEdit" % [spec, node.get_class()]


static func dump_tree(node: Node, indent: int = 0) -> PackedStringArray:
	var lines := PackedStringArray()
	if node == null:
		return lines
	var mark := "%" if node.is_unique_name_in_owner() else ""
	lines.append("%s%s%s (%s)" % ["  ".repeat(indent), mark, node.name, node.get_class()])
	for child in node.get_children():
		lines.append_array(dump_tree(child, indent + 1))
	return lines


static func dump_unique(node: Node) -> PackedStringArray:
	var lines := PackedStringArray()
	_collect_unique(node, lines)
	return lines


static func _collect_unique(node: Node, lines: PackedStringArray) -> void:
	if node == null:
		return
	if node.is_unique_name_in_owner():
		lines.append("%%%s\t%s\t%s" % [node.name, node.get_class(), str(node.get_path())])
	for child in node.get_children():
		_collect_unique(child, lines)


static func stringify_variant(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Resource:
		var path := (value as Resource).resource_path
		if not path.is_empty():
			return path
	return str(value)
