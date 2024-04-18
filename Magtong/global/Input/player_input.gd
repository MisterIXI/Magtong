extends Node
class_name PlayerInput

signal input_received(input_info: InputInfo)

var peer_id: int
var device_id: int
var is_ready: bool = false
var team: int = 0 # team 0 is spectator, actual teams count up from 1
var player_sprite_id: int = 0


func _init(peer_id: int, device_id: int) -> void:
	self.peer_id = peer_id
	self.device_id = device_id

func execute_input(input_info: InputInfo) -> void:
	# Emit the signal
	input_received.emit(input_info)
