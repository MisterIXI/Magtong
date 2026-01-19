class_name NetfoxInput
extends BaseNetInput
var movement: Vector2 = Vector2.ZERO
var movement_buffer: Vector2 = Vector2.ZERO
var x_input: float
var y_input: float
@onready var player: PlayerBody = get_parent()
@export var _rollback_synchronizer: RollbackSynchronizer
@export_range(0.01, 0.5) var decay: float = 0.15
var confidence: float = 1.
var input

func _ready():
	super._ready()
	player.player_input.input_received.connect(_on_input_received)
	NetworkRollback.after_prepare_tick.connect(_predict)

func _on_input_received(input_info: InputInfo):
	match input_info.input_type:
		InputInfo.InputType.MOVE_X:
			x_input = input_info.axis_value
		InputInfo.InputType.MOVE_Y:
			y_input = input_info.axis_value
	update_movement_buffer()

func update_movement_buffer():
	movement_buffer = Vector2(x_input, y_input) * player.settings.speed 
	# print(multiplayer.get_unique_id(), ": new movement_buffer: ", movement_buffer)

func _gather():
	if not is_multiplayer_authority():
		return
	movement = movement_buffer
	# print(multiplayer.get_unique_id(), ": old:", old_movement, " -> ", movement)

	# movement_buffer = Vector2.ZERO
	pass

func _predict(_t):
	# return
	if not _rollback_synchronizer.is_predicting():
		confidence = 1
		return
	
	if not _rollback_synchronizer.has_input():
		confidence = 0
		return
	

	# Decay input over a short time
	var decay_time := NetworkTime.seconds_to_ticks(decay)
	var input_age := _rollback_synchronizer.get_input_age()

	# **ALWAYS** cast either side to float, otherwise the integer-integer 
	# division yields either 1 or 0 confidence
	confidence = input_age / float(decay_time)
	confidence = clampf(1. - confidence, 0., 1.)

	# Modulate input based on confidence
	movement *= confidence