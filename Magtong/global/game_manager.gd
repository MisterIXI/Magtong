extends Node
class_name GameManager

enum State {
	MENU,
	LOBBY,
	MAP_SELECT,
	GAME,
	PAUSED,
}

var input_locked: bool = false
var current_state: State = State.MENU
# scenes
@export var menu_scene: PackedScene
@export var lobby_scene: PackedScene
@export var map_select_scene: PackedScene
@export var default_map_scene: PackedScene

var message_log: Array = []

@export var timer: Timer
var countdown: int = 3
signal state_changed(old_state: State, new_state: State)

@export var message_vbox: VBoxContainer
@export var message_scrollbox: ScrollContainer
@export var message_panel: PanelContainer

var player_ids: Dictionary = {}
var p_id_helper: int = 1
@onready var scene_root: SceneRoot = get_node("/root/MainScene/SceneRoot")

@rpc("authority", "call_local", "reliable")
func _change_state(new_state: State):
	var old_state = current_state
	current_state = new_state
	if new_state == State.LOBBY:
		if old_state == State.MENU:
			scene_root.hide_menu()
		if multiplayer.is_server():
			scene_root.change_scene(lobby_scene.instantiate())
	elif new_state == State.GAME:
		if multiplayer.is_server():
			scene_root.change_scene(default_map_scene.instantiate())
	state_changed.emit(old_state, new_state)

func host_game(is_local: bool, suppress_state_change: bool = false):
	assert(current_state == State.MENU)
	multiplayer.peer_connected.connect(_on_peer_connected)
	var peer = ENetMultiplayerPeer.new()
	var retval
	if is_local:
		# 1 max client
		retval = peer.create_server(12345, 1)
	else:
		# 32 max clients
		retval = peer.create_server(12345, 32)
	if retval:
		print("Server error: ", retval)
	else:
		print("Server created on port 12345")
	multiplayer.multiplayer_peer = peer
	if not suppress_state_change:
		_change_state.rpc(State.LOBBY)
	_on_peer_connected(1)

func join_game(ip: String, port: int):
	assert(current_state == State.MENU)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.server_disconnected.connect(_on_disconnected)
	var peer = ENetMultiplayerPeer.new()
	var returnval = peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	print("Client return val: ", returnval)
	print("Client connected to ", ip, ":", port)
	print_message("is_server " + str(multiplayer.is_server()))
	print_message("Client return val: " + str(returnval))

	_change_state(State.LOBBY)

func lobby_finished():
	pass

@rpc("any_peer", "call_local", "reliable")
func send_message(message: String):
	print_message(message)

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

func start_countdown():
	countdown = 3
	timer.start()

func cancel_countdown():
	timer.stop()
	countdown = 0

func countdown_step():
	if countdown > 0:
		send_message.rpc(str(countdown) + "...")
		countdown -= 1
		timer.start()
	elif countdown == 0:
		send_message.rpc("Start!")
		if current_state == State.LOBBY:
			#TODO: change to map select scene when implemented
			_change_state.rpc(State.GAME)

func _input(event):
	# check if F12 is pressed
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		toggle_message_panel()

func toggle_message_panel():
	message_panel.visible = not message_panel.visible

func start_game():
	_change_state(State.GAME)

func _on_peer_connected(peer_id: int):
	player_ids[peer_id] = p_id_helper
	send_message.rpc("New player connected! ID: " + str(p_id_helper))
	p_id_helper += 1
	if current_state == State.LOBBY:
		pass

func _on_connected():
	print_message("Connected to server!")

func _on_disconnected():
	print_message("Disconnected from server!")
