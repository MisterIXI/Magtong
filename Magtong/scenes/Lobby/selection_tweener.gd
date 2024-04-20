extends Node
class_name SelectionTweener

var tween: Tween = null
var prev_control: Control = null
func highlight_control(control: Control):
	if control == null:
		tween.kill()
		tween = null
		return
	if prev_control:
		prev_control.modulate = Color(1,1,1,1)
	if tween:
		tween.kill()
	
	control.modulate = Color(2,2,2,1)
	tween = create_tween()
	tween.set_loops()
	tween.tween_property(control, "modulate", Color(1.5,1.5,1.5,1), 0.5)
	tween.tween_property(control, "modulate", Color(2.5,2.5,2.5,1), 0.5)
	tween.play()
	prev_control = control
