class_name LocalNetHarness
extends RefCounted
## Runs several RollbackSessions in one process, connected through a FakeNetwork.
## Every session has its own Simulation and SimState, built the same way (same seed), so this behaves
## like separate machines playing together.

var network: FakeNetwork
var sessions: Array[RollbackSession] = [] # index = peer id

## sims_and_states: one [Simulation, SimState] pair per peer, all set up identically.
func _init(sims_and_states: Array, player_owner: PackedInt32Array, input_delay: int, seed: int = 0) -> void:
	network = FakeNetwork.new(seed)
	for peer in sims_and_states.size():
		sessions.append(RollbackSession.new(sims_and_states[peer][0], sims_and_states[peer][1], peer, player_owner, input_delay))

## One frame for every peer. input_for(player: int, target_tick: int) -> int returns the input of a
## local player for the tick it gets scheduled for.
## Peers in skip do not simulate this frame (they still send and receive), e.g. a machine that started late.
func tick(input_for: Callable, now_ms: int, skip: Array = []) -> void:
	for peer in sessions.size():
		var session := sessions[peer]
		for packet in network.receive(peer, now_ms):
			session.receive_packet(packet, now_ms)
		if peer in skip:
			session.resolve_rollback()
		elif session.can_advance():
			var target_tick := session.current_tick + 1 + session.input_delay
			for p in session.local_players:
				session.add_local_input(p, input_for.call(p, target_tick))
			session.advance()
		else:
			session.stalls += 1
			session.resolve_rollback()
		var packet := session.make_packet(now_ms)
		for other in sessions.size():
			if other != peer:
				network.send(peer, other, packet, now_ms)
