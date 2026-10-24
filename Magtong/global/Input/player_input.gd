extends Node
class_name PlayerInput

signal input_received(input_info: InputInfo)

var player_id: int
var device_id: int
var mapping: PlayerMapping
var is_ready: bool = false
var team: int = -1 # team 0 is spectator, actual teams count up from 1
var player_sprite_id: int = 0
var selected_ability: int = -1

func _init(device_id: int = InputManager.KEYBOARD_DEVICE_ID, player_id: int = -1) -> void:
	self.device_id = device_id
	self.player_id = player_id
	self.mapping = PlayerMapping.new(is_keyboard())
	self.player_sprite_id = randi_range(0, globResourceManager.icons.player_sprites.size() - 1)

func is_keyboard() -> bool:
	return device_id == InputManager.KEYBOARD_DEVICE_ID

func execute_input(input_info: InputInfo) -> void:
	# Emit the signal
	input_received.emit(input_info)
