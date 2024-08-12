extends Node2D
class_name  MagneticField2D

@export var dipole_moment: Vector2 = Vector2.RIGHT
@export var magnet_pos: Node2D

@export var menu_needle: PackedScene

const GRID_COUNT = 30

# func _ready():
# 	for i in range(GRID_COUNT):
# 		for j in range(GRID_COUNT):
# 			var needle = menu_needle.instantiate()
# 			needle.position = Vector2(i, j) * 50 + Vector2.RIGHT * 32
# 			add_child(needle)


func calculate_field_at_point(point: Vector2) -> Vector2:
	# Simplified calculation for a 2D magnetic dipole
	var r = point - magnet_pos.position
	var r_mag = r.length()
	var r_hat = r.normalized()
	var field = (2 * dipole_moment.dot(r_hat) * r_hat - dipole_moment) / r_mag**3
	return field
