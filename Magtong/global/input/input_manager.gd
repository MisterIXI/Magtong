extends Node

const KEYBOARD_DEVICE_ID: int = -1

var player_inputs: Dictionary = {} # maps device IDs to PlayerInputs
var next_player_id: int = 1
signal player_input_registered(player_input: PlayerInput)

## Joypads whose name contains one of these are parts of keyboards or mice (media keys, volume knobs), not
## gamepads. They must never join as a player.
const NOT_GAMEPAD_NAMES: Array[String] = ["keyboard", "mouse", "system control", "consumer control"]

func _ready() -> void:
	# keep tracking held buttons and sticks while the pause menu pauses the tree, or releases would get lost
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_menu_buttons()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

## Godot's ui_accept/ui_cancel only have keys. Every pad can confirm (A) and go back (B) in menus.
func _add_menu_buttons() -> void:
	for pair in [[&"ui_accept", JOY_BUTTON_A], [&"ui_cancel", JOY_BUTTON_B]]:
		var event := InputEventJoypadButton.new()
		event.device = -1 # all devices
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)

static func is_gamepad(device_id: int) -> bool:
	var joy_name := Input.get_joy_name(device_id).to_lower()
	for part in NOT_GAMEPAD_NAMES:
		if part in joy_name:
			return false
	return true

## A pad that disconnects keeps its player, but lets go of everything, so the player doesn't drift or keep a
## magnet on. When it comes back (Godot usually gives it the same device id) the player continues.
func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if not connected and player_inputs.has(device_id):
		player_inputs[device_id].release_all()

func _input(event: InputEvent) -> void:
	var device_id: int
	if event is InputEventKey:
		# function keys are debug keys, never player input
		if event.keycode >= KEY_F1 and event.keycode <= KEY_F12:
			return
		device_id = KEYBOARD_DEVICE_ID
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not is_gamepad(event.device):
			return
		device_id = event.device
	else:
		return
	if player_inputs.has(device_id):
		var player_input: PlayerInput = player_inputs[device_id]
		var input = player_input.mapping.check_input(event)
		if input:
			player_input.execute_input(input)
	# joypad motion is ignored for registration, so stick drift does not join players
	elif GameManager.current_state == GameManager.State.LOBBY and event.is_pressed() and not event is InputEventJoypadMotion:
		register_player(device_id)

func register_player(device_id: int) -> PlayerInput:
	var player_input = PlayerInput.new(device_id, next_player_id)
	next_player_id += 1
	add_child(player_input, true)
	player_inputs[device_id] = player_input
	player_input_registered.emit(player_input)
	return player_input

## Forget all local players (back to the main menu).
func clear_players() -> void:
	for player_input in player_inputs.values():
		player_input.queue_free()
	player_inputs.clear()
	next_player_id = 1

func get_all_player_inputs() -> Array:
	return player_inputs.values()
