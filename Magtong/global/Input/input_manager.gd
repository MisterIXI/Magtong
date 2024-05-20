extends Node
class_name InputManager

var player_mappings: Dictionary = {} # maps device IDs to playermappings (local only)
var player_inputs: Dictionary = {} # maps peer IDs to dictionaries of deviceID->PlayerInput
var player_cust_id: Dictionary = {} # maps peer IDs to custom IDs
var cust_id_helper: int = 1
@onready var own_id: int = multiplayer.get_unique_id()
signal input_unlocked()
signal player_input_registered(player_input: PlayerInput)
var input_locked: bool = false
func total_player_count() -> int:
	var count = 0
	for peer_dict in player_inputs.values():
		count += len(peer_dict)
	return count

func _input(event: InputEvent) -> void:
	if multiplayer.is_server():
		if event is InputEventKey and event.is_pressed():
			if event.keycode == KEY_P:
				var node = globGameManager.scene_root.current_scene
				if node is MatchManager:
					node.restart_match.rpc()
	# check for keyboard
	if event is InputEventKey:
		if player_mappings.has( - 1):
			var input = player_mappings[- 1].check_input(event)
			if input:
				send_input.rpc_id(1, -1, input.to_dict())
		elif globGameManager.current_state == GameManager.State.LOBBY:
			request_player_registration.rpc_id(1, -1)
	# check for gamepad buttons
	elif event is InputEventJoypadButton:
		if player_mappings.has(event.device):
			var input = player_mappings[event.device].check_input(event)
			if input:
				send_input.rpc_id(1, event.device, input.to_dict())
		elif globGameManager.current_state == GameManager.State.LOBBY:
			request_player_registration.rpc_id(1, event.device)
	# check for gamepad axis
	elif event is InputEventJoypadMotion:
		if player_mappings.has(event.device):
			var input = player_mappings[event.device].check_input(event)
			if input:
				send_input.rpc_id(1, event.device, input.to_dict())

func set_input_locked(locked: bool) -> void:
	input_locked = locked
	if not locked:
		input_unlocked.emit()

@rpc("any_peer", "call_local", "reliable")
func send_input(device_id: int, input_dict: Dictionary) -> void:
	# if input_locked:
	# 	return
	var input_info = InputInfo.new(input_dict)
	# print("Received Input: ", input_info.to_string())
	var peer_id: int = multiplayer.get_remote_sender_id()
	# check if player input exists
	if not player_inputs.has(peer_id) or not player_inputs[peer_id].has(device_id):
		return
	player_inputs[peer_id][device_id].execute_input(input_info)

@rpc("any_peer", "call_local", "reliable")
func request_player_registration(device_id: int) -> void:
	assert(multiplayer.is_server(), "Error: Only the server can register players!")
	## reject if not in lobby
	if globGameManager.current_state != GameManager.State.LOBBY:
		return
	var peer_id = multiplayer.get_remote_sender_id()
	# if dictionary does not exist, create it
	if not player_inputs.has(peer_id):
		player_inputs[peer_id] = {}
	if not player_inputs[peer_id].has(device_id):
		# create placeholder to prevent multiple requests
		var player_input = PlayerInput.new(peer_id, device_id, globGameManager.player_ids[peer_id])
		globInputManager.add_child(player_input, true)
		# if dictionary does not exist, create it
		if not player_inputs.has(peer_id):
			player_inputs[peer_id] = {}
		player_inputs[peer_id][device_id] = player_input
		register_player.rpc_id(peer_id, device_id)
		player_input_registered.emit(player_input)
		# var lobby:Lobby = globGameManager.scene_root.current_scene
		# lobby.connect_container(lobby.get_pc_count()-1, player_input)
		# lobby.set_container.rpc(lobby.get_pc_count()-1, player_input.to_dict(), globGameManager.player_ids[peer_id])
		# lobby.create_new_container()

@rpc("authority", "call_local", "reliable")
func register_player(device_id: int) -> void:
	player_mappings[device_id] = PlayerMapping.new(multiplayer.get_unique_id(), true if device_id == - 1 else false)
	
func get_all_player_inputs() -> Array:
	var all_inputs = []
	for peer_id in player_inputs.keys():
		for device_id in player_inputs[peer_id].keys():
			all_inputs.append(player_inputs[peer_id][device_id])
	return all_inputs
