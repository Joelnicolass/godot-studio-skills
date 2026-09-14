class_name MpReplicate
extends Node

## Child of a replicated actor. Server authority, sync props, freeze rigid proxies.
## Same code for listen-server and dedicated.

@export var actor: NodePath
@export var sync_properties: PackedStringArray = PackedStringArray([
	".:position",
	".:rotation",
	".:visible",
])
@export var freeze_rigid_if_proxy: bool = true


func _ready() -> void:
	var target := _target()
	if target == null:
		push_warning("MpReplicate: no actor (parent or NodePath)")
		return
	MpAuthority.claim_server(target)
	if not sync_properties.is_empty():
		MpAuthority.ensure_sync(target, sync_properties)
	if freeze_rigid_if_proxy:
		MpAuthority.freeze_rigid_proxy(target)


func _target() -> Node:
	if actor.is_empty():
		return get_parent()
	return get_node_or_null(actor)
