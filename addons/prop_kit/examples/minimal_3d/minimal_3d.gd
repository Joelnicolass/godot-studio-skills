extends Node3D

## PropKit's minimal example: a PropScatter3D plants trees on a flat square (PropFlatGround), away
## from the camp (a node in the group `camp`, kept clear by a PropKeepOut), and a PropBatch3D draws
## them in a few draw calls. In a game you press «Scatter» in the editor and save: the trees are
## then saved children, the batch builds on ready, and this script is not needed. Space: another seed.

@onready var scatter: PropScatter3D = $Forest
@onready var batch: PropBatch3D = $Batch


func _ready() -> void:
	if scatter.get_child_count() == 0:
		scatter.scatter()
	batch.rebuild_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		scatter.rules.random_seed += 1
		scatter.scatter()
		batch.rebuild_all()
