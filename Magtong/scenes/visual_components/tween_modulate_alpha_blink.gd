@tool
extends Node
class_name VC_BlinkAlpha
@export var enabled: bool = true

@export_range(0, 1, 0.01) var upper_bound: float = 0.1 :
	set(value):
		upper_bound = value
		update_configuration_warnings()
		recreate_tween()

@export_range(0, 1, 0.01) var lower_bound: float = 0.1 :
	set(value):
		lower_bound = value
		update_configuration_warnings()
		recreate_tween()

@export var cycle_duration: float = 1.0:
	set(value):
		cycle_duration = value
		recreate_tween()

var tween: Tween

func _ready():
	recreate_tween()

func recreate_tween():
	if not is_inside_tree():
		return
	if tween != null:
		tween.kill()
		tween = null
	var target = get_parent()
	target.modulate.a = lower_bound
	tween = target.create_tween()
	tween.tween_property(target, "modulate:a",lower_bound,cycle_duration/2)
	tween.tween_property(target, "modulate:a",upper_bound,cycle_duration/2)
	tween.set_loops(-1)

func _get_configuration_warnings():
	if upper_bound < lower_bound:
		return ["Upper bound must be greater than lower bound."]

func _exit_tree():
	if tween != null:
		tween.kill()
	request_ready()
		