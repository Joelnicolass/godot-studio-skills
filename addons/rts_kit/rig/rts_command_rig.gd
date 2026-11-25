@tool
class_name RtsCommandRig
extends Node

## The whole command rig as one node: instance rts_command_rig_3d.tscn (or rts_command_rig_2d.tscn)
## in the battle scene, assign `camera` and `ground`, and the player selects units and orders them.
## Inside are the kit's pieces, already wired to each other: Command (RtsCommandInput) with
## Selection, Orders, Pointer, State, Armed, OrderInput, SelectInput, GroupKeys, OrderButton and
## Probe, and ViewLayer/View/Box (the full-screen Control that takes the world's clicks, and the
## selection box). The 2D scene has its distances in pixels.
##
## This node holds what the rig needs from the battle (`camera`, `ground`, `menu`). Every other
## value stays on the piece that uses it: in the editor, right click the rig > Editable Children; in
## code, `rig.selection`, `rig.orders`, `rig.command`…
## The game's HUD goes on a CanvasLayer after the rig in the tree (or on a higher layer): what is
## over the view keeps its clicks.
## Not: the units (RtsUnit), the camera, the command UIs (RtsCommandCard, RtsRadialMenu).

## The battle's camera: an RtsCamera3D (RtsCamera2D in the 2D rig) or any camera of that dimension.
## An RtsCamera with no `edge_area` gets the rig's view: its screen edges pan over the world and
## stop over the HUD.
@export var camera: Node:
	set(value):
		camera = value
		_wire()
## 3D: the floor's body, or the parent of its bodies; nothing else on Pointer.ground_mask is ground
## (a building on that layer is not). 2D: optional, the ground is everywhere; a floor that has a
## collider (a TileMapLayer) goes here so clicks pass through it.
@export var ground: Node:
	set(value):
		ground = value
		_wire()
## Optional: the menu the order button opens while held (rts_radial_menu.tscn, or the game's own
## RtsOrderMenu). Empty: a plain right click.
@export var menu: RtsOrderMenu:
	set(value):
		menu = value
		_wire()
## Which rig this is. Each scene stores its own; for the other dimension use the other scene.
@export_storage var dimension := RtsPointer.Dimension.D3

## The pieces, for the game's code (`rig.selection.changed.connect(…)`, `rig.orders.send = …`,
## `rig.command.local_slot = 2`).
var command: RtsCommandInput:
	get:
		return %Command
var selection: RtsSelection:
	get:
		return %Selection
var orders: RtsOrders:
	get:
		return %Orders
var pointer: RtsPointer:
	get:
		return %Pointer
var state: RtsCommandState:
	get:
		return %State
var armed: RtsArmedCommand:
	get:
		return %Armed
var order_input: RtsOrderInput:
	get:
		return %OrderInput
var select_input: RtsSelectInput:
	get:
		return %SelectInput
var group_keys: RtsGroupKeys:
	get:
		return %GroupKeys
var order_button: RtsOrderButton:
	get:
		return %OrderButton
var probe: RtsTargetProbe:
	get:
		return %Probe
## The Control that takes the world's clicks.
var view: Control:
	get:
		return %View
## The selection box.
var box: Control:
	get:
		return %Box


func is_2d() -> bool:
	return dimension == RtsPointer.Dimension.D2


func _validate_property(property: Dictionary) -> void:
	if property.name == "camera":
		property.hint_string = "Camera2D" if is_2d() else "Camera3D"
	elif property.name == "ground":
		property.hint_string = "Node2D" if is_2d() else "Node3D"


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var kind := "2D" if is_2d() else "3D"
	if camera == null:
		warnings.append("Assign `camera`: the battle's Camera%s (an RtsCamera%s)." % [kind, kind])
	elif not _fits(camera):
		warnings.append(
			(
				"`camera` is not a Camera%s. This is the %s rig; the other one is %s."
				% [kind, kind, "rts_command_rig_3d.tscn" if is_2d() else "rts_command_rig_2d.tscn"]
			)
		)
	if ground == null and not is_2d():
		warnings.append(
			"Assign `ground`: the floor's body, or the parent of its bodies. Orders land on it."
		)
	return warnings


func _enter_tree() -> void:
	_wire()


## Hands the sockets to the pieces that use them. The pieces are there once the rig is in the tree.
func _wire() -> void:
	update_configuration_warnings()
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	pointer.dimension = dimension
	pointer.camera = camera
	pointer.ground = ground
	order_button.menu = menu
	if camera != null and "edge_area" in camera and camera.get("edge_area") == null:
		camera.set("edge_area", view)


func _fits(node: Node) -> bool:
	return node is Camera2D if is_2d() else node is Camera3D
