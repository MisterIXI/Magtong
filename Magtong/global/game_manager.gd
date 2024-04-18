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



@rpc("authority", "call_local", "reliable")
func _change_state(new_state: State):
	var old_state = current_state
	current_state = new_state
	if new_state == State.LOBBY:
		get_tree().change_scene_to_packed(lobby_scene)
	elif new_state == State.GAME:
		#TODO: change to map select scene when implemented
		# for now just set teams manually and load the default map
		var im = globInputManager
		im.player_inputs.get(1).get(-1).team = 1
		im.player_inputs.get(1).get(0).team = 2
		get_tree().change_scene_to_packed(default_map_scene)
	state_changed.emit(old_state, new_state)



func host_game(is_local: bool):
	assert(current_state == State.MENU)
	var peer = ENetMultiplayerPeer.new()
	if is_local:
		# 1 max client
		peer.create_server(12345, 1)
	else:
		# 32 max clients
		peer.create_server(12345, 32)
	print("Server created on port 12345")
	_change_state(State.LOBBY)
	multiplayer.peer_connected.connect(_on_peer_connected)

func join_game(ip: String, port: int):
	assert(current_state == State.MENU)
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	print("Client connected to ", ip, ":", port)
	_change_state(State.LOBBY)

func lobby_finished():
	pass

@rpc("authority", "call_local", "reliable")
func send_message(message: String):
	print_message(message)

func print_message(message: String):
	message_log.append(message)
	print("New Message received: ", message)
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
			_change_state(State.GAME)

func _on_peer_connected(id: int):
	send_message.rpc("New player connected! ID: " + str(id))
	if current_state == State.LOBBY:
		pass