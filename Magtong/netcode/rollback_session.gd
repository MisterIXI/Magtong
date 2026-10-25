class_name RollbackSession
extends RefCounted
## Rollback netcode core for one peer. Runs the Simulation with the inputs of all players: local inputs
## are known right away (delayed by input_delay ticks), remote inputs are predicted (last known input
## repeated) until they arrive. When an arrived input differs from the prediction, the state of that tick
## is restored and the simulation is run again up to the current tick.
## No engine or network code in here: packets are plain Dictionaries, time is passed in.

const MAX_ROLLBACK: int = 16 # max ticks we simulate ahead of a remote player's confirmed input
const HISTORY: int = MAX_ROLLBACK * 4 # how many ticks of states and inputs are kept
const CHECKSUM_INTERVAL: int = 10
const CHECKSUMS_PER_PACKET: int = 8
const MAX_INPUT_TICKS_PER_PACKET: int = MAX_ROLLBACK * 2
const SNAPSHOT_COOLDOWN: int = 60

var sim: Simulation
var state: SimState
var local_peer: int
var player_owner: PackedInt32Array # peer id per player
var local_players: PackedInt32Array = PackedInt32Array()
var input_delay: int
var current_tick: int

# per tick bookkeeping, keyed by tick
var _inputs: Dictionary = {} # tick -> PackedInt32Array, input per player
var _known: Dictionary = {} # tick -> PackedByteArray, 1 if the input of that player is confirmed
var _used: Dictionary = {} # tick -> PackedInt32Array, inputs the tick was last simulated with
var _states: Dictionary = {} # tick -> SimState before that tick was simulated
var _confirmed_until: PackedInt32Array = PackedInt32Array() # per player: all inputs up to this tick are known
var _rollback_from: int = -1
var _pruned_until: int = 0

# remote peers: peer id -> info dictionary
var _peers: Dictionary = {}

# desync detection
var _local_checksums: Dictionary = {} # tick -> checksum of the state after that tick
var _last_checksummed: int = 0
var _ignore_checksums_until: int = -1
var _snapshot_pending: bool = false
var _snapshot_requested: bool = false
var _snapshot_cooldown_until: int = 0
var _pending_snapshot: Dictionary = {} # snapshot for a tick we did not reach yet

# stats
var rollbacks: int = 0
var resimulated_ticks: int = 0
var max_rollback_depth: int = 0
var stalls: int = 0
var time_sync_waits: int = 0
var desyncs: int = 0
var snapshots_sent: int = 0
var snapshots_applied: int = 0
var last_desync_tick: int = -1

func _init(sim: Simulation, state: SimState, local_peer: int, player_owner: PackedInt32Array, input_delay: int = 2) -> void:
	self.sim = sim
	self.state = state
	self.local_peer = local_peer
	self.player_owner = player_owner
	self.input_delay = input_delay
	current_tick = state.tick
	_last_checksummed = current_tick
	_pruned_until = current_tick
	for p in player_owner.size():
		if player_owner[p] == local_peer:
			local_players.append(p)
		elif not _peers.has(player_owner[p]):
			_peers[player_owner[p]] = {
				"players": PackedInt32Array(),
				"ack": current_tick, # latest tick of our inputs the peer has without gaps
				"last_time": -1,
				"last_time_at": 0,
				"rtt": -1,
				"remote_tick": -1, # tick the peer was at when it sent its newest packet
				"remote_tick_at": 0,
				"checksums": {},
				"snapshot_applied": -1,
			}
		if player_owner[p] != local_peer:
			_peers[player_owner[p]]["players"].append(p)
	# the first input_delay ticks have no inputs from anybody
	for p in player_owner.size():
		_confirmed_until.append(current_tick + input_delay)
	for t in range(current_tick + 1, current_tick + input_delay + 1):
		_inputs[t] = _empty_inputs()
		_known[t] = _all_known()

func is_authority() -> bool:
	var lowest := local_peer
	for peer in _peers:
		lowest = mini(lowest, peer)
	return lowest == local_peer

func get_ping(peer: int) -> int:
	return _peers[peer]["rtt"] if _peers.has(peer) else -1

func get_remote_peers() -> Array:
	return _peers.keys()

## How many ticks we run ahead of the slowest remote peer, estimated from its newest packet and the ping.
## Positive means we are ahead and should slow down a little, so the predictions stay short.
func get_frame_advantage(now_ms: int) -> float:
	var advantage := 0.0
	var tick_ms := 1000.0 / Simulation.TICK_RATE
	for peer in _peers.values():
		if peer["remote_tick"] < 0 or peer["rtt"] < 0:
			continue
		var travel_ms: float = peer["rtt"] / 2.0 + (now_ms - peer["remote_tick_at"])
		var remote_now: float = peer["remote_tick"] + travel_ms / tick_ms
		advantage = maxf(advantage, current_tick - remote_now)
	return advantage

