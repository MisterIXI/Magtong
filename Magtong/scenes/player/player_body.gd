class_name PlayerBody
extends RigidBody2D

@export var sprite: PlayerSprite
@export var player_input: PlayerInput

signal magnet_state_changed(newState: MagnetState)

var magnet_state: MagnetState

enum MagnetState{
	Positive,
	Neutral,
	Negative
}



func change_magnet_state(new_state: MagnetState):
	magnet_state = new_state
	magnet_state_changed.emit(magnet_state)

func cycle_sprite(index_dir: int):
	if index_dir == 0:
		push_warning("should never be 0")
		return
	sprite.cycle_sprite()

func set_device_id(id: int):
	player_input.device_id = id