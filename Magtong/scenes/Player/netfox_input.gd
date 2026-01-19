class_name NetfoxInput
extends BaseNetInput
var movement: Vector2 = Vector2.ZERO
var movement_buffer: Vector2 = Vector2.ZERO
var x_input: float
var y_input: float
@onready var player: PlayerBody = get_parent()

var input

func _ready():
	super._ready()
	player.player_input.input_received.connect(_on_input_received)

func _on_input_received(input_info: InputInfo):
	match input_info.input_type:
		InputInfo.InputType.MOVE_X:
			x_input = input_info.axis_value
		InputInfo.InputType.MOVE_Y:
			y_input = input_info.axis_value
	update_movement_buffer()

func update_movement_buffer():
	movement_buffer = Vector2(x_input, y_input)
	# print(multiplayer.get_unique_id(), ": new movement_buffer: ", movement_buffer)

func _gather():
	if not is_multiplayer_authority():
		return
	movement = movement_buffer
	# print(multiplayer.get_unique_id(), ": old:", old_movement, " -> ", movement)

	# movement_buffer = Vector2.ZERO
	pass