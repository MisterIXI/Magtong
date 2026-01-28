class_name PlayerSpawner
extends Node
@export var spawn_root: Node
@export var player_scene: PackedScene
@onready var map: MapScript = get_parent()

func _ready():
	if multiplayer.is_server():
		globInputManager.player_input_registered.connect(call_spawn_rpc)

func call_spawn_rpc(player_input:PlayerInput):
	spawn_player.rpc(player_input.to_dict())

@rpc("call_local", "reliable", "authority")
func spawn_player(player_input_dict: Dictionary):
	var player_input = PlayerInput.new().from_dict(player_input_dict)
	var player_body = player_scene
	var new_player: PlayerBody = player_body.instantiate()
	new_player.player_input = player_input
	spawn_root.add_child(new_player, true)
	new_player.set_multiplayer_authority(1)
	new_player.setup_player(player_input)
	if multiplayer.is_server():
		map.players[0].append(new_player)
	if not globInputManager.player_inputs.has(player_input.peer_id):
		globInputManager.player_inputs[player_input.peer_id] = {}
	globInputManager.player_inputs[player_input.peer_id][player_input.device_id] = player_input
	if new_player.input != null:
		new_player.input.set_multiplayer_authority(player_input.peer_id)
	