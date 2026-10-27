extends Node
class_name PlayerInput

signal input_received(input_info: InputInfo)

var player_id: int
var device_id: int
var mapping: PlayerMapping

# held state built up from input events, sampled once per simulation tick
var move: Vector2 = Vector2.ZERO
var held_buttons: int = 0
# buttons pressed since the last sample, so a press and release within one tick is not lost
var latched_buttons: int = 0

func _init(device_id: int = InputManager.KEYBOARD_DEVICE_ID, player_id: int = -1) -> void:
	self.device_id = device_id
	self.player_id = player_id
	self.mapping = PlayerMapping.new(is_keyboard())

func is_keyboard() -> bool:
	return device_id == InputManager.KEYBOARD_DEVICE_ID

func execute_input(input_info: InputInfo) -> void:
	match input_info.input_type:
		InputInfo.InputType.MOVE_X:
			move.x = input_info.axis_value
		InputInfo.InputType.MOVE_Y:
			move.y = input_info.axis_value
		InputInfo.InputType.PLUS:
			_set_button(SimInput.PLUS, input_info.axis_value > 0.0)
		InputInfo.InputType.MINUS:
			_set_button(SimInput.MINUS, input_info.axis_value > 0.0)
		InputInfo.InputType.PRIMARY:
			_set_button(SimInput.PRIMARY, input_info.is_pressed)
		InputInfo.InputType.SECONDARY:
			_set_button(SimInput.SECONDARY, input_info.is_pressed)
		InputInfo.InputType.MENU:
			_set_button(SimInput.MENU, input_info.is_pressed)
		InputInfo.InputType.AUX_LEFT:
			_set_button(SimInput.AUX_LEFT, input_info.is_pressed)
		InputInfo.InputType.AUX_RIGHT:
			_set_button(SimInput.AUX_RIGHT, input_info.is_pressed)
		InputInfo.InputType.BACK:
			_set_button(SimInput.BACK, input_info.is_pressed)
	# Emit the signal
	input_received.emit(input_info)

func _set_button(button: int, pressed: bool) -> void:
	if pressed:
		held_buttons |= button
		latched_buttons |= button
	else:
		held_buttons &= ~button

## Returns the packed SimInput for the current tick.
func sample() -> int:
	var input := SimInput.encode(move, held_buttons | latched_buttons)
	latched_buttons = 0
	return input
