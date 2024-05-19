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
	globInputManager.player_input_registered.connect(on_player_input_registered)
	map_pack = globResourceManager.standard_maps
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
	
func on_player_input_registered(player_input: PlayerInput):
	current_map.spawn_player(player_input)

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
	_update_lobby_labels()
	ready_check()

func _update_lobby_labels():
	for i in current_map.lobby_labels.size():
		var text = str(curr_team_sizes[i])
		if i > 0:
			text += "/" + str(team_max_size)
		current_map.lobby_labels[i].text = text

func ready_check():
	var now_ready = _are_all_players_ready()
	for i in team_count:
		if curr_team_sizes[i+1] == 0:
			now_ready = false
	if all_ready != now_ready:
		all_ready = now_ready
		all_ready_changed.emit(all_ready)

func _are_all_players_ready() -> bool:
	for p_i in globInputManager.get_all_player_inputs():
		if p_i.team == - 1:
			return false
	return true
	