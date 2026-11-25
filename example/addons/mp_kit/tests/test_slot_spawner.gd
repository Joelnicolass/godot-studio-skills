extends "res://addons/mp_kit/tests/mp_test.gd"

## MpSlotSpawner with a pawn your game frees (MpActor.despawn: it died), solo, no network: the slot forgets it, spawn_slot makes
## a new one named Pawn_<slot> (also in the frame the old one leaves), and a player who leaves after its pawn was freed is no
## error.


func _world() -> MpSlotSpawner:
	var world := Node2D.new()
	world.name = "SpawnerWorld"
	var actors := Node2D.new()
	actors.name = "Actors"
	world.add_child(actors)
	var spawner := MpSlotSpawner.new()
	spawner.name = "Players"
	spawner.spawn_path = ^"../Actors"
	var scene := PackedScene.new()
	scene.pack(Node2D.new())
	spawner.pawn_scene = scene
	world.add_child(spawner)
	tree.root.add_child(world)
	return spawner


func _actors(spawner: MpSlotSpawner) -> Node:
	return spawner.get_parent().get_node("Actors")


func test_a_freed_pawn_is_forgotten() -> void:
	var spawner := _world()
	check(spawner.pawn_for(1) != null and spawner.pawn_for(1).name == "Pawn_1", "solo: the local slot's pawn")
	var pawn := spawner.spawn_slot(2)
	check(pawn != null and pawn.name == "Pawn_2" and pawn.get_parent() == _actors(spawner), "slot 2's pawn under Actors")
	check(spawner.spawn_slot(2) == pawn, "asked again: the same pawn")
	pawn.free()
	check(spawner.pawn_for(2) == null, "freed: pawn_for gives null, no error")
	var again := spawner.spawn_slot(2)
	check(again != null and again.is_inside_tree() and again.name == "Pawn_2", "spawn_slot makes a new one, Pawn_2")
	spawner.get_parent().free()


func test_a_pawn_freed_this_frame_is_replaced_under_its_name() -> void:
	var spawner := _world()
	var old := spawner.spawn_slot(2)
	old.queue_free()
	check(spawner.pawn_for(2) == null, "being freed (despawn): pawn_for gives null")
	var again := spawner.spawn_slot(2)
	check(again != null and again != old and not again.is_inside_tree(), "a new pawn, waiting for the old one to leave")
	check(spawner.spawn_slot(2) == again and spawner.pawn_for(2) == again, "asked again meanwhile: that same new pawn")
	await tree.process_frame
	await tree.process_frame
	check(again.is_inside_tree() and again.name == "Pawn_2" and _actors(spawner).get_child_count() == 2,
		"next frame it is in, named Pawn_2 (not Pawn_3), and only one pawn per slot (%s)" % [_actors(spawner).get_children()])
	spawner.get_parent().free()


func test_a_player_who_leaves_after_its_pawn_was_freed() -> void:
	var spawner := _world()
	spawner.spawn_slot(2).free()
	spawner._on_slot_peer_left(20, 2)
	check(spawner.pawn_for(2) == null, "its player left: nothing to free, no error")
	var pawn := spawner.spawn_slot(3)
	spawner._on_slot_peer_left(30, 3)
	check(pawn.is_queued_for_deletion() and spawner.pawn_for(3) == null, "a live pawn of a player who leaves is freed as before")
	spawner.get_parent().free()


func test_a_waiting_pawn_never_enters_a_world_that_is_gone() -> void:
	var spawner := _world()
	spawner.spawn_slot(2).queue_free()
	var waiting := spawner.spawn_slot(2)
	var id := waiting.get_instance_id()
	spawner.get_parent().free()
	await tree.process_frame
	check(instance_from_id(id) == null, "the world left before the old pawn did: the waiting one is freed, not leaked")
