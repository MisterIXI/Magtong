extends Node2D
class_name MapScript

@export var player_spawn_groups: Array[SpawnPointGroup] = []
@export var ball_spawn_group: SpawnPointGroup
@export var spawner: MultiplayerSpawner
@export var mp_root: Node2D
@export var player_body: PackedScene
@export var puck_body: PackedScene

var player_sg_indices: Array[int] = []

signal goal_scored(team: int)

var settings: PlayerSettings
var pucks: Array[Puck] = []
var players: Array[Array] = []
var mm: MatchManager
var im: InputManager

var max_team_size: int
func _ready():
	im = globInputManager
	settings = globResourceManager.player_settings
	player_sg_indices = []
	for i in range(player_spawn_groups.size()):
		player_sg_indices.append(i)

func setup(match_manager: MatchManager) -> void:
	if not multiplayer.is_server():
		return
	im = globInputManager
	mm = match_manager
	var puck = puck_body.instantiate()
	mp_root.add_child(puck,true)
	pucks.append(puck)
	players = [[],[]]
	# TODO: get team num somehow to not hardcode this
	# loop through all player inputs to build players double array (array of the teams, players[team_num][player_num])
	var team_counter = {}
	for peer in im.player_inputs:
		for player in im.player_inputs[peer]:
			var team = im.player_inputs[peer][player].team
			if team <= 0:
				continue # skip spectators and invalid team
			var new_player: PlayerBody = player_body.instantiate()
			mp_root.add_child(new_player, true)
			new_player.setup(im.player_inputs[peer][player])
			players[team - 1].append(new_player)
			team_counter[team] = team_counter.get(team, 0) + 1
			new_player.pulse_emitted.connect(on_pulse_from)
			new_player.impulse_emitted.connect(on_impulse_from)
	max_team_size = team_counter.values().max()

	
func _on_goal_collision(body: Node, team: int) -> void:
	if not multiplayer.is_server():
		return
	if body.is_in_group("puck"):
		goal_scored.emit(team)
	
func reset_field(keep_position: bool = false) -> void:
	if not multiplayer.is_server():
		return
	await get_tree().physics_frame
	reset_balls(keep_position)
	reset_players(keep_position)
	# TODO: countdown for start

func reset_balls(keep_position: bool) -> void:
	assert(multiplayer.is_server())
	ball_spawn_group.shuffle()
	for i in range(pucks.size()):
		if keep_position:
			pucks[i].reset(pucks[i].global_position, not keep_position)
		else:
			pucks[i].reset(ball_spawn_group.get_shuffled_point(i).global_position, not keep_position)
	
func reset_players(keep_position: bool) -> void:
	assert(multiplayer.is_server())
	player_sg_indices.shuffle()
	for i in len(players):
		for j in len(players[i]):
			if keep_position:
				players[i][j].reset(players[i][j].global_position)
			else:
				players[i][j].reset(player_spawn_groups[player_sg_indices[j]].spawn_points[i].global_position)
			players[i][j].reset_input.rpc()

func _physics_process(delta):
	if not multiplayer.is_server():
		return
	# step through all players and check if they are emitting magnetic field
	for team in players:
		for player in team:
			if player.state != PlayerBody.polarity.IDLE:
				# if not idle, affect all pucks
				for puck in pucks:
					var is_repelling = puck.is_plus_pol == (player.state == player.polarity.POS)
					var dist = puck.global_position.distance_to(player.global_position)
					var force = settings.magnet_dropoff.sample(dist / settings.magnet_range)
					if not is_repelling:
						force = -force
					var scaled_force = (
						(puck.global_position - player.global_position).normalized() * force * settings.magnet_force
					)
					puck.apply_central_force(scaled_force)
					player.apply_central_force( - scaled_force)
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
	for team in players:
		for player in team:
			if player.force_move_flag:
				player.reset(player.forced_pos)
				player.force_move_flag = false
			else:
				player.linear_velocity = player.linear_velocity.move_toward(player.target_vel, settings.accell * delta)
		
func on_pulse_from(pulse_pos: Vector2) -> void:
	for puck in pucks:
		var dist = puck.global_position.distance_to(pulse_pos)
		if dist < settings.pulse_range:
			puck.receive_pulse.rpc(not puck.is_plus_pol)

func on_impulse_from(impulse_pos: Vector2, polarity: PlayerBody.polarity) -> void:
	for puck in pucks:
		var puck_pol = PlayerBody.polarity.POS if puck.is_plus_pol else PlayerBody.polarity.NEG
		var mult = 1 if puck_pol == polarity else -1
		var dist = puck.global_position.distance_to(impulse_pos)
		var force = settings.magnet_dropoff.sample(dist / settings.magnet_range)
		var scaled_force = (
			(puck.global_position - impulse_pos).normalized() * force * settings.magnet_force * mult * settings.impulse_mult
		)
		puck.apply_impulse(scaled_force)