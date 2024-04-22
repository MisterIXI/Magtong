extends Node

@export var timer: Timer
var ping_time: int  = 0

func _ready():
	timer.start()

func on_timeout():
	if multiplayer.is_server():
		ping_time = Time.get_ticks_usec()
		ping_start.rpc()

@rpc("any_peer", "call_remote", "reliable")
func ping_start():
	ping_receive.rpc_id(1)

@rpc("any_peer","call_remote", "reliable")
func ping_receive():
	var roundtrip_time = Time.get_ticks_usec() - ping_time
	# convert to milliseconds
	roundtrip_time /= 1000
	globGameManager.send_message.rpc("Ping with " + str(multiplayer.get_remote_sender_id()) + " took " + str(roundtrip_time) + " ms.")
	timer.start()