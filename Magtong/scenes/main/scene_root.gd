extends Node
class_name SceneRoot

@export var start_scene: CanvasItem
@onready var current_scene: Node = start_scene

func change_scene(new_scene: Node = null) -> void:
	if new_scene == null and current_scene != start_scene:
		if current_scene != null:
			assert(multiplayer.is_server())
			current_scene.queue_free()
		new_scene = start_scene
		start_scene.visible = true
		return
	if current_scene == start_scene:
		start_scene.visible = false
	elif current_scene != null:
		assert(multiplayer.is_server())
		current_scene.queue_free()
	current_scene = new_scene
	add_child(current_scene)

func hide_menu():
	start_scene.visible = false