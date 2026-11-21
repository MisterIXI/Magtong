class_name MainMenu
extends Control
@export var start_menu: Control
@export var start_entry_focus: Control
@export var settings_menu: SettingsMenu
@export var mm_background: PackedScene
@export var address_edit: LineEdit
@export var host_steam_button: Button
@export var message_panel: Control
@export var message_label: Label
@export var message_ok_button: Button
## Debug builds only: local lobby whose matches last this many seconds, for quick testing
const TEST_MATCH_TIME: float = 15.0
@export var start_local_button: Button
var curr_mm_bg: MMBackground
## windows built in code (_add_window): How to Play above Settings, Credits above Quit
var how_to_play: HowToPlay
var credits: Credits
## window -> the start menu button that opens it (focus goes back there when the window closes)
var _window_buttons: Dictionary[Control, Button] = {}
var previous_menu: Control
var current_menu: Control
## full-screen, behind the message panel: no clicks on the menu while a message is open
var _message_blocker: Control
## focused before the message opened, gets the focus back when it closes
var _focus_before_message: Control
## the message has no OK ("Connecting..."), its button cancels instead
var _message_cancels: bool = false

func _ready() -> void:
	_message_blocker = Control.new()
	_message_blocker.name = "MessageBlocker"
	_message_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_message_blocker.top_level = true # StartMenu has no size, so the blocker sizes itself to the screen
	message_panel.add_sibling(_message_blocker)
	message_panel.get_parent().move_child(_message_blocker, message_panel.get_index())
	# the only control that can have focus while the message is open
	var self_path := NodePath(".")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		message_ok_button.set_focus_neighbor(side, self_path)
	message_ok_button.focus_next = self_path
	message_ok_button.focus_previous = self_path
	hide_message()
	settings_menu.closed.connect(settings_close)
	_window_buttons[settings_menu] = settings_menu_button()
	how_to_play = _add_window(HowToPlay.new(), "How to Play", settings_menu_button())
	credits = _add_window(Credits.new(), "Credits", start_menu.get_node("VBoxContainer/Quit"))
	_wrap_menu_focus.call_deferred()
	host_steam_button.disabled = not SteamHandler.is_initialized
	if NetDebug.dev_tools_enabled():
		_add_test_match_button()
	hide_all()
	current_menu = start_menu
	current_menu.show()
	spawn_mm_background()
	if start_entry_focus != null:
		start_entry_focus.call_deferred("grab_focus")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if current_menu is MenuWindow and not current_menu.blocks_cancel():
			UiSounds.play(UiSounds.Sound.BACK)
			_back_to_start_menu()
		
func hide_all() -> void:
	start_menu.hide()
	settings_menu.hide()
	how_to_play.hide()
	credits.hide()
	if is_instance_valid(curr_mm_bg):
		curr_mm_bg.queue_free()
	curr_mm_bg = null


func switch_to_menu(menu: Control) -> void:
	if current_menu != null:
		current_menu.hide()
	spawn_mm_background()
	previous_menu = current_menu
	current_menu = menu
	current_menu.show()
	if current_menu == start_menu:
		if start_entry_focus != null:
			start_entry_focus.call_deferred("grab_focus")
	elif current_menu == settings_menu:
		settings_menu.refresh()
		settings_menu.focus_first()
	elif current_menu is MenuWindow:
		current_menu.focus_first()

## Spawns the background unless one is already running (there is only ever one).
func spawn_mm_background() -> void:
	if mm_background != null and not is_instance_valid(curr_mm_bg):
		var mm_bg = mm_background.instantiate()
		add_child(mm_bg)
		move_child(mm_bg, -1)
		curr_mm_bg = mm_bg as MMBackground

func settings_close() -> void:
	_back_to_start_menu()

## Back from a sub panel: the start menu, with the focus on the button that opened the panel.
func _back_to_start_menu() -> void:
	var from := current_menu
	switch_to_menu(start_menu)
	var button: Button = _window_buttons.get(from)
	if button != null:
		button.grab_focus.call_deferred()

func settings_menu_button() -> Button:
	return start_menu.get_node_or_null("VBoxContainer/Settings") as Button

## Up on the first entry goes to the last one and down on the last to the first (only visible entries).
func _wrap_menu_focus() -> void:
	var entries: Array = []
	for child in start_menu.get_node("VBoxContainer").get_children():
		if child is Control and child.visible:
			entries.append(child)
	MenuWindow.wrap_focus(entries)

## Adds a window next to the settings and a start menu button for it, placed right above `before`.
func _add_window(window: MenuWindow, button_text: String, before: Button) -> MenuWindow:
	window.name = button_text.replace(" ", "")
	window.closed.connect(_back_to_start_menu)
	window.z_index = settings_menu.z_index # above the background, like the settings
	settings_menu.add_sibling(window)
	var button := Button.new()
	button.name = window.name
	button.text = button_text
	button.theme = before.theme
	button.pressed.connect(func():
		if current_menu == start_menu:
			switch_to_menu(window))
	before.add_sibling(button)
	before.get_parent().move_child(button, before.get_index())
	_window_buttons[window] = button
	return window

func _on_settings_pressed() -> void:
	if current_menu == start_menu:
		switch_to_menu(settings_menu)

func _on_start_local_pressed() -> void:
	GameManager.start_local_game()

func _add_test_match_button() -> void:
	var button := Button.new()
	button.name = "StartTestMatch"
	button.text = "Short Test Match (%d s)" % TEST_MATCH_TIME
	button.theme = start_local_button.theme
	button.pressed.connect(func(): GameManager.start_local_game(TEST_MATCH_TIME))
	start_local_button.add_sibling(button)

func _on_host_steam_pressed() -> void:
	GameManager.host_steam()

func _on_host_direct_pressed() -> void:
	GameManager.host_direct()

func _on_join_direct_pressed() -> void:
	var address := address_edit.text.strip_edges()
	GameManager.join_direct(address if address != "" else "127.0.0.1")

## A modal message. Without the OK button ("Connecting...") the button cancels and leaves instead.
func show_message(message: String, with_ok_button: bool = true) -> void:
	if not message_panel.visible:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and focused != message_ok_button:
			_focus_before_message = focused
	message_label.text = message
	_message_cancels = not with_ok_button
	message_ok_button.text = "Okay" if with_ok_button else "Cancel"
	message_panel.show()
	_message_blocker.position = Vector2.ZERO
	_message_blocker.size = get_viewport_rect().size
	_message_blocker.show()
	if with_ok_button:
		# messages with an OK button are failures (could not host/connect, host left, ...)
		UiSounds.play(UiSounds.Sound.ERROR)
	message_ok_button.grab_focus.call_deferred()

func hide_message() -> void:
	var was_open := message_panel.visible
	message_panel.hide()
	_message_blocker.hide()
	if was_open:
		_restore_focus.call_deferred()

func _restore_focus() -> void:
	if message_panel.visible:
		return
	if is_instance_valid(_focus_before_message) and _focus_before_message.is_visible_in_tree():
		_focus_before_message.grab_focus()
	elif start_entry_focus != null and start_entry_focus.is_visible_in_tree():
		start_entry_focus.grab_focus()
	_focus_before_message = null

func _on_message_button_pressed() -> void:
	if _message_cancels:
		GameManager.return_to_menu()
	hide_message()


func _on_quit_pressed() -> void:
	get_tree().quit()
