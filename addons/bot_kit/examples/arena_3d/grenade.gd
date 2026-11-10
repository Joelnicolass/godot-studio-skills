extends MeshInstance3D

## A grenade: it flies under gravity (the same as the bot's grenade weapon, so its lob lands where it aimed) and
## bursts on whatever it meets, hurting every fighter within RADIUS_M.

const GRAVITY := 9.8
const RADIUS_M := 3.0
const DAMAGE := 45.0
const FUSE_S := 4.0

var velocity := Vector3.ZERO
var thrower: Node
var _left_s := FUSE_S


func _ready() -> void:
	var ball := SphereMesh.new()
	ball.radius = 0.12
	ball.height = 0.24
	mesh = ball


func _physics_process(delta: float) -> void:
	_left_s -= delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 0b11)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() or _left_s <= 0.0:
		_burst(hit.get("position", to))
		return
	global_position = to


func _burst(at: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(&"bot_target"):
		var fighter := node as Node3D
		var distance := fighter.global_position.distance_to(at) if fighter != null else INF
		if distance < RADIUS_M and fighter.has_method(&"hurt"):
			fighter.call(&"hurt", DAMAGE * (1.0 - distance / RADIUS_M), thrower)
	get_parent().call(&"burst", at)
	queue_free()
