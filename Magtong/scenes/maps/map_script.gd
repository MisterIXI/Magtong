extends Node2D
class_name MapScript
## Owns the Simulation of a map and the RollbackSession that runs it. Builds the simulation from the
## map nodes (rink, spawn points, lobby areas) and the roster, feeds the inputs of this machine's players
## into the session every physics tick, sends and receives session packets and updates the views.
## Simulation coordinates are the local coordinates of mp_root.

const LOBBY_PUCKS: int = 2

@export var player_spawn_groups: Array[SpawnPointGroup] = []
@export var ball_spawn_group: SpawnPointGroup
@export var mp_root: Node2D
@export var team_indicator_groups: SpawnPointGroup
@export var rink: RinkOutline
## index in the array is the team of the area (0 = spectators)
@export var lobby_areas: Array[Area2D]
@export var lobby_labels: Array[Label]

var is_lobby_map: bool = false

var sim: Simulation
var state: SimState # the state that is shown
var session: RollbackSession
## only in the offline rollback test (NetDebug): two sessions in this process
var harness: LocalNetHarness
var session_id: String = ""
var players: Array[PlayerBody] = []
var pucks: Array[Puck] = []
## player slot -> PlayerInput, for the players controlled on this machine
var local_inputs: Dictionary = {}
var _advantage: float = 0.0
var _ticks_since_wait: int = 0

func _ready():
	add_child(NetDebugOverlay.new(self))

func _exit_tree():
	if session_id != "":
		NetGame.unregister_session(session_id)

#region lobby
func set_lobby_mode() -> void:
	is_lobby_map = true

func disable_lobby_features() -> void:
	for area in lobby_areas:
		area.visible = false

## A fresh lobby state with the pucks and a player for every roster entry.
func make_lobby_state(roster: Array) -> SimState:
	var new_state := SimState.new()
	new_state.rng = _new_seed()
	_add_lobby_bodies(_new_lobby_sim(), new_state, roster)
	return new_state

## Copy of the state with one more player (in the middle of the field).
func add_player_to_state(source: SimState, skin: int) -> SimState:
	var new_state := source.copy()
	Simulation.new(ResourceManager.player_settings, Simulation.Mode.LOBBY).add_player(new_state, Vector2.ZERO, 0, 0, skin)
	return new_state

## Rebuilds the lobby simulation and session. Every machine does this with the same roster and state.
func rebuild_lobby(roster: Array, state_bytes: PackedByteArray, epoch: int) -> void:
	_clear_players()
	sim = _new_lobby_sim()
	_add_lobby_bodies(sim, SimState.new(), roster) # only for the static data, the state comes from the bytes
	state = SimState.from_bytes(state_bytes)
	_start_session(_owners(roster), "L%d" % epoch, NetGame.get_input_delay())
	if pucks.is_empty():
		_add_puck_views(LOBBY_PUCKS)
	for i in roster.size():
		_add_player_view(roster[i], i, true)
	_update_views()

func _new_lobby_sim() -> Simulation:
	var lobby_sim := _new_sim(Simulation.Mode.LOBBY)
	for team in lobby_areas.size():
		lobby_sim.add_team_area(_area_rect(lobby_areas[team]), team)
	return lobby_sim

func _add_lobby_bodies(target_sim: Simulation, target_state: SimState, roster: Array) -> void:
	# two pucks for players to play around with
	target_sim.add_puck(target_state, Vector2.LEFT * 50)
	target_sim.add_puck(target_state, Vector2.RIGHT * 50)
	for entry in roster:
		target_sim.add_player(target_state, Vector2.ZERO, 0, 0, entry.get("skin", 0))
#endregion

#region match
func setup(_match_manager: MatchManager, match_time: float) -> void:
	disable_lobby_features()
	var match_setup: Dictionary = NetGame.match_setup
	var match_players: Array = match_setup["players"]
	var seed: int = match_setup["seed"]
	var pair := _build_match_sim(match_time, seed, match_players)
	sim = pair[0]
	state = pair[1]
	if not NetGame.is_online() and NetDebug.enabled:
		# rollback test: team 1 plays on this machine, team 2 on a fake remote one with its own simulation
		var owners := PackedInt32Array()
		for entry in match_players:
			owners.append(0 if entry["team"] == 1 else 1)
		var remote_pair := _build_match_sim(match_time, seed, match_players)
		harness = LocalNetHarness.new([pair, remote_pair], owners, NetDebug.input_delay, seed)
		NetDebug.apply_network(harness.network)
		session = harness.sessions[0]
	else:
		_start_session(_owners(match_players), match_setup["session"], NetGame.get_input_delay())
	_add_puck_views(1)
	for i in match_players.size():
		_add_player_view(match_players[i], i, false)
	_update_views()

