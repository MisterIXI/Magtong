extends Node
class_name InputManager

const KEYBOARD_DEVICE_ID: int = -1

var player_inputs: Dictionary = {} # maps device IDs to PlayerInputs
var next_player_id: int = 1
signal player_input_registered(player_input: PlayerInput)

func _input(event: InputEvent) -> void:
	var device_id: int
	if event is InputEventKey:
		# function keys are debug keys, never player input
		if event.keycode >= KEY_F1 and event.keycode <= KEY_F12:
			return
		device_id = KEYBOARD_DEVICE_ID
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		device_id = event.device
	else:
		return
	if player_inputs.has(device_id):
		var player_input: PlayerInput = player_inputs[device_id]
		var input = player_input.mapping.check_input(event)
		if input:
			player_input.execute_input(input)
	# joypad motion is ignored for registration, so stick drift does not join players
	elif globGameManager.current_state == GameManager.State.LOBBY and event.is_pressed() and not event is InputEventJoypadMotion:
		register_player(device_id)

func register_player(device_id: int) -> PlayerInput:
	var player_input = PlayerInput.new(device_id, next_player_id)
	next_player_id += 1
	add_child(player_input, true)
	player_inputs[device_id] = player_input
	player_input_registered.emit(player_input)
	return player_input

func get_all_player_inputs() -> Array:
	return player_inputs.values()
