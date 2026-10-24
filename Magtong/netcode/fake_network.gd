class_name FakeNetwork
extends RefCounted
## In-process network with configurable ping, jitter and packet loss, for testing rollback without a
## real connection. Packets are serialized to bytes on send, like a real transport would, so the peers
## never share data by reference.

var ping_ms: int = 0 # round trip, every packet takes half of it one way
var jitter_ms: int = 0 # random extra one-way delay of 0..jitter_ms
var loss: float = 0.0 # 0..1 chance a packet is dropped
var keep_order: bool = false # if true, packets of one connection never overtake each other

var packets_sent: int = 0
var packets_lost: int = 0

var _rng := RandomNumberGenerator.new()
var _queue: Array[Dictionary] = [] # {deliver_at, to, from, bytes}
var _last_delivery: Dictionary = {} # Vector2i(from, to) -> latest deliver_at, for keep_order

func _init(seed: int = 0) -> void:
	_rng.seed = seed

func send(from: int, to: int, packet: Dictionary, now_ms: int) -> void:
	packets_sent += 1
	if loss > 0.0 and _rng.randf() < loss:
		packets_lost += 1
		return
	var deliver_at := now_ms + ping_ms / 2
	if jitter_ms > 0:
		deliver_at += _rng.randi_range(0, jitter_ms)
	if keep_order:
		var key := Vector2i(from, to)
		deliver_at = maxi(deliver_at, _last_delivery.get(key, 0))
		_last_delivery[key] = deliver_at
	_queue.append({"deliver_at": deliver_at, "to": to, "from": from, "bytes": var_to_bytes(packet)})

## Packets for that peer that arrived by now.
func receive(to: int, now_ms: int) -> Array[Dictionary]:
	var arrived: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for entry in _queue:
		if entry["to"] == to and entry["deliver_at"] <= now_ms:
			arrived.append(entry)
		else:
			remaining.append(entry)
	_queue = remaining
	arrived.sort_custom(func(a, b): return a["deliver_at"] < b["deliver_at"])
	var packets: Array[Dictionary] = []
	for entry in arrived:
		packets.append(bytes_to_var(entry["bytes"]))
	return packets
