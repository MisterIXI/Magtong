class_name MMBackground
extends Node2D

var players: Array[PlayerBody] = []
var pucks: Array[Puck] = []
var p1_start_pos: Vector2 = Vector2(-1100, -500)
var p2_start_pos: Vector2 = Vector2(1100, 500)
var p3_start_pos: Vector2 = Vector2(-700, 0.0)
var p4_start_pos: Vector2 = Vector2(700, 0.0)
var tween1: Tween
var tween2: Tween
var tween3: Tween
var tween4: Tween
@export var settings: PlayerSettings

func _ready():
	# Initialize players and pucks arrays
	players = []
	pucks = []
	
	# spawn players
	players.append(spawn_player())
	players[0].reset_once(p1_start_pos)
	players[0].force_move_flag = false
	players.append(spawn_player())
	players[1].reset_once(p2_start_pos)
	players.append(spawn_player())
	players[2].reset_once(p3_start_pos)
	players.append(spawn_player())
	players[3].reset_once(p4_start_pos)

	# spawn pucks
	for i in range(8):
		var puck: Puck = globResourceManager.puck_scene.instantiate()
		add_child(puck)
		puck.reset(p1_start_pos + Vector2.DOWN * 100 * (i+1), false)
		pucks.append(puck)
		if i % 2 == 0:
			puck.receive_pulse(false)
		puck = globResourceManager.puck_scene.instantiate()
		add_child(puck)
		puck.reset(p2_start_pos + Vector2.UP * 100 * (i+1), false)
		pucks.append(puck)
		if i % 2 == 0:
			puck.receive_pulse(false)
	start_tweens()
	
func start_tweens():
	await get_tree().physics_frame
	var p1 = players[0]
	# var p2 = players[1]
	# tween for body 1
	tween1 = create_tween()
	# move right
	tween1.tween_callback(p1.on_input.bind(input_info_axis_x(0.5)))
	tween1.tween_interval(1.5)
	tween1.tween_callback(p1.on_input.bind(input_info_axis_plus(1.0)))
	tween1.tween_interval(1.5)
	# move left and down
	tween1.tween_method(
		func (x): p1.on_input(input_info_axis_y(x)),
		0.0,
		0.5,
		0.5,
	)
	tween1.parallel()
	tween1.tween_method(
		func (x): p1.on_input(input_info_axis_x(x)),
		0.5,
		-0.5,
		1.5,
	)
	# move down and right
	tween1.tween_callback(p1.on_input.bind(input_info_axis_plus(0.0)))
	tween1.tween_callback(p1.on_input.bind(input_info_axis_minus(1.0)))
	tween1.tween_method(
		func (x): x = clampf(x, 0.0, 0.5); p1.on_input(input_info_axis_y(x)),
		1.5,
		0.0,
		1.5,
	)
	tween1.parallel()
	tween1.tween_method(
		func (x): p1.on_input(input_info_axis_x(x)),
		-0.5,
		0.5,
		1.5,
	)
	tween1.tween_callback(p1.on_input.bind(input_info_axis_y(0.0)))
	tween1.tween_callback(p1.on_input.bind(input_info_axis_x(-0.5)))
	tween1.tween_interval(1.5)
	tween1.tween_callback(p1.on_input.bind(input_info_axis_minus(0.0)))
	tween1.tween_interval(1.5)
	tween1.tween_callback(p1.on_input.bind(input_info_axis_x(0.0)))
	tween1.tween_callback(p1.reset_once.bind(p1_start_pos))
	tween1.tween_interval(1.0)
	tween1.set_loops()
	tween1.play()

	# tween for body 2
	var p2 = players[1]
	tween2 = create_tween()
	# move right
	tween2.tween_callback(p2.on_input.bind(input_info_axis_x(-0.5)))
	tween2.tween_interval(1.5)
	tween2.tween_callback(p2.on_input.bind(input_info_axis_minus(1.0)))
	tween2.tween_interval(1.5)
	# move left and down
	tween2.tween_method(
		func (x): p2.on_input(input_info_axis_y(x)),
		0.0,
		-0.5,
		0.5,
	)
	tween2.parallel()
	tween2.tween_method(
		func (x): p2.on_input(input_info_axis_x(x)),
		-0.5,
		0.5,
		1.5,
	)
	# move down and right
	tween2.tween_callback(p2.on_input.bind(input_info_axis_minus(0.0)))
	tween2.tween_callback(p2.on_input.bind(input_info_axis_plus(1.0)))
	tween2.tween_method(
		func (x): x = clampf(x, -0.5, 0.0); p2.on_input(input_info_axis_y(x)),
		-1.5,
		0.0,
		1.5,
	)
	tween2.parallel()
	tween2.tween_method(
		func (x): p2.on_input(input_info_axis_x(x)),
		0.5,
		-0.5,
		1.5,
	)
	tween2.tween_callback(p2.on_input.bind(input_info_axis_y(0.0)))
	tween2.tween_callback(p2.on_input.bind(input_info_axis_x(0.5)))
	tween2.tween_interval(1.5)
	tween2.tween_callback(p2.on_input.bind(input_info_axis_plus(0.0)))
	tween2.tween_interval(1.5)
	tween2.tween_callback(p2.on_input.bind(input_info_axis_x(0.0)))
	tween2.tween_callback(p2.reset_once.bind(p2_start_pos))
	tween2.tween_interval(1.0)
	tween2.set_loops()
	tween2.play()

	# simple loops for p3 and p4
	# # p3 up and down
	# var p3 = players[2]
	# p3.on_input(input_info_axis_minus(1.0), true)
	# p3.on_input(input_info_axis_y(0.3), true)
	# tween3 = create_tween()
	# # tween3.tween_callback(p3.on_input.bind(input_info_axis_y(0.3)))
	# tween3.tween_interval(1.75)
	# tween3.tween_method(
	# 	func (x): p3.on_input(input_info_axis_y(x)),
	# 	0.3,
	# 	-0.3,
	# 	1.0,
	# )
	# tween3.tween_interval(3.5)
	# tween3.tween_method(
	# 	func (x): p3.on_input(input_info_axis_y(x)),
	# 	-0.3,
	# 	0.3,
	# 	1.0,
	# )
	# tween3.tween_interval(1.75)
	# tween3.set_loops()
	
