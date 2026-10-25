class_name NetTransport
extends RefCounted
## Raw packets over a Godot MultiplayerPeer (ENetMultiplayerPeer for direct connections,
## SteamMultiplayerPeer for Steam). No SceneMultiplayer and no RPCs: the peer is polled here and
## packets are plain bytes. The host has peer id 1, clients only talk to the host.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

const HOST_ID: int = 1

var peer: MultiplayerPeer
var _was_connected: bool = false

func _init(peer: MultiplayerPeer) -> void:
	self.peer = peer
	peer.peer_connected.connect(func(id): peer_connected.emit(id))
	peer.peer_disconnected.connect(func(id): peer_disconnected.emit(id))

func get_unique_id() -> int:
	return peer.get_unique_id()

func is_host() -> bool:
	return get_unique_id() == HOST_ID

func is_connected_to_host() -> bool:
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

## True while a client is still trying to reach the host.
func is_connecting() -> bool:
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING

## Polls the peer and returns the received packets as [from_peer_id, bytes].
func poll() -> Array:
	peer.poll()
	var packets := []
	while peer.get_available_packet_count() > 0:
		var from := peer.get_packet_peer()
		var bytes := peer.get_packet()
		packets.append([from, bytes])
	return packets

## to: peer id, or 0 for everybody this peer is connected to (a client is only connected to the host).
func send(to: int, bytes: PackedByteArray, reliable: bool) -> void:
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	peer.set_target_peer(to)
	peer.put_packet(bytes)

func close() -> void:
	peer.close()
