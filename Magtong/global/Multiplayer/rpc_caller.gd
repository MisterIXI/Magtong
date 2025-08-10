extends Node

var is_steam: bool = true

func _ready():
	print("args: ", OS.get_cmdline_user_args())
	if not "nosteam" in OS.get_cmdline_user_args():
		print("steam")
		pass
	else:
		print("nosteam")
	pass

func steam_init() -> void:
	pass

func rpc_init() -> void:
	pass

func call_rpc(target_method: Callable, args: Array, target_id: int = -1) -> void:
	if is_steam:
		if target_id != -1:
			Steam.sendP2PPacket(target_id, PackedByteArray(args), Steam.P2P_SEND_RELIABLE, )
			pass
		else:
			for user in globSteamHandler.curr_lobby_members:
				if user["steam_id"] != globSteamHandler.steam_id:
					Steam.getLobbyOwner(
			pass
			# Steam.sendMessageToUser()
		pass
	else:
		if target_id != -1:
			args.push_front(rpc_id)
			target_method.rpc_id.callv(args)
		else:
			target_method.rpc.callv(args)
	pass

