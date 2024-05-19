@tool
extends Node
class_name  MPMapAdder

func _ready():
	if not Engine.is_editor_hint():
		var parent_spawner : MultiplayerSpawner = get_parent()
		for map in globResourceManager.standard_maps.maps:
			parent_spawner.add_spawnable_scene(map.resource_path)

func _enter_tree():
	print("Enter tree")
	if Engine.is_editor_hint():
		_get_configuration_warnings()

func _get_configuration_warnings():
	var warnings = []
	if Engine.is_editor_hint():
		if get_parent() is not MultiplayerSpawner:
			warnings.append("This node should be a child of a MultiplayerSpawner node.")
	return warnings