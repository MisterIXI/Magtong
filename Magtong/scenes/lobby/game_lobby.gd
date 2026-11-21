extends Node2D
class_name GameLobby
## Lobby playground. Runs on the same simulation as the match. Teams come from the team areas players
## stand in, the match starts when a player presses MENU while everybody is ready (both decided inside the
## simulation, so all machines agree). The authority (host or local game) manages the roster: joins and
## leaves rebuild the lobby on every machine from the state the authority sends.

var current_map: MapScript
@export var map_root: Node2D
@export var player_game_banner: ReadyBanner
var map_pack: MapPack
var all_ready = false
var map_id: int = 0
var team_count: int
var team_max_size: int
var puck_count: int
var _starting: bool = false
## one line at the top: what to do next in the lobby
## Line 1 is the next step, line 2 how to join and open the menu. "@name" is a glyph from assets/icons/prompts.
var _hint: RichTextLabel
var _hint_shown: Array = []
const HINT_GLYPH_HEIGHT := 28
const HINT_JOIN: Array[String] = ["Press any button on a gamepad or ", "@keyboard_space", " on the keyboard to join"]
const HINT_TEAMS: Array[String] = ["Walk into the orange or the cyan area to pick a team. Both teams need a player"]
const HINT_START: Array[String] = ["Everyone hold both magnets to start   ", "@xbox_lt", " ", "@xbox_rt",
		"  /  ", "@keyboard_j", " ", "@keyboard_k"]
const HINT_JOIN_MORE: Array[String] = ["Join: any gamepad button / ", "@keyboard_space", "      "]
const HINT_MENU: Array[String] = ["Menu and How to Play: ", "@xbox_button_menu", " / ", "@keyboard_escape"]

signal all_ready_changed(all_ready: bool)

func _ready():
	map_pack = ResourceManager.standard_maps
	InputManager.player_input_registered.connect(_on_player_input_registered)
	NetGame.lobby_reset.connect(_on_lobby_reset)
	_switch_map(0)
	add_child(PauseMenu.new(current_map, true, remove_local_player))
	_add_hint()
	if NetGame.is_authority():
		NetGame.player_join_requested.connect(_on_player_join_requested)
		NetGame.peer_hello.connect(_on_peer_hello)
		NetGame.peer_left.connect(_on_peer_left)
		NetGame.reset_lobby(NetGame.roster, current_map.make_lobby_state(NetGame.roster).to_bytes())
	else:
		NetGame.send_hello()

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

func _on_player_input_registered(player_input: PlayerInput):
	NetGame.request_add_player(player_input.device_id)

func _on_lobby_reset(epoch: int, roster: Array, state_bytes: PackedByteArray):
	current_map.rebuild_lobby(roster, state_bytes, epoch)

## Local lobby: takes a local player out of the lobby (pause menu "Remove Player"). The device is forgotten,
## so its next join press (any gamepad button / Space) joins it again.
func remove_local_player(device: int) -> void:
	var local_peer := NetGame.get_local_peer()
	var roster := []
	var new_state := current_map.state.copy()
	for i in range(NetGame.roster.size() - 1, -1, -1):
		var entry: Dictionary = NetGame.roster[i]
		if entry["peer"] == local_peer and entry["device"] == device:
			new_state.remove_player(MapScript.LOBBY_PUCKS + i, i)
		else:
			roster.push_front(entry)
	if roster.size() == NetGame.roster.size():
		return
	NetGame.reset_lobby(roster, new_state.to_bytes())
	InputManager.unregister_player(device)

#region authority
func _on_player_join_requested(peer: int, device: int):
	for entry in NetGame.roster:
		if entry["peer"] == peer and entry["device"] == device:
			return
	var skin: int = randi() % ResourceManager.icons.player_sprites.size()
	var roster := NetGame.roster.duplicate(true)
	roster.append({"peer": peer, "device": device, "skin": skin})
	NetGame.reset_lobby(roster, current_map.add_player_to_state(current_map.state, skin).to_bytes())

func _on_peer_hello(_peer: int):
	NetGame.reset_lobby(NetGame.roster, current_map.state.to_bytes())

func _on_peer_left(peer: int):
	var roster := []
	var new_state := current_map.state.copy()
	for i in range(NetGame.roster.size() - 1, -1, -1):
		if NetGame.roster[i]["peer"] == peer:
			new_state.remove_player(MapScript.LOBBY_PUCKS + i, i)
		else:
			roster.push_front(NetGame.roster[i])
	NetGame.reset_lobby(roster, new_state.to_bytes())
#endregion

func _process(_delta):
	if current_map.session == null:
		return
	var team_sizes := current_map.sim.lobby_team_sizes(current_map.state)
	_update_lobby_labels(team_sizes)
	var now_ready := current_map.sim.is_lobby_ready(current_map.state)
	_update_hint(now_ready)
	if now_ready != all_ready:
		all_ready = now_ready
		all_ready_changed.emit(all_ready)
	if not _starting:
		# only start from a confirmed state, a predicted start could still be rolled back
		var confirmed := current_map.session.get_confirmed_state()
		if confirmed != null and confirmed.start_tick != -1:
			_start_match(confirmed)

func _add_hint() -> void:
	_hint = RichTextLabel.new()
	_hint.name = "LobbyHint"
	_hint.fit_content = true
	_hint.scroll_active = false
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override(&"normal_font_size", 18)
	_hint.add_theme_constant_override(&"outline_size", 6)
	_hint.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	$CanvasLayer.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 4

func _update_hint(is_ready: bool) -> void:
	_hint.visible = not InputManager.join_blocked # hidden while the pause menu is open
	var step := HINT_START if is_ready else HINT_TEAMS
	if NetGame.roster.is_empty():
		step = HINT_JOIN
	var footer: Array[String] = HINT_MENU if step == HINT_JOIN else HINT_JOIN_MORE + HINT_MENU
	var lines := [step, footer]
	if lines == _hint_shown:
		return
	_hint_shown = lines
	_hint.clear()
	_hint.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	for i in lines.size():
		if i > 0:
			_hint.newline()
		for part: String in lines[i]:
			if part.begins_with("@"):
				var glyph: Texture2D = load(HowToPlay.PROMPTS_DIR + part.substr(1) + ".svg")
				_hint.add_image(glyph, 0, HINT_GLYPH_HEIGHT, Color.WHITE, INLINE_ALIGNMENT_CENTER)
			else:
				_hint.add_text(part)
	_hint.pop()

func _update_lobby_labels(team_sizes: PackedInt32Array):
	for i in current_map.lobby_labels.size():
		var text = str(team_sizes[i] if i < team_sizes.size() else 0)
		if i > 0:
			text += "/" + str(team_max_size)
		current_map.lobby_labels[i].text = text

## Every machine calls this with the same confirmed state, so they all set up the same match.
func _start_match(confirmed: SimState) -> void:
	_starting = true
	var match_players := []
	for i in NetGame.roster.size():
		NetGame.roster[i]["skin"] = confirmed.skin[i]
		var entry: Dictionary = NetGame.roster[i].duplicate()
		entry["team"] = confirmed.zone[i]
		if entry["team"] > 0: # spectators do not play
			match_players.append(entry)
	NetGame.match_setup = {
		"session": "M%d_%d" % [NetGame.epoch, confirmed.start_tick],
		"seed": confirmed.rng | 1,
		"players": match_players,
	}
	GameManager.start_game()
