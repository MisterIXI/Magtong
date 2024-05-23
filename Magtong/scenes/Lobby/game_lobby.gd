extends Node2D
class_name GameLobby

var current_map: MapScript
@export var map_root: Node2D
@export var player_game_banner: ReadyBanner
var map_pack: MapPack
var all_ready = false
var map_id: int = 0
var team_count: int
var team_max_size: int
var puck_count: int
var curr_team_sizes: Array[int] = []

signal all_ready_changed(all_ready: bool)

func _ready():
	if multiplayer.is_server():
		map_pack = globResourceManager.standard_maps
		globInputManager.player_input_registered.connect(on_player_input_registered)
		multiplayer.peer_connected.connect(on_peer_connected)
		_switch_map(0)

func _switch_map(id: int):
	if current_map != null:
		current_map.queue_free()
	map_id = id
	current_map = map_pack.maps[map_id].instantiate() as MapScript
	map_root.add_child(current_map)
	current_map.set_lobby_mode()
	team_count = current_map.get_team_count()
	team_max_size = current_map.get_max_team_size()
	puck_count = current_map.get_max_pucks()
	curr_team_sizes = []
	for i in team_count + 1: # +1 for spectator_team
		curr_team_sizes.append(0)
	current_map.player_entered_team_area.connect(on_player_entered_team_area)
	current_map.player_left_team_area.connect(on_player_exited_team_area)

func on_peer_connected(peer_id: int):
	assert(multiplayer.is_server())
	catchup_on_join.rpc_id(peer_id, team_max_size, all_ready)
	_update_lobby_labels.rpc_id(peer_id, curr_team_sizes)

func on_player_input_registered(player_input: PlayerInput):
	current_map.spawn_player(player_input)
	ready_check()

func on_player_entered_team_area(player_input: PlayerInput, team: int):
	print("Player entered team area")
	player_input.team = team
	curr_team_sizes[team] += 1
	team_update()

func on_player_exited_team_area(player_input: PlayerInput, team: int):
	print("Player exited team area")
	player_input.team = -1
	curr_team_sizes[team] -= 1
	team_update()

func team_update():
	_update_lobby_labels. rpc (curr_team_sizes)
	ready_check()

@rpc("authority", "call_local", "reliable")
func _update_lobby_labels(team_sizes: Array):
	# print(team_sizes)
	for i in current_map.lobby_labels.size():
		var text = str(team_sizes[i])
		if i > 0:
			text += "/" + str(team_max_size)
		current_map.lobby_labels[i].text = text

# func _setup_lobby_labels(team_max_sizes: Array):

func ready_check():
	var now_ready = _are_all_players_ready()
	for i in team_count:
		if curr_team_sizes[i + 1] == 0:
			now_ready = false
	if all_ready != now_ready:
		all_ready = now_ready
		emit_ready.rpc(all_ready)

@rpc("authority", "call_local", "reliable")
func emit_ready(value:bool):
	all_ready_changed.emit(value)

func _are_all_players_ready() -> bool:
	for p_i in globInputManager.get_all_player_inputs():
		if p_i.team == - 1:
			return false
	return true

func request_game_start():
	if all_ready:
		globGameManager.start_game()

@rpc("authority", "call_local", "reliable")
func catchup_on_join(team_max_size: int, is_ready: bool):
	current_map = map_root.get_child(0) as MapScript
	self.team_max_size = team_max_size
	if is_ready:
		all_ready = true
		all_ready_changed.emit(all_ready)
	