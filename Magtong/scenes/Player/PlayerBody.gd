extends RigidBody2D
class_name PlayerBody

@export var player: int = 0
@export var settings: PlayerSettings
enum polarity { IDLE, POS, NEG }
signal polarity_changed(new_pol: polarity)
signal pulse_emitted

@export var opponent: PlayerBody
@export var puck: Puck
var state = polarity.IDLE

var target_vel: Vector2 = Vector2()
@export var pulse_timer: Timer
@export var game_field: Game
var forced_pos: Vector2 = Vector2()
var force_move_flag: bool = false

## If the polarity is different from the current state, update the state and emit signal
func change_polarity(new_pol: polarity):
	if new_pol != state:
		state = new_pol
		emit_signal("polarity_changed", state)


## Check for polarity inputs, differenciated by playerID and
## calls change_polarity with the correct polarity
func check_polarity_input():
	var pos = false
	var neg = false
	# if solo player
	if player == 0:
		if Input.is_action_pressed("pos_1") or Input.is_action_pressed("pos_2"):
			pos = true
		if Input.is_action_pressed("neg_1") or Input.is_action_pressed("neg_2"):
			neg = true
	elif player == 1:
		if Input.is_action_pressed("pos_1"):
			pos = true
		if Input.is_action_pressed("neg_1"):
			neg = true
	elif player == 2:
		if Input.is_action_pressed("pos_2"):
			pos = true
		if Input.is_action_pressed("neg_2"):
			neg = true

	if not neg and not pos:
		change_polarity(polarity.IDLE)
	elif pos and not neg:
		change_polarity(polarity.POS)
	elif neg and not pos:
		change_polarity(polarity.NEG)


func update_target_vel(new_vel: Vector2):
	if new_vel.length() > 1:
		new_vel = new_vel.normalized()
	target_vel = new_vel * settings.speed


## Check for movement inputs and normalize the target velocity
func check_movement_input():
	var p1_input = Vector2()
	var p2_input = Vector2()
	if player == 0 or player == 1:
		p1_input.x = (
			Input.get_action_strength("move_right_1") - Input.get_action_strength("move_left_1")
		)
		p1_input.y = (
			Input.get_action_strength("move_down_1") - Input.get_action_strength("move_up_1")
		)
	if player == 0 or player == 2:
		p2_input.x = (
			Input.get_action_strength("move_right_2") - Input.get_action_strength("move_left_2")
		)
		p2_input.y = (
			Input.get_action_strength("move_down_2") - Input.get_action_strength("move_up_2")
		)
	target_vel = p1_input + p2_input
	update_target_vel(target_vel)

func reset(new_forced_pos: Vector2):
	linear_velocity = Vector2()
	angular_velocity = 0
	change_polarity(polarity.IDLE)
	target_vel = Vector2()
	force_move_flag = true
	self.forced_pos = new_forced_pos
	PhysicsServer2D.body_set_state(
		get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D.IDENTITY.translated(new_forced_pos)
	)


func try_to_pulse():
	if pulse_timer.is_stopped():
		pulse_timer.start()
		if puck.global_position.distance_to(global_position) < settings.pulse_range:
			puck.receive_pulse()
		emit_signal("pulse_emitted")


func check_impulse_input():
	if player == 0 or player == 1:
		if Input.is_action_just_pressed("impulse_1"):
			try_to_pulse()
	if player == 0 or player == 2:
		if Input.is_action_just_pressed("impulse_2"):
			try_to_pulse()


func _process(_delta):
	# in process, process inputs
	if not game_field.input_locked:
		check_polarity_input()
		check_movement_input()
		check_impulse_input()


func _physics_process(delta):
	if state != polarity.IDLE:
		#  apply magnetism to puck
		var is_repelling = puck.is_plus_pol == (state == polarity.POS)
		var dist = puck.global_position.distance_to(global_position)
		print("Distance: " + str(dist))
		var force = settings.magnet_dropoff.sample(dist / settings.magnet_range)

		if not is_repelling:
			force *= -1
		print("Magnet_force: " + str(force))
		var scaled_force = (
			(puck.global_position - global_position).normalized() * force * settings.magnet_force
		)
		print("Scaled_force: " + str(scaled_force))
		puck.apply_central_force(scaled_force)
		apply_central_force(-scaled_force)
		if opponent != null:
			# apply magnetism to opponent
			is_repelling = (opponent.state == polarity.POS) == (state == polarity.POS)
			dist = opponent.global_position.distance_to(global_position)
			force = settings.magnet_dropoff.sample(dist / settings.magnet_range)
			if not is_repelling:
				force *= -1
			scaled_force = (
				(opponent.global_position - global_position).normalized()
				* force
				* settings.magnet_force
			)
			opponent.apply_central_force(scaled_force)
			apply_central_force(-scaled_force)
	# move velocity towards target velocity
	linear_velocity = linear_velocity.move_toward(target_vel, settings.accell * delta)

	# velocity = velocity.move_toward(target_vel, settings.accell * delta)
	# move_and_slide()
	# print("velocity: " + str(velocity) + " target_vel: " + str(target_vel))
