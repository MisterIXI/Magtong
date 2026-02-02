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
	# if multiplayer.is_server():
	# 	if event is InputEventKey and event.is_pressed():
	# 		if event.keycode == KEY_P:
	# 			var node = globGameManager.scene_root.current_scene
	# 			if node is MatchManager:
	# 				node.restart_match.rpc()
	# check for keyboard
	if event is InputEventKey:
		if player_mappings.has(-1):
			var input = player_mappings[-1].check_input(event)
			if input:
				# send_input.rpc_id(1, -1, input.to_dict())
				if multiplayer.is_server():
					send_input(-1, input)
				else:
					input.peer_id = get_tree().get_multiplayer().get_unique_id()
					var result = Steam.sendP2PPacket(globSteamHandler.lobby_host_steam_id, input.pack_byte_arr(), Steam.P2PSend.P2P_SEND_UNRELIABLE_NO_DELAY)
					# print("Input result: ", result)
		elif globGameManager.current_state == GameManager.State.LOBBY:
			request_player_registration.rpc_id(1, -1)
	# check for gamepad buttons
	elif event is InputEventJoypadButton:
		if player_mappings.has(event.device):
			var input = player_mappings[event.device].check_input(event)
			if input:
				# send_input.rpc_id(1, event.device, input.to_dict())
				if multiplayer.is_server():
					send_input(event.device, input)
				else:
					input.peer_id = get_tree().get_multiplayer().get_unique_id()
					Steam.sendP2PPacket(globSteamHandler.lobby_host_steam_id, input.pack_byte_arr(), Steam.P2PSend.P2P_SEND_UNRELIABLE_NO_DELAY)
		elif globGameManager.current_state == GameManager.State.LOBBY:
			request_player_registration.rpc_id(1, event.device)
			
	# check for gamepad axis
	elif event is InputEventJoypadMotion:
		if player_mappings.has(event.device):
			var input = player_mappings[event.device].check_input(event)
			if input:
				# send_input.rpc_id(1, event.device, input.to_dict())
				if multiplayer.is_server():
					send_input(event.device, input)
				else:
					input.peer_id = get_tree().get_multiplayer().get_unique_id()

					Steam.sendP2PPacket(globSteamHandler.lobby_host_steam_id, input.pack_byte_arr(), Steam.P2PSend.P2P_SEND_UNRELIABLE_NO_DELAY)
func set_input_locked(locked: bool) -> void:
	input_locked = locked
	if not locked:
		input_unlocked.emit()

func _process(_delta):
	if globSteamHandler.lobby_id == 0:
		return

	var size: int = Steam.getAvailableP2PPacketSize(0)
	while size > 0:
		# print("received input packets!!1!!1!")
		var packet = Steam.readP2PPacket(size, 0)
		var data: PackedByteArray = packet["data"]
		var remote_id: int = packet["remote_steam_id"]
		var input_info = InputInfo.from_byte_arr(data)
		#TODO: change send input to factor in device id from input info
		send_input(input_info.device_id, input_info, globGameManager.p2_id)
		size = Steam.getAvailableP2PPacketSize(0)


# @rpc("any_peer", "call_local", "reliable")
func send_input(device_id: int, input_info: InputInfo, remote_id: int = 1) -> void:
	# if input_locked:
	# 	return
	# print("Received Input: ", input_info.to_string())
	# var peer_id: int = input_info.peer_id
	var peer_id: int = remote_id
	# check if player input exists
	# print("peer_id: ", peer_id)
	# print("device_id: ", device_id)
	if not player_inputs.has(peer_id) or not player_inputs[peer_id].has(device_id):
		# print(player_inputs)
		push_error("Input not found :o")
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
	player_mappings[device_id] = PlayerMapping.new(multiplayer.get_unique_id(), true if device_id == -1 else false)
	
func get_all_player_inputs() -> Array:
	var all_inputs = []
	for peer_id in player_inputs.keys():
		for device_id in player_inputs[peer_id].keys():
			all_inputs.append(player_inputs[peer_id][device_id])
	return all_inputs
