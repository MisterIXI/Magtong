extends NinePatchRect

@export var margin_cont : MarginContainer

var tween: Tween = null
# Called when the node enters the scene tree for the first time.
func _ready():
	set_deferred("visible", false)

func highlight_control(control: Control):
	if control == null:
		set_deferred("visible", false)
		tween.kill()
		tween = null
		return
	# set visible to true
	set_deferred("visible", true)
	# get bounds of the control
	var control_rect = control.get_rect()
	# position self (-5,-5) from the control and set size to control size + 10+
	position = control_rect.position + Vector2(5, 10)

	size = control_rect.size
	# start tween
	if tween:
		tween.kill()
	tween = create_tween()
	# infinite looping
	tween.set_loops()
	# tween to be slightly bigger and smaller
	tween.tween_property(self, "modulate", Color(0.5, 0.5, 0.5, 1), 1)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 1)
	tween.play()
