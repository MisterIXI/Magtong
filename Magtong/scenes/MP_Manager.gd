extends Node


func host_game( port: int):
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port, 2)
	multiplayer.multiplayer_peer = peer
	peer.connect("peer_connected", self.on_peer_connected)
	peer.connect("peer_disconnected", self.on_peer_disconnected)
	print("Hosted game on port: ", port)

func join_game(address: String, port: int):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer

@rpc("any_peer", "call_remote", "reliable")
func print_on_remote(message: String):
	print("Printing: ", message)


func on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)

func on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)

func default_host()->void:
	host_game(12345)

func default_join()->void:
	join_game("localhost", 12345)

func call_rpc()->void:
	print_on_remote.rpc("Test")


func _on_rpc_button_pressed() -> void:
	pass # Replace with function body.
