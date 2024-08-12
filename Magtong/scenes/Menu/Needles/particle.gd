extends Node2D

@onready var magnet_field: MagneticField2D = get_parent()

func _physics_process(delta):
	var magnet_force = magnet_field.calculate_field_at_point(position)
	position += magnet_force.normalized() * delta * 1000