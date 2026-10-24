extends Node2D
class_name MapScript
## Owns the Simulation of a map. Builds it from the map nodes (rink, spawn points, lobby areas),
## steps it every physics tick with the sampled player inputs and updates the player and puck views.
## Simulation coordinates are the local coordinates of mp_root.

@export var player_spawn_groups: Array[SpawnPointGroup] = []
@export var ball_spawn_group: SpawnPointGroup
@export var mp_root: Node2D
@export var team_indicator_groups: SpawnPointGroup
@export var rink: RinkOutline
## index in the array is the team of the area (0 = spectators)
@export var lobby_areas: Array[Area2D]
@export var lobby_labels: Array[Label]

var is_lobby_map: bool = false

signal player_entered_team_area(player_input: PlayerInput, team: int)
signal player_left_team_area(player_input: PlayerInput, team: int)

var sim: Simulation
var state: SimState # the state that is shown
## matches run through a rollback session (local only, or the rollback test with a fake remote peer)
var session: RollbackSession
var harness: LocalNetHarness
var players: Array[PlayerBody] = []
var player_inputs: Array[PlayerInput] = []
var pucks: Array[Puck] = []
var _zones: PackedInt32Array = PackedInt32Array()
var im: InputManager

func _ready():
	im = globInputManager
	add_child(NetDebugOverlay.new(self))

func set_lobby_mode() -> void:
	is_lobby_map = true
	_create_sim(Simulation.Mode.LOBBY)
	for team in lobby_areas.size():
		sim.add_team_area(_area_rect(lobby_areas[team]), team)
	# spawn two pucks for players to play around with
	_spawn_puck(Vector2.LEFT * 50)
	_spawn_puck(Vector2.RIGHT * 50)
	_update_views()

func disable_lobby_features() -> void:
	for area in lobby_areas:
		area.visible = false

func spawn_player(player_input: PlayerInput) -> PlayerBody:
	return _spawn_player(player_input, Vector2.ZERO, 0, 0)

func setup(_match_manager: MatchManager, match_time: float) -> void:
	disable_lobby_features()
	var match_inputs: Array[PlayerInput] = []
	for player_input in im.get_all_player_inputs():
		if player_input.team > 0: # skip spectators and invalid team
			match_inputs.append(player_input)
	var seed := _new_seed()
	var pair := _build_match_sim(match_time, seed, match_inputs)
	sim = pair[0]
	state = pair[1]
	var owners := PackedInt32Array()
	if NetDebug.enabled:
		# rollback test: team 1 plays on this machine, team 2 on a fake remote one with its own simulation
		for player_input in match_inputs:
			owners.append(0 if player_input.team == 1 else 1)
		var remote_pair := _build_match_sim(match_time, seed, match_inputs)
		harness = LocalNetHarness.new([pair, remote_pair], owners, NetDebug.input_delay, seed)
		NetDebug.apply_network(harness.network)
		session = harness.sessions[0]
	else:
		for player_input in match_inputs:
			owners.append(0)
		session = RollbackSession.new(sim, state, 0, owners, 0)
	_add_puck_view()
	for player_input in match_inputs:
		_add_player_view(player_input)
	_update_views()

## A match simulation, built the same way every time for the same seed and players.
func _build_match_sim(match_time: float, seed: int, match_inputs: Array[PlayerInput]) -> Array:
	var match_sim := _new_sim(Simulation.Mode.MATCH)
	var match_state := SimState.new()
	match_state.rng = seed
	match_sim.match_length_ticks = roundi(match_time * Simulation.TICK_RATE)
	for point in ball_spawn_group.spawn_points:
		match_sim.puck_spawns.append(_to_sim(point.global_position))
	for group in player_spawn_groups:
		var points := PackedVector2Array()
		for point in group.spawn_points:
			points.append(_to_sim(point.global_position))
		match_sim.player_spawn_groups.append(points)
	match_sim.add_puck(match_state, Vector2.ZERO)
	var team_sizes := {}
	for player_input in match_inputs:
		var team: int = player_input.team
		match_sim.add_player(match_state, Vector2.ZERO, team, team_sizes.get(team, 0))
		team_sizes[team] = team_sizes.get(team, 0) + 1
	match_sim.start_match(match_state)
	return [match_sim, match_state]

