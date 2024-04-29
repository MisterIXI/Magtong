extends RigidBody2D
class_name PlayerBody

@export var player: int = 0
@export var settings: PlayerSettings
enum polarity {IDLE, POS, NEG}
signal polarity_changed(new_pol: polarity)
signal pulse_emitted(pulse_position: Vector2)
signal impulse_emitted(pulse_position: Vector2, pol: polarity)
signal setup_completed(player_body: PlayerBody)
@export var opponent: PlayerBody
@export var puck: Puck
var state = polarity.IDLE

var target_vel: Vector2 = Vector2()
@export var pulse_timer: Timer
@export var impulse_timer: Timer
var forced_pos: Vector2 = Vector2()
var force_move_flag: bool = false
@export var player_skin: Sprite2D
var x_input: float = 0.0
var y_input: float = 0.0
var plus_input: float = 0.0
var minus_input: float = 0.0
var current_polarity

@onready var im: InputManager = globInputManager
var mm: MatchManager
var player_input: PlayerInput

func setup(player_input: PlayerInput):
	self.player_input = player_input
	player_input.input_received.connect(on_input)
	globInputManager.input_unlocked.connect(_on_input_unlocked)
	mm = get_node("/root/MatchManager") as MatchManager
	player_skin.texture = globResourceManager.icons.player_sprites[player_input.player_sprite_id]
	set_skin.rpc(player_input.player_sprite_id)
	setup_completed.emit(self)

func on_input(input_info: InputInfo):
	assert(multiplayer.is_server())
	match input_info.input_type:
		InputInfo.InputType.MOVE_X:
			x_input = input_info.axis_value
			if not im.input_locked:
				update_target_vel(Vector2(x_input, y_input))
		InputInfo.InputType.MOVE_Y:
			y_input = input_info.axis_value
			if not im.input_locked:
				update_target_vel(Vector2(x_input, y_input))
		InputInfo.InputType.PLUS:
			plus_input = input_info.axis_value
			if not im.input_locked:
				update_polarity()
		InputInfo.InputType.MINUS:
			minus_input = input_info.axis_value
			if not im.input_locked:
				update_polarity()
		InputInfo.InputType.PRIMARY:
			if input_info.is_pressed and not im.input_locked:
				try_to_pulse()
		InputInfo.InputType.SECONDARY:
			if input_info.is_pressed and not im.input_locked:
				try_to_impulse()
		InputInfo.InputType.MENU:
			if input_info.is_pressed:
				mm.request_restart.rpc_id(1)
		_:
			pass

func _on_input_unlocked():
	update_target_vel(Vector2(x_input, y_input))
	update_polarity()

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
@rpc("any_peer", "call_local", "reliable")
func reset_input():
	x_input = 0.0
	y_input = 0.0
	plus_input = 0.0
	minus_input = 0.0
	update_target_vel(Vector2(x_input, y_input))
	update_polarity()
	
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

func try_to_impulse():
	if impulse_timer.is_stopped() and state != polarity.IDLE:
		impulse_timer.start()
		impulse.rpc()

@rpc("authority", "call_local", "reliable")
func impulse():
	impulse_emitted.emit(global_position, state)

@rpc("any_peer", "call_remote", "reliable")
func set_skin(player_sprite_id: int):
	player_skin.texture = globResourceManager.icons.player_sprites[player_sprite_id]