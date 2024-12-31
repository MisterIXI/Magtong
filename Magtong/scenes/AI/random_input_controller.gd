extends Node2D
class_name RandomInputController

@onready var player: PlayerBody = get_parent()

func _physics_process(_delta):
	var input_info = InputInfo.new()
	# moveX
	input_info.input_type = InputInfo.InputType.MOVE_X
	input_info.axis_value = randf_range(-1, 1)
	player.on_input(input_info)
	# moveY
	input_info.input_type = InputInfo.InputType.MOVE_Y
	input_info.axis_value = randf_range(-1, 1)
	player.on_input(input_info)
	# magnetismX
	input_info.input_type = InputInfo.InputType.PLUS
	input_info.axis_value = randf_range(-1, 1)
	player.on_input(input_info)
	# magnetismY
	input_info.input_type = InputInfo.InputType.MINUS
	input_info.axis_value = randf_range(-1, 1)
	player.on_input(input_info)
	# switch
	input_info.input_type = InputInfo.InputType.PRIMARY
	input_info.is_pressed = randi() % 2 == 1
	player.on_input(input_info)
	# ability
	input_info.input_type = InputInfo.InputType.SECONDARY
	input_info.is_pressed = randi() % 2 == 1
	player.on_input(input_info)
	