extends CanvasLayer
class_name PauseMenu
## Pause menu of local matches. Any player opens it with Start / Esc during the countdown or the match, and any
## player can navigate, resume or leave (local players are trusted to behave). Pausing pauses the whole scene
## tree, so the simulation simply stops ticking. Online there is no pause, MatchManager doesn't add it there.

const THEME: Theme = preload("res://scenes/menu/main_menu_theme.tres")
const PANEL_STYLE: StyleBox = preload("res://resources/default_box.tres")
const DIM_COLOR := Color(0, 0, 0, 0.55)

var map: MapScript
var _resume_button: Button

func _init(map: MapScript) -> void:
	self.map = map
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
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.theme_type_variation = &"HeaderLarge"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_resume_button = _add_button(box, "Resume", resume)
	_add_button(box, "Back to Lobby", _leave.bind(GameManager.return_to_lobby))
	_add_button(box, "Main Menu", _leave.bind(GameManager.return_to_menu.bind("")))

func _add_button(box: VBoxContainer, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 0)
	button.pressed.connect(on_pressed)
	box.add_child(button)
	return button

func _input(event: InputEvent) -> void:
	if visible:
		if _is_pause_button(event) or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			UiSounds.play(UiSounds.Sound.BACK)
			resume()
	elif _is_pause_button(event) and _can_pause():
		get_viewport().set_input_as_handled()
		UiSounds.play(UiSounds.Sound.CONFIRM)
		open()

## Only during the countdown and the match: after the game over Start means rematch (in the simulation).
func _can_pause() -> bool:
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
	get_tree().paused = true
	visible = true
	_resume_button.grab_focus.call_deferred()

func resume() -> void:
	visible = false
	get_tree().paused = false
	# the button that confirmed (A, Space, Start, ...) is a game button too, it must not act in the first tick
	for player_input in InputManager.get_all_player_inputs():
		player_input.release_buttons()

func _leave(leave: Callable) -> void:
	resume()
	leave.call()