## A match simulation, built the same way on every machine for the same seed and players.
func _build_match_sim(match_time: float, seed: int, match_players: Array) -> Array:
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
	for entry in match_players:
		var team: int = entry["team"]
		match_sim.add_player(match_state, Vector2.ZERO, team, team_sizes.get(team, 0), entry.get("skin", 0))
		team_sizes[team] = team_sizes.get(team, 0) + 1
	match_sim.start_match(match_state)
	return [match_sim, match_state]
#endregion

#region session
func _start_session(owners: PackedInt32Array, id: String, input_delay: int) -> void:
	if session_id != "":
		NetGame.unregister_session(session_id)
	session = RollbackSession.new(sim, state, NetGame.get_local_peer(), owners, input_delay)
	session_id = id
	if NetGame.is_online():
		NetGame.register_session(id, _on_session_packet)

func _on_session_packet(packet: Dictionary, now_ms: int) -> void:
	session.receive_packet(packet, now_ms)

func _owners(entries: Array) -> PackedInt32Array:
	var owners := PackedInt32Array()
	for entry in entries:
		owners.append(entry["peer"])
	return owners

func _physics_process(_delta):
	if session == null:
		return
	var now := Time.get_ticks_msec()
	if harness != null:
		harness.tick(func(player: int, _target_tick: int): return _sample(player), now)
	else:
		if session.can_advance() and not _should_wait_for_peers(now):
			for slot in local_inputs:
				session.add_local_input(slot, local_inputs[slot].sample())
			session.advance()
		else:
			if not session.can_advance():
				session.stalls += 1
			session.resolve_rollback()
		if NetGame.is_online():
			NetGame.send_session_packet(session_id, session.make_packet(now))
	# rollbacks and snapshots replace the state object
	state = session.state
	_update_views()

func _sample(slot: int) -> int:
	return local_inputs[slot].sample() if local_inputs.has(slot) else SimInput.EMPTY

## Time sync: if we run ahead of the other machines, skip a tick now and then so they catch up.
## Otherwise we would predict further and further ahead and roll back more and more.
func _should_wait_for_peers(now_ms: int) -> bool:
	if not NetGame.is_online():
		return false
	_advantage = lerpf(_advantage, session.get_frame_advantage(now_ms), 0.1)
	_ticks_since_wait += 1
	if _advantage > 1.0 and _ticks_since_wait > 4:
		_ticks_since_wait = 0
		session.time_sync_waits += 1
		return true
	return false
#endregion

#region views
func _add_puck_views(count: int) -> void:
	for i in count:
		var puck: Puck = ResourceManager.puck_scene.instantiate()
		mp_root.add_child(puck, true)
		pucks.append(puck)

func _add_player_view(entry: Dictionary, slot: int, in_lobby: bool) -> void:
	var view: PlayerBody = ResourceManager.player_scene.instantiate()
	mp_root.add_child(view, true)
	var player_input: PlayerInput = null
	if entry["peer"] == NetGame.get_local_peer():
		player_input = InputManager.player_inputs.get(entry["device"])
	if player_input != null:
		local_inputs[slot] = player_input
	view.setup_player(self, player_input, in_lobby)
	players.append(view)

func _clear_players() -> void:
	for view in players:
		view.queue_free()
	players.clear()
	local_inputs.clear()

func _update_views() -> void:
	for k in pucks.size():
		pucks[k].update_from_sim(state, k)
	for i in players.size():
		players[i].update_from_sim(state, sim.player_body(i), i)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_F3:
		rink.debug_draw_in_game = not rink.debug_draw_in_game
#endregion

#region helpers
func _new_sim(mode: Simulation.Mode) -> Simulation:
	var new_sim := Simulation.new(ResourceManager.player_settings, mode)
	new_sim.set_rink(rink, _sim_transform(rink), mode == Simulation.Mode.MATCH)
	new_sim.skin_count = ResourceManager.icons.player_sprites.size()
	return new_sim

func _new_seed() -> int:
	return hash(Time.get_ticks_usec()) & 0x7FFFFFFF | 1

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

func get_max_pucks() -> int: return ball_spawn_group.size()

func get_team_count() -> int: return player_spawn_groups[0].size()

func get_max_team_size() -> int: return player_spawn_groups.size()
#endregion
