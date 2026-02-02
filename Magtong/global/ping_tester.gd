extends Node
@onready var ping_label: Label = $'../CanvasLayer/PingLabel'
@export var timer: Timer
var ping_time: int = 0
var arr_acc: Array[int] = []
var steam_acc: Array[int] = []
var steam_ping_arrived: bool = false
var rpc_ping_arrived: bool = false
var rpc_result: float = 0
var steam_result: float = 0

func _ready():
	timer.start()
	
func on_timeout():
	if multiplayer.has_multiplayer_peer() and globSteamHandler.lobby_id != 0:
		if not pings_finished():
			if (Time.get_ticks_usec() - ping_time) / 1000. / 1000. > 2:
				# on timeout:
				rpc_ping_arrived = true
				steam_ping_arrived = true
				finish_pings()
				pass
			# print("Tick... ", (Time.get_ticks_usec()- ping_time ) / 1000. / 1000.)
			timer.start()
			return
		steam_ping_arrived = false
		rpc_ping_arrived = false
		ping_time = Time.get_ticks_usec()
		if not globSteamHandler.is_host:
			ping_start.rpc_id(1, multiplayer.multiplayer_peer.get_unique_id())
			Steam.sendP2PPacket(globSteamHandler.lobby_host_steam_id, PackedByteArray([0]), Steam.P2PSend.P2P_SEND_UNRELIABLE_NO_DELAY, 100)
		else:
			ping_start.rpc_id(globGameManager.p2_id, 1)
			Steam.sendP2PPacket(globSteamHandler.p2_id, PackedByteArray([0]), Steam.P2PSend.P2P_SEND_UNRELIABLE_NO_DELAY, 100)

func _process(delta):
	var size: int = Steam.getAvailableP2PPacketSize(100)
	while size > 0:
		var packet = Steam.readP2PPacket(size, 100)
		var data: PackedByteArray = packet["data"]
		var remote_id: int = packet["remote_steam_id"]
		if data[0] == 0:
			# respond to ping
			Steam.sendP2PPacket(remote_id, PackedByteArray([1]), Steam.P2PSend.P2P_SEND_UNRELIABLE_NO_DELAY, 100)
		else:
			# receive ping
			steam_result = Time.get_ticks_usec() - ping_time
			steam_ping_arrived = true
			finish_pings()
		size = Steam.getAvailableP2PPacketSize(100)
@rpc("any_peer", "call_local", "reliable")
func ping_start(return_id):
	ping_receive.rpc_id(return_id)

@rpc("any_peer", "call_local", "reliable")
func ping_receive():
	rpc_result = Time.get_ticks_usec() - ping_time
	rpc_ping_arrived = true
	finish_pings()

func pings_finished():
	return steam_ping_arrived and rpc_ping_arrived

func finish_pings():
	if not pings_finished():
		return
	rpc_result /= 1000.
	arr_acc.append(rpc_result)
	if arr_acc.size() > 60:
		arr_acc.pop_front()
	var avg_rpc = arr_acc.reduce(func(acc, num): return acc + num) / arr_acc.size()
	steam_result /= 1000.
	steam_acc.append(steam_result)
	if steam_acc.size() > 60:
		steam_acc.pop_front()
	var avg_steam = steam_acc.reduce(func(acc, num): return acc + num) / steam_acc.size()
	ping_label.text = "RPC:   PING: %3dms AVG: %3dms\nSTEAM: %3dms AVG: %3dms" % [int(rpc_result), int(avg_rpc), int(steam_result), int(avg_steam)]
	timer.start()