func _physics_process(delta):
	if not multiplayer.is_server():
		return
	# step through all players and check if they are emitting magnetic field
	for player in players:
		if player.state != PlayerBody.Polarity.IDLE:
			# if not idle, affect all pucks
			for puck in pucks:
				var is_repelling = puck.is_plus_pol == (player.state == player.Polarity.POS)
				var dist = puck.global_position.distance_to(player.global_position)
				var force = settings.magnet_dropoff.sample(dist / settings.magnet_range)
				if not is_repelling:
					force = -force
				var scaled_force = (
					(puck.global_position - player.global_position).normalized() * force * settings.magnet_force
				)
				puck.apply_central_force(scaled_force)
				# player.apply_central_force( - scaled_force)
			# and affect all other players
			# for opp_team in players:
			# 	for opp_player in opp_team:
			# 		if opp_player == player:
			# 			continue
			# 		var is_repelling = player.state == opp_player.state
			# 		var dist = player.global_position.distance_to(opp_player.global_position)
			# 		var force = settings.magnet_dropoff.sample(dist / settings.magnet_range)
			# 		if not is_repelling:
			# 			force = -force
			# 		var scaled_force = (
			# 			(opp_player.global_position - player.global_position).normalized() * force * settings.magnet_force
			# 		)
			# 		opp_player.apply_central_force(scaled_force)
			# 		player.apply_central_force( - scaled_force)
# regardless of state, apply input
	for player in players:
		if player.force_move_flag:
			player.reset(player.forced_pos)
			player.force_move_flag = false
		else:
			player.linear_velocity = player.linear_velocity.move_toward(player.target_vel, settings.accell * delta)

func input_info_axis_x(value: float) -> InputInfo:
	return InputInfo.new({
		"input_type": InputInfo.InputType.MOVE_X,
		"is_pressed": true,
		"axis_value": value,
	})


func input_info_axis_y(value: float) -> InputInfo:
	return InputInfo.new({
		"input_type": InputInfo.InputType.MOVE_Y,
		"is_pressed": true,
		"axis_value": value,
	})

func input_info_axis_plus(value: float) -> InputInfo:
	return InputInfo.new({
		"input_type": InputInfo.InputType.PLUS,
		"is_pressed": true,
		"axis_value": value,
	})

func input_info_axis_minus(value: float) -> InputInfo:
	return InputInfo.new({
		"input_type": InputInfo.InputType.MINUS,
		"is_pressed": true,
		"axis_value": value,
	})

func spawn_player() -> PlayerBody:
	var player_body = globResourceManager.player_scene
	var new_player: PlayerBody = player_body.instantiate()
	add_child(new_player, true)
	return new_player
