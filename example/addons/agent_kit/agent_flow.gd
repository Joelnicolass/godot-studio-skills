class_name AgentFlow
extends RefCounted

const Ops := preload("res://addons/agent_kit/agent_ops.gd")


func run(tree: SceneTree, spec: Dictionary, out_dir: String) -> String:
	var scene_path := str(spec.get("scene", "")).strip_edges()
	if not scene_path.is_empty():
		var err := tree.change_scene_to_file(scene_path)
		if err != OK:
			return "change_scene %s failed (%d)" % [scene_path, err]
		await tree.process_frame
		await tree.process_frame
	var wait_first := float(spec.get("wait_first", 0.8))
	if wait_first > 0.0:
		await tree.create_timer(wait_first).timeout
	var dest := out_dir.strip_edges()
	if dest.is_empty():
		dest = "user://agent_kit"
	Ops.ensure_parent_dir(dest.path_join("dummy.png"))
	var steps: Variant = spec.get("steps", [])
	if typeof(steps) != TYPE_ARRAY:
		return "flow.steps must be an array"
	var index := 0
	for raw in steps:
		index += 1
		if typeof(raw) != TYPE_DICTIONARY:
			return "step %d is not an object" % index
		var fail := await _step(tree, raw, dest, index)
		if not fail.is_empty():
			return fail
	return ""


func _step(tree: SceneTree, step: Dictionary, dest: String, index: int) -> String:
	var scene := Ops.current_scene(tree)
	if step.has("wait"):
		await tree.create_timer(float(step["wait"])).timeout
		return ""
	if step.has("shot") or step.has("screenshot"):
		var name := str(step.get("shot", step.get("screenshot", "")))
		if name.is_empty():
			name = "%02d.png" % index
		if not name.ends_with(".png"):
			name += ".png"
		var path := dest.path_join(name)
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var shot_err := Ops.screenshot(tree, path)
		if not shot_err.is_empty():
			return "shot %s: %s" % [name, shot_err]
		print("AGENT_SHOT=", Ops.fs_path(path))
		return ""
	if step.has("click"):
		return Ops.click(scene, str(step["click"]))
	if step.has("press"):
		var spec: Variant = step["press"]
		if typeof(spec) == TYPE_STRING:
			return Ops.press_action(str(spec))
		if typeof(spec) != TYPE_DICTIONARY:
			return "press step must be a StringName or {name, pressed}"
		return Ops.press_action(str(spec.get("name", "")), bool(spec.get("pressed", true)))
	if step.has("try_click"):
		return Ops.try_click(scene, str(step["try_click"]))
	if step.has("repeat"):
		return await _repeat(tree, step["repeat"], dest, index)
	if step.has("type"):
		var spec: Variant = step["type"]
		if typeof(spec) != TYPE_DICTIONARY:
			return "type step must be {node, text}"
		return Ops.type_in(scene, str(spec.get("node", "")), str(spec.get("text", "")))
	if step.has("print"):
		var spec: Variant = step["print"]
		if typeof(spec) != TYPE_DICTIONARY:
			return "print step must be {node, prop}"
		var node := Ops.resolve(scene, str(spec.get("node", "")))
		if node == null:
			return "print missing %s" % str(spec.get("node", ""))
		var value := Ops.read_prop(node, str(spec.get("prop", "name")))
		print(
			"AGENT_PRINT node=%s prop=%s value=%s"
			% [spec.get("node", ""), spec.get("prop", ""), Ops.stringify_variant(value)]
		)
		return ""
	if step.has("assert"):
		return _assert(scene, step["assert"], index)
	if step.has("wait_until"):
		return await _wait_until(tree, scene, step["wait_until"])
	return "unknown step keys in %d: %s" % [index, str(step.keys())]


