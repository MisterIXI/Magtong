extends Node
class_name InputManager

var player_mappings: Dictionary = {} # maps device IDs to playermappings (local only)
var player_inputs: Dictionary = {} # maps peer IDs to dictionaries of deviceID->PlayerInput

@onready var own_id: int = multiplayer.get_unique_id()

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
				var node = get_node("/root/MatchManager")
				if node:
					node.restart_match.rpc()
	if input_locked:
		return
	# check for keyboard
	if event is InputEventKey:
		if player_mappings.has( - 1):
			var input = player_mappings[- 1].check_input(event)
			if input:
				send_input.rpc_id(1, -1, input)
		elif globGameManager.current_state == GameManager.State.LOBBY:
			request_player_registration.rpc_id(1, - 1)
	# check for gamepad buttons
	elif event is InputEventJoypadButton:
		if player_mappings.has(event.device):
			var input = player_mappings[event.device].check_input(event)
			if input:
				send_input.rpc_id(1, event.device, input)
		elif globGameManager.current_state == GameManager.State.LOBBY:
			request_player_registration.rpc_id(1, event.device)
	# check for gamepad axis
	elif event is InputEventJoypadMotion:
		if player_mappings.has(event.device):
			var input = player_mappings[event.device].check_input(event)
			if input:
				send_input.rpc_id(1, event.device, input)

@rpc("any_peer", "call_local", "reliable")
func send_input(device_id: int, input_info: InputInfo) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	# check if player input exists
	if not player_inputs.has(peer_id) or not player_inputs[peer_id].has(device_id):
		return
	player_inputs[peer_id][device_id].execute_input(input_info)

@rpc("any_peer", "call_local", "reliable")
func request_player_registration(device_id: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	# if dictionary does not exist, create it
	if not player_inputs.has(peer_id):
		player_inputs[peer_id] = {}
	if not player_inputs[peer_id].has(device_id):
		# create placeholder to prevent multiple requests
		player_inputs[peer_id][device_id] = null
		register_player.rpc(peer_id, device_id)

@rpc("authority", "call_local", "reliable")
func register_player(peer_id: int, device_id: int) -> void:
	## registeres a new input on the player requesting to input stuff. this is local at first, but sends the inputs to the server
	# check if player with device
	if peer_id == own_id:
		player_mappings[device_id] = PlayerMapping.new(peer_id, true if device_id == -1 else false)
	# if dictionary does not exist, create it
	if not player_inputs.has(peer_id):
		player_inputs[peer_id] = {}
	# create player input
	var player_input = PlayerInput.new(peer_id, device_id)
	player_inputs[peer_id][device_id] = player_input
	player_input.name = "PlayerInput_" + str(peer_id) + "_" + str(device_id)
	globInputManager.add_child(player_input, true)
	if globGameManager.current_state == GameManager.State.LOBBY:
		var lobby = get_node("/root/Lobby")
		lobby.set_current_container(player_input)

