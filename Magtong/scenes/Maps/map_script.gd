extends Node2D
class_name MapScript

@export var player_spawn_groups: Array[SpawnPointGroup] = []
@export var ball_spawn_group: SpawnPointGroup
@export var spawner: MultiplayerSpawner
@export var mp_root: Node2D
@export var team_indicator_groups: SpawnPointGroup
@export var divider_collider: StaticBody2D
@export var lobby_areas: Array[Area2D]
@export var lobby_labels: Array[Label]

var is_lobby_map: bool = false
var player_sg_indices: Array[int] = []

signal goal_scored(team: int)
signal player_entered_team_area(player_input: PlayerInput, team: int)
signal player_left_team_area(player_input: PlayerInput, team: int)
signal player_puck_count_changed()

var spawned_pucks: Array[Puck] = []
var spawned_players: Array[PlayerBody] = []
var pucks: Array[Puck] = []
var players: Array[Array] = []
var settings: PlayerSettings
var mm: MatchManager
var im: InputManager
func _ready():
	im = globInputManager
	settings = globResourceManager.player_settings
	player_sg_indices = []
	for i in range(player_spawn_groups.size()):
		player_sg_indices.append(i)

func set_lobby_mode() -> void:
	players = [[]]
	is_lobby_map = true
	pucks = []
	# spawn two pucks for players to play around with
	pucks.append(spawn_puck())
	pucks[0].global_position += Vector2.LEFT * 50
	pucks.append(spawn_puck())
	pucks[1].global_position += Vector2.RIGHT * 50
	if divider_collider != null:
		var childs = divider_collider.get_children()
		for child: CollisionShape2D in childs:
			child.set_deferred("disabled", true)

@rpc("authority", "call_local", "reliable")
func disable_lobby_features() -> void:
	for area in lobby_areas:
		area.set_deferred("disabled", true)
		area.monitorable = false
		area.monitoring = false
		area.visible = false

func spawn_player(player_input: PlayerInput) -> PlayerBody:
	var player_body = globResourceManager.player_scene
	var new_player: PlayerBody = player_body.instantiate()
	mp_root.add_child(new_player, true)
	new_player.setup_player(self, player_input, is_lobby_map)
	new_player.pulse_emitted.connect(on_pulse_from)
	players[0].append(new_player)
	print("all player_inputs: ", globInputManager.get_all_player_inputs()[0].team)
	return new_player

func spawn_puck() -> Puck:
	var puck_body = globResourceManager.puck_scene
	var puck = puck_body.instantiate()
	mp_root.add_child(puck, true)
	return puck

func setup(match_manager: MatchManager) -> void:
	if not multiplayer.is_server():
		return
	disable_lobby_features.rpc()
	im = globInputManager
	mm = match_manager
	var player_body = globResourceManager.player_scene
	pucks.append(spawn_puck())
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
			new_player.setup_player(self, im.player_inputs[peer][player]) 
			players[team - 1].append(new_player)
			team_counter[team] = team_counter.get(team, 0) + 1
			new_player.pulse_emitted.connect(on_pulse_from)

func _on_goal_collision(body: Node, team: int) -> void:
	if not multiplayer.is_server():
		return
	if is_lobby_map:
		return
	if body.is_in_group("Puck"):
		goal_scored.emit(team)
	
func reset_field(keep_position: bool=false) -> void:
	# if not multiplayer.is_server():
	# 	return
	# await get_tree().physics_frame
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
			players[i][j].reset_input_state.rpc()

func _physics_process(delta):
	if not multiplayer.is_server():
		return
	# step through all players and check if they are emitting magnetic field
	for team in players:
		for player in team:
			if player.state != PlayerBody.Polarity.IDLE:
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

func get_max_pucks() -> int: return ball_spawn_group.size()

func get_team_count() -> int: return player_spawn_groups[0].size()

func get_max_team_size() -> int: return player_spawn_groups.size()

func on_player_entered_team_area(body: Node2D, team: int):
	if multiplayer.is_server() and body.is_in_group("PlayerBody"):
		player_entered_team_area.emit(body.player_input, team)
		if body.is_in_group("PlayerBody"):
			body.player_input.team = team
			# print("Player entered team area ", body.player_input.team)

func on_player_left_team_area(body: Node2D, team: int):
	if multiplayer.is_server() and body.is_in_group("PlayerBody"):
		if globGameManager.current_state == GameManager.State.LOBBY:
			player_left_team_area.emit(body.player_input, team)
			if body.is_in_group("PlayerBody"):
				body.player_input.team = -1

func on_node_spawned(node: Node) -> void:
	if node.is_in_group("PlayerBody"):
		spawned_players.append(node)
	elif node.is_in_group("Puck"):
		spawned_pucks.append(node)

