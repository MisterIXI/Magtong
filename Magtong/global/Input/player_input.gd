extends Node
class_name PlayerInput

signal input_received(input_info: InputInfo)

var player_id: int
var peer_id: int
var device_id: int
var is_ready: bool = false
var team: int = -1 # team 0 is spectator, actual teams count up from 1
var player_sprite_id: int = 0
var is_host: bool = false
var selected_ability: int = -1

func _init(peer_id: int = -1, device_id: int = -1, player_id: int = -1, is_host: bool = false) -> void:
	self.peer_id = peer_id
	self.device_id = device_id
	self.player_id = player_id
	self.is_host = is_host


func execute_input(input_info: InputInfo) -> void:
	# Emit the signal
	input_received.emit(input_info)

func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"device_id": device_id,
		"player_id": player_id,
		"is_ready": is_ready,
		"team": team,
		"player_sprite_id": player_sprite_id
	}

func from_dict(data: Dictionary) -> PlayerInput:
	peer_id = data["peer_id"]
	device_id = data["device_id"]
	player_id = data["player_id"]
	is_ready = data["is_ready"]
	team = data["team"]
	player_sprite_id = data["player_sprite_id"]
	return self