extends Node2D
class_name TrailerScene


var players: Array[PlayerBody] = []
var pucks: Array[Puck] = []
@export var spawns: Array[Node2D] = []
var p1: PlayerBody
var p2: PlayerBody
var p3: PlayerBody
var tween: Tween
@export var audio_player: AudioStreamPlayer
@export var settings: PlayerSettings
var fake_map: MapScript

func _ready():
	# infographic_pull()
	pulse()
	# switch()
	# trailer_tween()


func pulse():
	fake_map = MapScript.new()
	fake_map.pucks = pucks
	var fake_input = PlayerInput.new()
	players.append(spawn_player())
	players[-1].reset_once(Vector2.LEFT * 100)
	p1 = players[-1]
	p1.pulse_emitted.connect(on_player_pulse)
	p1.setup_player(fake_map, fake_input)
	pucks.append(globResourceManager.puck_scene.instantiate())
	add_child(pucks[-1])
	pucks[-1].reset(Vector2.RIGHT * 290, false)
	p1.current_ability.settings = settings
	tween = create_tween()
	tween.tween_interval(0.7)
	tween.tween_callback(p1.on_input.bind(input_info_axis_minus(1.0)))
	tween.tween_interval(0.4)
	tween.tween_callback(p1.on_input.bind(input_info_pulse()))
	tween.tween_interval(0.5)
	tween.tween_callback(p1.on_input.bind(input_info_axis_minus(0.0)))
	tween.tween_callback(p1.on_input.bind(input_info_axis_plus(1.0)))
	tween.tween_interval(0.1)
	tween.tween_callback(p1.on_input.bind(input_info_pulse()))
	tween.tween_interval(0.4)
	tween.tween_callback(p1.on_input.bind(input_info_axis_plus(0.0)))
	tween.tween_property(p1, "global_position", Vector2.LEFT * 100, 0.4)

func switch():
	fake_map = MapScript.new()
	fake_map.pucks = pucks
	players.append(spawn_player())
	players[-1].reset_once(Vector2.ZERO)
	p1 = players[-1]
	p1.pulse_emitted.connect(on_player_pulse)
	pucks.append(globResourceManager.puck_scene.instantiate())
	add_child(pucks[-1])
	pucks[-1].reset(Vector2.LEFT * 100, false)
	pucks.append(globResourceManager.puck_scene.instantiate())
	add_child(pucks[-1])
	pucks[-1].reset(Vector2.RIGHT * 100, false)
	
	tween = create_tween()
	tween.tween_interval(0.7)
	tween.tween_callback(p1.on_input.bind(input_info_switch()))
	tween.tween_interval(1.5)
	tween.tween_callback(p1.on_input.bind(input_info_switch()))

func infographic_pull():
	fake_map = MapScript.new()
	fake_map.pucks = pucks
	var fake_input = PlayerInput.new()
	players.append(spawn_player())
	players[-1].reset_once(Vector2.ZERO)
	p1 = players[-1]

	pucks.append(globResourceManager.puck_scene.instantiate())
	add_child(pucks[-1])
	pucks[-1].reset(Vector2.LEFT * 290, false)
	pucks.append(globResourceManager.puck_scene.instantiate())
	add_child(pucks[-1])
	pucks[-1].reset(Vector2.RIGHT * 290, false)
	
	tween = create_tween()
	tween.tween_interval(0.7)
	tween.tween_callback(p1.on_input.bind(input_info_axis_minus(1.0)))
	tween.tween_interval(0.8)
	tween.tween_callback(p1.on_input.bind(input_info_axis_minus(0.0)))
	tween.tween_interval(1.3)
	tween.tween_callback(p1.on_input.bind(input_info_axis_plus(1.0)))
	tween.tween_interval(0.4)
	tween.tween_callback(p1.on_input.bind(input_info_axis_plus(0.0)))