func _create_sim(mode: Simulation.Mode) -> void:
	sim = _new_sim(mode)
	state = SimState.new()
	state.rng = _new_seed()

func _new_sim(mode: Simulation.Mode) -> Simulation:
	var new_sim := Simulation.new(globResourceManager.player_settings, mode)
	new_sim.set_rink(rink, _sim_transform(rink), mode == Simulation.Mode.MATCH)
	return new_sim

func _new_seed() -> int:
	return hash(Time.get_ticks_usec()) & 0x7FFFFFFF | 1

func _spawn_puck(pos: Vector2) -> Puck:
	sim.add_puck(state, pos)
	return _add_puck_view()

func _spawn_player(player_input: PlayerInput, pos: Vector2, team: int, team_slot: int) -> PlayerBody:
	sim.add_player(state, pos, team, team_slot)
	var new_player := _add_player_view(player_input)
	new_player.update_from_sim(state, sim.player_body(players.size() - 1), players.size() - 1)
	return new_player

func _add_puck_view() -> Puck:
	var puck: Puck = globResourceManager.puck_scene.instantiate()
	mp_root.add_child(puck, true)
	pucks.append(puck)
	return puck

func _add_player_view(player_input: PlayerInput) -> PlayerBody:
	var new_player: PlayerBody = globResourceManager.player_scene.instantiate()
	mp_root.add_child(new_player, true)
	new_player.setup_player(self, player_input, is_lobby_map)
	players.append(new_player)
	player_inputs.append(player_input)
	_zones.append(-1)
	return new_player

func _physics_process(_delta):
	if sim == null:
		return
	var inputs := PackedInt32Array()
	for player_input in player_inputs:
		inputs.append(player_input.sample())
	if harness != null:
		harness.tick(func(player: int, _target_tick: int): return inputs[player], Time.get_ticks_msec())
	elif session != null:
		for p in inputs.size():
			session.add_local_input(p, inputs[p])
		session.advance()
	else:
		sim.step(state, inputs)
	if session != null:
		# rollbacks and snapshots replace the state object
		state = session.state
	_update_views()
	if is_lobby_map:
		_emit_zone_changes()

func _update_views() -> void:
	for k in pucks.size():
		pucks[k].update_from_sim(state, k)
	for i in players.size():
		players[i].update_from_sim(state, sim.player_body(i), i)

func _emit_zone_changes() -> void:
	for i in players.size():
		var zone := state.zone[i]
		if zone == _zones[i]:
			continue
		if _zones[i] != -1:
			player_left_team_area.emit(player_inputs[i], _zones[i])
		if zone != -1:
			player_entered_team_area.emit(player_inputs[i], zone)
		_zones[i] = zone

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_F3:
		rink.debug_draw_in_game = not rink.debug_draw_in_game

#region coordinate helpers
func _sim_transform(node: Node2D) -> Transform2D:
	return mp_root.global_transform.affine_inverse() * node.global_transform

func _to_sim(global_pos: Vector2) -> Vector2:
	return mp_root.to_local(global_pos).snapped(Vector2(RinkOutline.SNAP, RinkOutline.SNAP))

func _area_rect(area: Area2D) -> Rect2:
	for child in area.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size: Vector2 = child.shape.size
			return _sim_transform(child) * Rect2(-size / 2, size)
	push_warning("Lobby area without a RectangleShape2D: " + area.name)
	return Rect2()
#endregion

func get_max_pucks() -> int: return ball_spawn_group.size()

func get_team_count() -> int: return player_spawn_groups[0].size()

func get_max_team_size() -> int: return player_spawn_groups.size()
