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

var player_ids: Dictionary = {}
var p_id_helper: int = 1

@rpc("authority", "call_local", "reliable")
func _change_state(new_state: State):
	var old_state = current_state
	current_state = new_state
	if new_state == State.LOBBY:
		get_tree().change_scene_to_packed(lobby_scene)
	elif new_state == State.GAME:
		#TODO: change to map select scene when implemented
		# for now just set teams manually and load the default map
		if multiplayer.is_server():
			var im = globInputManager
			var p1 = im.get_child(0)
			var p2 = im.get_child(1)
			p1.team = 1
			p2.team = 2
		get_tree().change_scene_to_packed(default_map_scene)
	state_changed.emit(old_state, new_state)



func host_game(is_local: bool):
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
	_change_state.rpc(State.LOBBY)
	multiplayer.multiplayer_peer = peer
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
	print_message("is_server "+ str(multiplayer.is_server()))
	print_message("Client return val: " + str(returnval))

	_change_state(State.LOBBY)

func lobby_finished():
	pass


@rpc("any_peer", "call_local", "reliable" )
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
	# scroll to the bottom
	message_scrollbox.scroll_vertical = int(message_scrollbox.get_v_scroll_bar().max_value)

func start_countdown():
	countdown = 3
	timer.timeout.connect(countdown_step)
	timer.start()

func cancel_countdown():
	timer.stop()
	countdown = 0

func countdown_step():
	if countdown > 0:
		send_message.rpc(str(countdown)+ "...")
		countdown -= 1
		timer.start()
	elif countdown == 0:
		send_message.rpc("Start!")
		if current_state == State.LOBBY:
			#TODO: change to map select scene when implemented
			_change_state.rpc(State.GAME)

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