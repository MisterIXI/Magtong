extends RigidBody2D
class_name PlayerBody

@export var player: int = 0
@export var settings: PlayerSettings
enum polarity {IDLE, POS, NEG}
signal polarity_changed(new_pol: polarity)
signal pulse_emitted(pulse_position: Vector2)

@export var opponent: PlayerBody
@export var puck: Puck
var state = polarity.IDLE

var target_vel: Vector2 = Vector2()
@export var pulse_timer: Timer
@export var game_field: Game
var forced_pos: Vector2 = Vector2()
var force_move_flag: bool = false

var x_input: float = 0.0
var y_input: float = 0.0
var plus_input: float = 0.0
var minus_input: float = 0.0
var current_polarity

@onready var im: InputManager = globInputManager
var player_input: PlayerInput

func setup(player_input: PlayerInput):
	self.player_input = player_input
	player_input.input_received.connect(on_input)

func on_input(input_info: InputInfo):
	assert(multiplayer.is_server())
	match input_info.input_type:
		InputInfo.InputType.MOVE_X:
			x_input = input_info.axis_value
			update_target_vel(Vector2(x_input, y_input))
		InputInfo.InputType.MOVE_Y:
			y_input = input_info.axis_value
			update_target_vel(Vector2(x_input, y_input))
		InputInfo.InputType.PLUS:
			plus_input = input_info.axis_value
			update_polarity()
		InputInfo.InputType.MINUS:
			minus_input = input_info.axis_value
			update_polarity()
		InputInfo.InputType.PRIMARY:
			if input_info.is_pressed:
				try_to_pulse()
		_:
			pass

func update_target_vel(new_vel: Vector2):
	if new_vel.length() > 1:
		new_vel = new_vel.normalized()
	target_vel = new_vel * settings.speed

func update_polarity():
	if plus_input == 0.0 and minus_input == 0.0:
		if state != polarity.IDLE:
			change_polarity.rpc(polarity.IDLE)
	elif plus_input > 0.0: # use plus with priority
		if state != polarity.POS:
			change_polarity.rpc(polarity.POS)
	else:
		if state != polarity.NEG:
			change_polarity.rpc(polarity.NEG)

## If the polarity is different from the current state, update the state and emit signal
@rpc("any_peer", "call_local", "reliable")
func change_polarity(new_pol: polarity):
	if new_pol != state:
		state = new_pol
		polarity_changed.emit(state)

func reset(new_pos: Vector2):
	linear_velocity = Vector2()
	angular_velocity = 0
	change_polarity(polarity.IDLE)
	target_vel = Vector2()
	global_position = new_pos
	forced_pos = new_pos
	force_move_flag = true
	PhysicsServer2D.body_set_state(
		get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D.IDENTITY.translated(new_pos)
	)


func try_to_pulse():
	if pulse_timer.is_stopped():
		pulse_timer.start()
		pulse.rpc()

@rpc("authority", "call_local", "reliable")
func pulse():
	pulse_emitted.emit(global_position)