## The newest state that can not change anymore (all inputs up to it are known).
func get_confirmed_state() -> SimState:
	return _state_after(mini(get_confirmed_tick(), current_tick))

#region inputs
## Sets the input of a local player for the next tick to be scheduled (current tick + 1 + input_delay).
## Call once per local player right before advance().
func add_local_input(player: int, input: int) -> void:
	assert(player_owner[player] == local_peer, "Player %d is not local" % player)
	_set_input(current_tick + 1 + input_delay, player, input)

func _set_input(tick: int, player: int, input: int) -> void:
	if tick <= _pruned_until:
		return
	if not _inputs.has(tick):
		_inputs[tick] = _empty_inputs()
		_known[tick] = PackedByteArray()
		_known[tick].resize(player_owner.size())
	if _known[tick][player] == 1:
		return
	_inputs[tick][player] = input
	_known[tick][player] = 1
	while _is_known(_confirmed_until[player] + 1, player):
		_confirmed_until[player] += 1
	# already simulated with a different (predicted) input, so that tick has to be simulated again
	if tick <= current_tick and _used.has(tick) and _used[tick][player] != input:
		_rollback_from = tick if _rollback_from == -1 else mini(_rollback_from, tick)

func _is_known(tick: int, player: int) -> bool:
	return _known.has(tick) and _known[tick][player] == 1

func _input_for(tick: int, player: int) -> int:
	if _is_known(tick, player):
		return _inputs[tick][player]
	# prediction: the latest known input of that player
	for t in range(tick - 1, maxi(tick - HISTORY, _pruned_until), -1):
		if _is_known(t, player):
			return _inputs[t][player]
	return SimInput.EMPTY