func trailer_tween():
	fake_map = MapScript.new()
	fake_map.pucks = pucks
	var fake_input = PlayerInput.new()

	players.append(spawn_player())
	players[-1].reset_once(spawns[0].global_position)
	p1 = players[-1]
	p1.setup_player(fake_map, fake_input, false)
	players.append(spawn_player())
	players[-1].reset_once(spawns[1].global_position)
	p2 = players[-1]
	p2.setup_player(fake_map, fake_input, false)
	p2.set_skin(1)
	players.append(spawn_player())
	players[-1].reset_once(spawns[2].global_position)
	p3 = players[-1]
	p3.setup_player(fake_map, fake_input, false)
	p3.set_skin(2)

	#pucks
	pucks.append(globResourceManager.puck_scene.instantiate())
	add_child(pucks[-1])
	pucks[-1].reset(spawns[3].global_position, false)
	pucks.append(globResourceManager.puck_scene.instantiate())
	add_child(pucks[-1])
	pucks[-1].reset(spawns[4].global_position, false)
	pucks.append(globResourceManager.puck_scene.instantiate())
	add_child(pucks[-1])
	pucks[-1].reset(spawns[5].global_position, false)
	pucks.append(globResourceManager.puck_scene.instantiate())
	add_child(pucks[-1])
	pucks[-1].reset(spawns[6].global_position, false)

	tween = create_tween()
	tween.tween_interval(0.7)
	tween.tween_callback(audio_player.play.bind())
	tween.tween_callback(p1.on_input.bind(input_info_axis_x(1.0)))
	tween.tween_interval(0.3)
	tween.tween_callback(p1.on_input.bind(input_info_axis_x(0)))
	tween.tween_interval(0.7)
	tween.tween_callback(p2.on_input.bind(input_info_axis_x(-1.0)))
	tween.tween_interval(0.3)
	tween.tween_callback(p2.on_input.bind(input_info_axis_x(0)))
	tween.tween_interval(0.7)
	tween.tween_callback(p3.on_input.bind(input_info_axis_x(1.0)))
	tween.tween_interval(0.3)
	tween.tween_callback(p3.on_input.bind(input_info_axis_x(0)))
	tween.tween_interval(0.7)
	tween.tween_callback(p1.on_input.bind(input_info_axis_minus(1.0)))
	tween.tween_callback(p2.on_input.bind(input_info_axis_minus(1.0)))
	tween.tween_callback(p3.on_input.bind(input_info_axis_minus(1.0)))
	tween.tween_interval(1.0)
	tween.tween_callback(p1.on_input.bind(input_info_axis_plus(1.0)))
	tween.tween_callback(p1.on_input.bind(input_info_axis_minus(0.0)))
	tween.tween_callback(p2.on_input.bind(input_info_axis_plus(1.0)))
	tween.tween_callback(p2.on_input.bind(input_info_axis_minus(0.0)))
	tween.tween_callback(p3.on_input.bind(input_info_axis_plus(1.0)))
	tween.tween_callback(p3.on_input.bind(input_info_axis_minus(0.0)))
	tween.tween_callback(p1.on_input.bind(input_info_pulse()))
	tween.tween_callback(p2.on_input.bind(input_info_pulse()))
	tween.tween_callback(p3.on_input.bind(input_info_pulse()))

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
					force = - force
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

func input_info_pulse() -> InputInfo:
	return InputInfo.new({
		"input_type": InputInfo.InputType.SECONDARY,
		"is_pressed": true,
		"axis_value": 0.0,
	})

func input_info_switch() -> InputInfo:
	return InputInfo.new({
		"input_type": InputInfo.InputType.PRIMARY,
		"is_pressed": true,
		"axis_value": 0.0,
	})

func spawn_player() -> PlayerBody:
	var player_body = globResourceManager.player_scene
	var new_player: PlayerBody = player_body.instantiate()
	add_child(new_player, true)
	return new_player

func on_player_pulse(_pos):
	for puck in pucks:
		puck.receive_pulse(not puck.is_plus_pol)