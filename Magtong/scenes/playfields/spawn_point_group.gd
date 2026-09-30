extends Node2D

class_name SpawnPointGroup

@export var spawn_points: Array[Node2D]
var shuffle_indices: Array[int]

func _ready():
	shuffle_indices = []
	for i in range(spawn_points.size()):
		shuffle_indices.append(i)

func shuffle():
	shuffle_indices.shuffle()

func get_shuffled_point(index: int) -> Node2D:
	return spawn_points[shuffle_indices[index]]

func size() -> int:
	return spawn_points.size()