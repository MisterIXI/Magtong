extends CanvasLayer
class_name PauseMenu
## Menu of the lobby and the match. Any local player opens it with Start / Esc (in a match during the countdown
## or the match), and any local player can navigate, resume or leave (local players are trusted to behave).
## Local games pause the whole scene tree, so the simulation simply stops ticking. Online the game can't pause:
## it keeps running, and this machine's players send empty input while the menu is open.
## Lobby: Resume, Remove Player (host / local game: a list of this machine's players, picking one takes it out of
## the lobby, its next button press joins it again), Main Menu.
## Match: Resume, Back to Lobby (host / local game, for everybody), Main Menu.
## A client gets "Leave" instead of Main Menu: the host then removes its players (lobby) or ends the match.

const THEME: Theme = preload("res://scenes/menu/main_menu_theme.tres")
const PANEL_STYLE: StyleBox = preload("res://resources/default_box.tres")
const DIM_COLOR := Color(0, 0, 0, 0.55)

var map: MapScript
var _resume_button: Button
var _in_lobby: bool
var _online: bool
## lobby, host / local game only: removes the local player with this device id
var _remove_player: Callable
var _main_box: VBoxContainer
var _player_box: VBoxContainer
var _remove_button: Button

## remove_player: lobby only, (device: int) -> void.
func _init(map: MapScript, in_lobby: bool = false, remove_player: Callable = Callable()) -> void:
	self.map = map
	_in_lobby = in_lobby
	_online = NetGame.is_online()
	_remove_player = remove_player if NetGame.is_authority() else Callable()
	name = "PauseMenu"
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	var root := Control.new()
	root.theme = THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", PANEL_STYLE)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 32)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_main_box = _add_box(stack, "Menu" if _online else "Paused")
	_resume_button = _add_button(_main_box, "Resume", resume)
	if _in_lobby and _remove_player.is_valid():
		_remove_button = _add_button(_main_box, "Remove Player", _show_players)
		_player_box = _add_box(stack, "Remove Player")
		_player_box.visible = false
	if not _in_lobby and NetGame.is_authority():
		# NetGame sends the clients along, offline it just goes back
		_add_button(_main_box, "Back to Lobby", _leave.bind(NetGame.request_return_to_lobby))
	var leave_text := "Leave" if not NetGame.is_authority() else "Main Menu"
	_add_button(_main_box, leave_text, _leave.bind(GameManager.return_to_menu.bind("")))

func _add_box(parent: Control, title_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	parent.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = &"HeaderLarge"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	return box

func _add_button(box: VBoxContainer, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 0)
	button.pressed.connect(on_pressed)
	box.add_child(button)
	return button

func _input(event: InputEvent) -> void:
	if visible:
		if _player_box != null and _player_box.visible and event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			UiSounds.play(UiSounds.Sound.BACK)
			_show_main(_remove_button)
		elif _is_pause_button(event) or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			UiSounds.play(UiSounds.Sound.BACK)
			resume()
	elif _is_pause_button(event) and _can_pause():
		get_viewport().set_input_as_handled()
		UiSounds.play(UiSounds.Sound.CONFIRM)
		open()

## Lobby: until the match start is decided. Match: only during the countdown and the match, after the game
## over Start means rematch (in the simulation).
func _can_pause() -> bool:
	if _in_lobby:
		return map.state.start_tick == -1
	var phase := map.state.phase
	return phase == Simulation.Phase.COUNTDOWN or phase == Simulation.Phase.PLAYING

func _is_pause_button(event: InputEvent) -> bool:
	if event.is_echo() or not event.is_pressed():
		return false
	if event is InputEventKey:
		return event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		return event.button_index == JOY_BUTTON_START and InputManager.is_gamepad(event.device)
	return false

func open() -> void:
	if not _online:
		get_tree().paused = true
	map.inputs_blocked = true
	visible = true
	_show_main(_resume_button)

func _show_main(focus: Button) -> void:
	_main_box.visible = true
	if _player_box != null:
		_player_box.visible = false
	focus.grab_focus.call_deferred()

## One button per local player (sim order = roster order), plus Back.
func _show_players() -> void:
	for child in _player_box.get_children():
		if child is Button:
			child.queue_free()
	var first: Button = null
	var local_peer := NetGame.get_local_peer()
	for i in NetGame.roster.size():
		var entry: Dictionary = NetGame.roster[i]
		if entry["peer"] != local_peer:
			continue
		var device: int = entry["device"]
		var kind := "Keyboard" if device == InputManager.KEYBOARD_DEVICE_ID else "Gamepad"
		var button := _add_button(_player_box, "Player %d (%s)" % [i + 1, kind], _on_remove_pressed.bind(device))
		if first == null:
			first = button
	var back := _add_button(_player_box, "Back", _show_main.bind(_remove_button))
	_main_box.visible = false
	_player_box.visible = true
	(first if first != null else back).grab_focus.call_deferred()

func _on_remove_pressed(device: int) -> void:
	_remove_player.call(device)
	_show_main(_remove_button)

func resume() -> void:
	visible = false
	if not _online:
		get_tree().paused = false
	map.inputs_blocked = false
	# the button that confirmed (A, Space, Start, ...) is a game button too, it must not act in the first tick
	for player_input in InputManager.get_all_player_inputs():
		player_input.release_buttons()

func _leave(leave: Callable) -> void:
	resume()
	leave.call()