func _repeat(tree: SceneTree, spec: Variant, dest: String, index: int) -> String:
	if typeof(spec) != TYPE_DICTIONARY:
		return "repeat %d must be an object" % index
	var times := maxi(1, int(spec.get("times", 1)))
	var until: Variant = spec.get("until", {})
	var inner: Variant = spec.get("steps", [])
	if typeof(inner) != TYPE_ARRAY:
		return "repeat.steps must be an array"
	var last := ""
	var scene: Node = null
	for i in times:
		scene = Ops.current_scene(tree)
		if typeof(until) == TYPE_DICTIONARY and not (until as Dictionary).is_empty():
			last = _assert(scene, until, index)
			if last.is_empty():
				print("AGENT_REPEAT done iter=%d" % i)
				return ""
		for raw in inner:
			if typeof(raw) != TYPE_DICTIONARY:
				return "repeat step is not an object"
			var fail := await _step(tree, raw, dest, index)
			if not fail.is_empty():
				return fail
	scene = Ops.current_scene(tree)
	if typeof(until) == TYPE_DICTIONARY and not (until as Dictionary).is_empty():
		last = _assert(scene, until, index)
		if last.is_empty():
			print("AGENT_REPEAT done iter=%d" % times)
			return ""
		return "repeat exhausted: %s" % last
	return ""


func _assert(scene: Node, spec: Variant, index: int) -> String:
	if typeof(spec) != TYPE_DICTIONARY:
		return "assert %d must be an object" % index
	var node := Ops.resolve(scene, str(spec.get("node", "")))
	if node == null:
		return "assert missing %s" % str(spec.get("node", ""))
	if spec.has("disabled"):
		if not (node is BaseButton):
			return "assert disabled: %s is not a button" % node.name
		var want := bool(spec["disabled"])
		if (node as BaseButton).disabled != want:
			return "assert disabled want=%s got=%s" % [want, (node as BaseButton).disabled]
	if spec.has("visible"):
		if node is CanvasItem:
			var want_vis := bool(spec["visible"])
			if (node as CanvasItem).visible != want_vis:
				return "assert visible want=%s got=%s" % [want_vis, (node as CanvasItem).visible]
	if spec.has("visible_in_tree"):
		if not (node is Node):
			return "assert visible_in_tree: missing node"
		var want_tree := bool(spec["visible_in_tree"])
		var in_tree := false
		if node is CanvasItem:
			in_tree = (node as CanvasItem).is_visible_in_tree()
		else:
			in_tree = node.is_inside_tree()
		if in_tree != want_tree:
			return "assert visible_in_tree want=%s got=%s" % [want_tree, in_tree]
	if spec.has("text_contains"):
		var text := _node_text(node)
		var needle := str(spec["text_contains"])
		if not text.contains(needle):
			return "assert text_contains %s not in %s" % [needle, text]
	if spec.has("text_equals"):
		var text := _node_text(node)
		var want := str(spec["text_equals"])
		if text != want:
			return "assert text_equals want=%s got=%s" % [want, text]
	if spec.has("texture_path_contains"):
		var tex_path := ""
		if node is TextureRect and (node as TextureRect).texture != null:
			tex_path = (node as TextureRect).texture.resource_path
		var needle := str(spec["texture_path_contains"])
		if not tex_path.contains(needle):
			return "assert texture_path_contains %s not in %s" % [needle, tex_path]
	print("AGENT_ASSERT ok step=%d node=%s" % [index, spec.get("node", "")])
	return ""


func _wait_until(tree: SceneTree, scene: Node, spec: Variant) -> String:
	if typeof(spec) != TYPE_DICTIONARY:
		return "wait_until must be an object"
	var timeout := float(spec.get("timeout", 5.0))
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	var probe: Dictionary = spec.duplicate()
	if probe.has("contains") and not probe.has("text_contains"):
		probe["text_contains"] = probe["contains"]
	probe.erase("timeout")
	var last := ""
	while Time.get_ticks_msec() < deadline:
		last = _assert(scene, probe, 0)
		if last.is_empty():
			return ""
		await tree.process_frame
		scene = Ops.current_scene(tree)
	return "wait_until timeout: %s" % last


func _node_text(node: Node) -> String:
	if node is Label:
		return (node as Label).text
	if node is RichTextLabel:
		return (node as RichTextLabel).get_parsed_text()
	if node is LineEdit:
		return (node as LineEdit).text
	if node is Button:
		return (node as Button).text
	return str(node.get("text"))
