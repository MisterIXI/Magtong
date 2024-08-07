extends Node
const start_zoom: float = 0.755
const default_size: Vector2i = Vector2i(1280,720)

func _ready():
	get_viewport().size_changed.connect(on_viewport_size_changed)
	on_viewport_size_changed()
	pass

func on_viewport_size_changed():
	var new_size : Vector2i= get_viewport().get_window().size
	var factor : float = 1.0
	# check if it's flatter or thinner than 16 by 9
	if float(new_size.x) / new_size.y < 16.0 / 9.0:
		factor = (float(new_size.x) / default_size.x)
	else:
		factor = (float(new_size.y) / default_size.y)
	get_parent().zoom = Vector2.ONE * start_zoom * factor

