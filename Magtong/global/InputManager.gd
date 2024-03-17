extends Node

var players

func _input(event: InputEvent) -> void:
	pass
	print(event.as_text())
	print("event: " + str(event))
	print("device: " + str(event.device))
	# check 


@rpc("any_peer", "call_local", "reliable")
func send_input(player_id: int, event: InputEvent) -> void:
	pass