extends Node
@onready var ping_label: Label = $'../CanvasLayer/PingLabel'
@export var timer: Timer
var ping_time: int  = 0
var arr_acc: Array[int] = []

func _ready():
	timer.start()
	
func on_timeout():
	if multiplayer.has_multiplayer_peer():
		ping_time = Time.get_ticks_usec()
		ping_start.rpc_id(1, multiplayer.multiplayer_peer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func ping_start(return_id):
	ping_receive.rpc_id(return_id)

@rpc("any_peer","call_local", "reliable")
func ping_receive():
	var roundtrip_time = Time.get_ticks_usec() - ping_time
	# convert to milliseconds
	roundtrip_time /= 1000
	arr_acc.append(roundtrip_time)
	if arr_acc.size() > 60:
		arr_acc.pop_front()
	var avg_ping = arr_acc.reduce(func(acc, num): return acc+num) / arr_acc.size()
	ping_label.text = "PING: %3dms\nAVG: %3dms" % [int(roundtrip_time), int(avg_ping)]
	timer.start()