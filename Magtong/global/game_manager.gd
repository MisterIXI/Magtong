extends Node

enum State {
	MENU,
	LOBBY,
	MAP_SELECT,
	GAME,
	PAUSED,
}

var current_state: State = State.MENU
# scenes
@export var menu_scene: PackedScene
@export var lobby_scene: PackedScene
@export var map_select_scene: PackedScene
@export var default_map_scene: PackedScene

var message_log: Array = []

signal state_changed(old_state: State, new_state: State)

@export var message_vbox: VBoxContainer
@export var message_scrollbox: ScrollContainer
@export var message_panel: PanelContainer

@onready var scene_root: SceneRoot = get_node("/root/MainScene/SceneRoot")
@onready var main_menu: MainMenu = get_node("/root/MainScene/MainMenu")

func _ready():
	NetDebug.parse_args()
	NetGame.connected_to_host.connect(_on_connected_to_host)
	NetGame.connection_ended.connect(return_to_menu)
	NetGame.return_to_lobby_requested.connect(return_to_lobby)
	_handle_command_line.call_deferred()

func _change_state(new_state: State):
	var old_state = current_state
	current_state = new_state
	if new_state == State.LOBBY:
		if old_state == State.MENU:
			main_menu.hide_all()
		scene_root.change_scene(lobby_scene.instantiate())
	elif new_state == State.GAME:
		scene_root.change_scene(default_map_scene.instantiate())
	state_changed.emit(old_state, new_state)

func start_local_game():
	assert(current_state == State.MENU)
	_change_state(State.LOBBY)

#region online
func host_direct(port: int = NetGame.DEFAULT_PORT) -> void:
	var err := NetGame.host_direct(port)
	if err != OK:
		main_menu.show_message("Could not host on port %d: %s" % [port, error_string(err)])
		return
	enter_online_lobby()

## address can be "ip" or "ip:port"
func join_direct(address: String) -> void:
	var port := NetGame.DEFAULT_PORT
	if address.count(":") == 1:
		port = address.get_slice(":", 1).to_int()
		address = address.get_slice(":", 0)
	var err := NetGame.join_direct(address, port)
	if err != OK:
		main_menu.show_message("Could not connect to %s:%d: %s" % [address, port, error_string(err)])
		return
	wait_for_host()

func host_steam() -> void:
	SteamHandler.create_lobby()
	main_menu.show_message("Creating Steam lobby...", false)

## The host side is ready, go to the lobby.
func enter_online_lobby() -> void:
	main_menu.hide_message()
	if current_state == State.MENU:
		_change_state(State.LOBBY)

## A client connection is starting, wait in the menu until the host answers.
func wait_for_host() -> void:
	main_menu.show_message("Connecting...", false)

func _on_connected_to_host() -> void:
	enter_online_lobby()

## Leaves the match. Online every machine calls this on its own (the match ended in the simulation, or
## the host sent return_to_lobby), the lobby then syncs up through the host.
func return_to_lobby() -> void:
	if current_state == State.GAME:
		_change_state(State.LOBBY)

## Leaves any online session and shows the main menu, optionally with a message.
func return_to_menu(message: String = "") -> void:
	NetGame.leave()
	SteamHandler.leave_lobby()
	InputManager.clear_players()
	if current_state != State.MENU:
		var old_state = current_state
		current_state = State.MENU
		scene_root.change_scene(null)
		main_menu.switch_to_menu(main_menu.start_menu)
		state_changed.emit(old_state, current_state)
	if message != "":
		main_menu.show_message(message)

## --host[=port] / --join=ip[:port] start an online session right away (testing, debug builds only)
func _handle_command_line() -> void:
	if not NetDebug.dev_tools_enabled():
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--host" or arg.begins_with("--host="):
			host_direct(arg.get_slice("=", 1).to_int() if "=" in arg else NetGame.DEFAULT_PORT)
		elif arg.begins_with("--join="):
			join_direct(arg.get_slice("=", 1))
#endregion

func print_message(message: String):
	message_log.append(message)
	print("[gm]: ", message)
	var label = Label.new()
	label.text = message
	message_vbox.add_child(label)
	# wait for the box to change
	await get_tree().process_frame
	await get_tree().process_frame
	# scroll to the bottom
	message_scrollbox.scroll_vertical = int(message_scrollbox.get_v_scroll_bar().max_value)

func _input(event):
	# F12 shows the message log (debug builds only)
	if NetDebug.dev_tools_enabled() and event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		toggle_message_panel()

func toggle_message_panel():
	message_panel.visible = not message_panel.visible

func start_game():
	_change_state(State.GAME)
