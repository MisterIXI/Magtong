extends RigidBody2D
class_name PlayerBody

@export var player: int = 0
@export var settings: PlayerSettings
enum polarity {IDLE, POS, NEG}
signal polarity_changed(new_pol: polarity)
signal pulse_emitted(pulse_position: Vector2)
# signal impulse_emitted(pulse_position: Vector2, pol: polarity)
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
var sync_pos: Vector2
var sync_rot: float

@onready var im: InputManager = globInputManager
var mm: MatchManager
var gl: GameLobby
var player_input: PlayerInput
var is_in_lobby: bool = false
var map: MapScript
var current_ability: AbilityBase
var ability_id: int = -1
@export var abilities: Array[AbilityBase]

func setup_player( map: MapScript, player_input: PlayerInput, is_in_lobby: bool = false):
	self.map = map
	self.player_input = player_input
	player_input.input_received.connect(on_input)
	globInputManager.input_unlocked.connect(_on_input_unlocked)
	self.is_in_lobby = is_in_lobby
	if is_in_lobby:
		gl = globGameManager.scene_root.current_scene as GameLobby
	else:
		mm = globGameManager.scene_root.current_scene as MatchManager
	player_skin.texture = globResourceManager.icons.player_sprites[player_input.player_sprite_id]
	set_skin.rpc(player_input.player_sprite_id)
	# set up ability
	if player_input.selected_ability != -1:
		ability_id = player_input.selected_ability
	else:
		ability_id = 0
	current_ability = abilities[ability_id]
	if not is_multiplayer_authority():
		freeze = true
	for x in abilities:
		x.setup(map)
	setup_completed.emit(self)

# fixing MP flickering
# https://www.reddit.com/r/godot/comments/180ywzs/multiplayersynchronizer_and_rigidbody/
func _integrate_forces(_state):
	if is_multiplayer_authority():
		sync_pos = global_position
		sync_rot = rotation
		# print("Nope")
	else:
		# print("Sync_pos: ", sync_pos, "Sync_rot: ", sync_rot)
		global_position = sync_pos
		rotation = sync_rot

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
			if not im.input_locked:
				if input_info.is_pressed:
					current_ability._ability_button_down()
				else:
					current_ability._ability_button_up()
		InputInfo.InputType.MENU:
			if input_info.is_pressed:
				if is_in_lobby:
					if player_input.peer_id == 1:
						gl.request_game_start()
				else:
					mm.request_restart()
		InputInfo.InputType.D_LEFT:
			if input_info.is_pressed:
				if is_in_lobby:
					cycle_skin(-1)
		InputInfo.InputType.D_RIGHT:
			if input_info.is_pressed:
				if is_in_lobby:
					cycle_skin(1)
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
func reset_input_state(retain_input: bool = true):
	var old_plus = plus_input
	var old_minus = minus_input
	plus_input = 0.0
	minus_input = 0.0
	update_target_vel(Vector2(0.0, 0.0))
	update_polarity()
	if retain_input:
		plus_input = old_plus
		minus_input = old_minus
	else:
		x_input = 0.0
		y_input = 0.0
		
	
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

@rpc("any_peer", "call_local", "reliable")
func set_skin(player_sprite_id: int):
	player_skin.texture = globResourceManager.icons.player_sprites[player_sprite_id]

func cycle_skin(dir: int):
	player_input.player_sprite_id = (player_input.player_sprite_id + dir) % globResourceManager.icons.player_sprites.size()
	set_skin.rpc(player_input.player_sprite_id)