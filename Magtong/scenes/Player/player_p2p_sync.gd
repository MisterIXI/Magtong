extends Node
@onready var player: PlayerBody = get_parent()
static var offset_helper: int = 0
var offset
func _ready():
	offset = offset_helper
	offset_helper += 1
	player.set_multiplayer_authority(get_tree().get_multiplayer().get_unique_id())
func _physics_process(delta):
	# if globSteamHandler.p2_id == -1:
	# 	return
	if globSteamHandler.is_host:
		var arr = PackedByteArray()
		arr.resize(8)
		arr.encode_float(0, player.global_position.x)
		arr.encode_float(4, player.global_position.y)
		Steam.sendP2PPacket(globSteamHandler.p2_id, arr, Steam.P2PSend.P2P_SEND_UNRELIABLE_NO_DELAY, 1 + offset)
	else:
		var size: int = Steam.getAvailableP2PPacketSize(1 + offset)
		while size > 0:
			var packet = Steam.readP2PPacket(size, 1 + offset)
			var data: PackedByteArray = packet["data"]
			var remote_id: int = packet["remote_steam_id"]
			var new_pos: Vector2 = Vector2.ZERO
			# print("data: ", data)
			new_pos.x = data.decode_float(0)
			new_pos.y = data.decode_float(4)
			# print(new_pos)
			#TODO: change send input to factor in device offset from input info
			# PhysicsServer2D.body_set_state(
			# 	player.get_rid(),
			# 	PhysicsServer2D.BODY_STATE_TRANSFORM,
			# 	Transform2D.IDENTITY.translated(new_pos)
			# )
			player.global_position = new_pos
			size = Steam.getAvailableP2PPacketSize(1 + offset)