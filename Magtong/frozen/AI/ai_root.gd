@tool
extends Node2D
class_name AIManager

@export var ai_map_scene: PackedScene
@export var env_root: Node2D
@export var env_size: Vector2 = Vector2(1000, 1000)
@export var scene_count: Vector2i = Vector2i(1, 1)
@export var spawn_scenes: bool = false:
	set(_value):
		respawn_scenes()


func _ready():
	# check if in editor
	if Engine.is_editor_hint():
		return
	globGameManager.host_game(true, true)
	await get_tree().physics_frame
	# globGameManager._change_state(GameManager.State.GAME)
	#pass
	respawn_scenes()

func respawn_scenes():
	print("Respawning scenes...")
	if env_root == null:
		push_warning("No environment root set, cannot spawn scenes")
		return
	var scenes = env_root.get_children()
	for scene in scenes:
		scene.queue_free()
	var half_x = (env_size.x * scene_count.x) / 2 - env_size.x / 2
	var half_y = (env_size.y * scene_count.y) / 2 - env_size.y / 2

	for x in range(scene_count.x):
		for y in range(scene_count.y):
			var scene = ai_map_scene.instantiate()
			scene.global_position = Vector2(x * env_size.x, y * env_size.y)
			
			scene.global_position -= Vector2(half_x, half_y)
			env_root.add_child(scene)