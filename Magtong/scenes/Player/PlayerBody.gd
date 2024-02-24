extends CharacterBody2D
class_name PlayerBody

var player: int = 0
@export var settings: PlayerSettings
enum polarity { IDLE, POS, NEG }
signal polarity_changed(new_pol: polarity)
signal pulse_emitted

var state = polarity.IDLE

var target_vel: Vector2 = Vector2()


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


func check_impulse_input():
	if player == 0 or player == 1:
		if Input.is_action_just_pressed("impulse_1"):
			emit_signal("pulse_emitted")
	if player == 0 or player == 2:
		if Input.is_action_just_pressed("impulse_2"):
			emit_signal("pulse_emitted")


func _process(_delta):
	# in process, process inputs
	check_polarity_input()
	check_movement_input()
	check_impulse_input()


func _physics_process(delta):
	# move velocity towards target velocity
	velocity = velocity.move_toward(target_vel, settings.accell * delta)
	move_and_slide()
	# print("velocity: " + str(velocity) + " target_vel: " + str(target_vel))