func _inputs_for(tick: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for p in player_owner.size():
		result.append(_input_for(tick, p))
	return result

func _empty_inputs() -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(player_owner.size())
	return result

func _all_known() -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(player_owner.size())
	result.fill(1)
	return result

## Lowest tick up to which the inputs of every player are known. States up to here are final.
func get_confirmed_tick() -> int:
	var confirmed := current_tick + input_delay
	for p in player_owner.size():
		confirmed = mini(confirmed, _confirmed_until[p])
	return confirmed
#endregion

#region simulation
## False if a remote player is so far behind that we would have to predict too far ahead (stall).
func can_advance() -> bool:
	var next_tick := current_tick + 1
	for peer in _peers.values():
		for p in peer["players"]:
			if next_tick - _confirmed_until[p] > MAX_ROLLBACK:
				return false
	return true

## Re-simulates if inputs arrived that differ from the predictions. advance() does this as well,
## call it directly when stalling so corrections still show up.
func resolve_rollback() -> void:
	if _rollback_from == -1:
		return
	var from := _rollback_from
	_rollback_from = -1
	if from > current_tick:
		return
	if not _states.has(from):
		push_error("Rollback to tick %d not possible, state is not in the history anymore" % from)
		return
	state = _states[from].copy()
	for t in range(from, current_tick + 1):
		_states[t] = state.copy()
		var inputs := _inputs_for(t)
		_used[t] = inputs
		sim.step(state, inputs)
	var depth := current_tick - from + 1
	rollbacks += 1
	resimulated_ticks += depth
	max_rollback_depth = maxi(max_rollback_depth, depth)

## Simulates the next tick. Check can_advance() first, and add the local inputs before.
func advance() -> void:
	resolve_rollback()
	var t := current_tick + 1
	_states[t] = state.copy()
	var inputs := _inputs_for(t)
	_used[t] = inputs
	sim.step(state, inputs)
	current_tick = t
	if not _pending_snapshot.is_empty() and _pending_snapshot["tick"] == current_tick:
		_apply_snapshot(_pending_snapshot["tick"], _pending_snapshot["data"])
		_pending_snapshot = {}
	_record_checksums()
	_prune()

## State after the given tick, if it is still in the history.
func _state_after(tick: int) -> SimState:
	if tick == current_tick:
		return state
	return _states.get(tick + 1)

func _prune() -> void:
	var horizon := current_tick - HISTORY
	for t in range(_pruned_until + 1, horizon + 1):
		_inputs.erase(t)
		_known.erase(t)
		_used.erase(t)
		_states.erase(t)
		_local_checksums.erase(t)
		for peer in _peers.values():
			peer["checksums"].erase(t)
	_pruned_until = maxi(_pruned_until, horizon)
#endregion

#region desync detection
func _record_checksums() -> void:
	var final_tick := mini(get_confirmed_tick(), current_tick)
	for t in range(_last_checksummed + 1, final_tick + 1):
		if t % CHECKSUM_INTERVAL != 0:
			continue
		var s := _state_after(t)
		if s == null:
			continue
		_local_checksums[t] = s.checksum()
		for peer_id in _peers:
			_compare_checksum(peer_id, t)
	_last_checksummed = maxi(_last_checksummed, final_tick)

func _compare_checksum(peer_id: int, tick: int) -> void:
	var peer: Dictionary = _peers[peer_id]
	if not _local_checksums.has(tick) or not peer["checksums"].has(tick):
		return
	if tick <= _ignore_checksums_until or tick <= peer["snapshot_applied"]:
		return
	if _local_checksums[tick] != peer["checksums"][tick]:
		desyncs += 1
		last_desync_tick = tick
		if is_authority():
			_snapshot_pending = true
		else:
			_snapshot_requested = true

func _apply_snapshot(tick: int, data: PackedByteArray) -> void:
	if tick > current_tick:
		# we are behind the authority, apply it once we get there
		_pending_snapshot = {"tick": tick, "data": data}
		return
	var snapshot := SimState.from_bytes(data)
	if tick == current_tick:
		state = snapshot
	else:
		_states[tick + 1] = snapshot
		_rollback_from = tick + 1
		resolve_rollback()
	# checksums from before the snapshot were made from the broken state
	for t in _local_checksums.keys():
		if t > tick:
			_local_checksums.erase(t)
	_last_checksummed = mini(_last_checksummed, tick)
	_ignore_checksums_until = tick
	_snapshot_requested = false
	snapshots_applied += 1
#endregion

#region packets
## Packet for all remote peers: our inputs they might not have yet, checksums, acks and snapshots.
func make_packet(now_ms: int) -> Dictionary:
	var newest := current_tick + input_delay
	var oldest := newest
	for peer in _peers.values():
		oldest = mini(oldest, peer["ack"])
	var start := maxi(oldest + 1, newest - MAX_INPUT_TICKS_PER_PACKET + 1)
	start = maxi(start, _pruned_until + 1)
	var inputs := PackedInt32Array()
	for t in range(start, newest + 1):
		for p in local_players:
			inputs.append(_input_for(t, p))
	var checksums := PackedInt64Array()
	var checksum_ticks := _local_checksums.keys()
	checksum_ticks.sort()
	for t in checksum_ticks.slice(-CHECKSUMS_PER_PACKET):
		checksums.append(t)
		checksums.append(_local_checksums[t])
	var acks := {}
	var echoes := {}
	for peer_id in _peers:
		var peer: Dictionary = _peers[peer_id]
		var ack := newest
		for p in peer["players"]:
			ack = mini(ack, _confirmed_until[p])
		acks[peer_id] = ack
		if peer["last_time"] >= 0:
			echoes[peer_id] = peer["last_time"] + (now_ms - peer["last_time_at"])
	var packet := {
		"peer": local_peer,
		"time": now_ms,
		"tick": current_tick,
		"echoes": echoes,
		"acks": acks,
		"players": local_players,
		"start": start,
		"count": newest - start + 1,
		"inputs": inputs,
		"checksums": checksums,
		"snapshot_request": _snapshot_requested,
		"snapshot_applied": _ignore_checksums_until,
	}
	if _snapshot_pending and is_authority() and current_tick >= _snapshot_cooldown_until:
		var final_tick := mini(get_confirmed_tick(), current_tick)
		var s := _state_after(final_tick)
		if s != null:
			packet["snapshot"] = {"tick": final_tick, "data": s.to_bytes()}
			_snapshot_pending = false
			_snapshot_cooldown_until = current_tick + SNAPSHOT_COOLDOWN
			snapshots_sent += 1
	return packet

func receive_packet(packet: Dictionary, now_ms: int) -> void:
	var peer_id: int = packet["peer"]
	if not _peers.has(peer_id):
		return
	var peer: Dictionary = _peers[peer_id]
	peer["ack"] = maxi(peer["ack"], packet["acks"].get(local_peer, peer["ack"]))
	if packet["echoes"].has(local_peer):
		peer["rtt"] = now_ms - packet["echoes"][local_peer]
	if packet["time"] > peer["last_time"]:
		peer["last_time"] = packet["time"]
		peer["last_time_at"] = now_ms
	if packet["tick"] > peer["remote_tick"]:
		peer["remote_tick"] = packet["tick"]
		peer["remote_tick_at"] = now_ms
	peer["snapshot_applied"] = maxi(peer["snapshot_applied"], packet["snapshot_applied"])
	var players: PackedInt32Array = packet["players"]
	var inputs: PackedInt32Array = packet["inputs"]
	for i in packet["count"]:
		for j in players.size():
			var p := players[j]
			if player_owner[p] == peer_id:
				_set_input(packet["start"] + i, p, inputs[i * players.size() + j])
	var checksums: PackedInt64Array = packet["checksums"]
	for i in range(0, checksums.size(), 2):
		var tick := checksums[i]
		if tick > _pruned_until:
			peer["checksums"][tick] = checksums[i + 1]
			_compare_checksum(peer_id, tick)
	if packet["snapshot_request"] and is_authority():
		_snapshot_pending = true
	if packet.has("snapshot") and not is_authority():
		_apply_snapshot(packet["snapshot"]["tick"], packet["snapshot"]["data"])
#endregion
