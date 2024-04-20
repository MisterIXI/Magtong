extends Control
class_name Lobby

@onready var input_manager: InputManager = globInputManager
@export var player_container: PackedScene
@export var lobby_container: HFlowContainer
func _ready():
	if multiplayer.is_server():
		create_new_container()
		multiplayer.peer_connected.connect(_on_peer_connected)

func check_for_ready():
	assert(multiplayer.is_server())
	print("Check for ready...")
	# check if all players are ready
	var is_ready = true
	if input_manager.total_player_count() < 2:
		# not enough players
		is_ready = false
	else:
		for peer in input_manager.player_inputs:
			for player_input in input_manager.player_inputs[peer]:
				if not input_manager.player_inputs[peer][player_input].is_ready:
					is_ready = false
					break
	if is_ready:
		# all players are ready, start the lobby countdown
		globGameManager.start_countdown()
	else:
		# in case someone unreadied, cancel the countdown
		globGameManager.cancel_countdown()

## on the server: react on new peers and update their lobby accordingly
func _on_peer_connected(peer_id: int):
	if globGameManager.current_state == GameManager.State.LOBBY:
		var pcs = lobby_container.get_children()
		for i in range(pcs.size()):
			var pc:PlayerContainer = pcs[i]
			if pc.player_input:
				set_container.rpc_id(peer_id, i, pc.player_input.to_dict(), globGameManager.player_ids[peer_id])

@rpc("authority", "call_local", "reliable")
func set_container(index: int, dict: Dictionary, player_id: int):
	var player_containers = lobby_container.get_children()
	if index >= player_containers.size():
		globGameManager.send_message.rpc("Error: PlayerContainer index "+ str(index)+ " out of bounds")
	else:
		player_containers[index].set_player(dict, player_id)

func connect_container(index: int, player_input: PlayerInput):
	var pcs = lobby_container.get_children()
	if index < pcs.size():
		pcs[index].connect_player(player_input)

func create_new_container():
	var new_player_container = player_container.instantiate()
	lobby_container.add_child(new_player_container, true)

func get_pc_count():
	return lobby_container.get_child_count()