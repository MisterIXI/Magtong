extends SceneTree
## Headless tests for the rollback netcode. Run with:
## godot --headless --path . -s res://tests/rollback_test.gd

const SEED: int = 4242
const DELAY: int = 2

var failures: int = 0
var settings: PlayerSettings = load("res://resources/player_settings.tres")
var rink := RinkOutline.new()

func _init():
	test_snapshot_bytes()
	test_local_only()
	test_perfect_network()
	test_bad_network()
	test_bad_network_three_peers()
	test_stall_and_recover()
	test_desync_recovery()
	rink.free()
	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
	print(("PASS " if cond else "FAIL ") + msg)

#region helpers
## [Simulation, SimState] of a match, identical every time for the same player count
func make_match(player_count: int) -> Array:
	var sim := Simulation.new(settings, Simulation.Mode.MATCH)
	var state := SimState.new()
	state.rng = SEED
	sim.set_rink(rink, Transform2D.IDENTITY, true)
	sim.match_length_ticks = 180 * Simulation.TICK_RATE
	sim.puck_spawns = PackedVector2Array([Vector2(0, 0), Vector2(0, -86), Vector2(0, 83)])
	sim.player_spawn_groups = [
		PackedVector2Array([Vector2(-350, 0), Vector2(350, 0)]),
		PackedVector2Array([Vector2(-480, -240), Vector2(480, 240)]),
	]
	sim.add_puck(state, Vector2.ZERO)
	for p in player_count:
		sim.add_player(state, Vector2.ZERO, 1 + p % 2, p / 2)
	sim.start_match(state)
	return [sim, state]

## the "true" input of a player for a tick, changes every few ticks like a human would
func script_input(player: int, tick: int) -> int:
	if tick <= DELAY:
		return SimInput.EMPTY
	var h := hash(Vector2i(tick / 9, player * 7919))
	var move := Vector2(((h & 0xFF) - 128) / 128.0, (((h >> 8) & 0xFF) - 128) / 128.0)
	var buttons := (h >> 16) & (SimInput.PLUS | SimInput.MINUS | SimInput.PRIMARY | SimInput.SECONDARY)
	return SimInput.encode(move, buttons)

## checksum of a straight simulation (no rollback) with the true inputs after the given tick
func reference_checksum(player_count: int, to_tick: int) -> int:
	var m := make_match(player_count)
	var sim: Simulation = m[0]
	var state: SimState = m[1]
	for t in range(1, to_tick + 1):
		var inputs := PackedInt32Array()
		for p in player_count:
			inputs.append(script_input(p, t))
		sim.step(state, inputs)
	return state.checksum()

func make_harness(owners: PackedInt32Array, peer_count: int) -> LocalNetHarness:
	var pairs := []
	for peer in peer_count:
		pairs.append(make_match(owners.size()))
	return LocalNetHarness.new(pairs, owners, DELAY, SEED)

func run(harness: LocalNetHarness, from_frame: int, to_frame: int, on_frame: Callable = Callable()) -> void:
	for frame in range(from_frame, to_frame):
		if on_frame.is_valid():
			on_frame.call(frame)
		harness.tick(script_input, frame * 1000 / Simulation.TICK_RATE)

## all peers end up on the exact same state as the reference simulation
func check_matches_reference(harness: LocalNetHarness, player_count: int, label: String) -> void:
	var final_tick := 1 << 30
	for s in harness.sessions:
		final_tick = mini(final_tick, mini(s.get_confirmed_tick(), s.current_tick))
	var expected := reference_checksum(player_count, final_tick)
	var all_match := true
	for s in harness.sessions:
		var after := s._state_after(final_tick)
		if after == null or after.checksum() != expected:
			all_match = false
	check(all_match and final_tick > 0, "%s: every peer matches the reference simulation at tick %d" % [label, final_tick])

func stats(harness: LocalNetHarness) -> String:
	var parts := []
	for s in harness.sessions:
		parts.append("peer %d: tick %d, %d rollbacks (max depth %d), %d stalls, %d desyncs" % [
			s.local_peer, s.current_tick, s.rollbacks, s.max_rollback_depth, s.stalls, s.desyncs])
	return ", ".join(parts)
#endregion

func test_snapshot_bytes():
	var m := make_match(2)
	m[0].step(m[1], PackedInt32Array([script_input(0, 5), script_input(1, 5)]))
	var restored := SimState.from_bytes(m[1].to_bytes())
	check(restored.checksum() == m[1].checksum(), "state survives the bytes round trip")

func test_local_only():
	var m := make_match(2)
	var session := RollbackSession.new(m[0], m[1], 0, PackedInt32Array([0, 0]), DELAY)
	for frame in 600:
		for p in 2:
			session.add_local_input(p, script_input(p, session.current_tick + 1 + DELAY))
		session.advance()
	check(session.state.checksum() == reference_checksum(2, session.current_tick), "local only session equals the plain simulation")
	check(session.rollbacks == 0 and session.stalls == 0, "local only session never rolls back")

func test_perfect_network():
	var harness := make_harness(PackedInt32Array([0, 1]), 2)
	run(harness, 0, 900)
	check_matches_reference(harness, 2, "zero ping")
	var rollbacks := 0
	for s in harness.sessions:
		rollbacks += s.rollbacks
	check(rollbacks == 0, "zero ping with input delay needs no rollbacks (%s)" % stats(harness))

func test_bad_network():
	var harness := make_harness(PackedInt32Array([0, 1, 0, 1]), 2)
	harness.network.ping_ms = 140
	harness.network.jitter_ms = 30
	harness.network.loss = 0.15
	run(harness, 0, 1800)
	check_matches_reference(harness, 4, "2v2, 140 ms ping, 30 ms jitter, 15% loss")
	var s0 := harness.sessions[0]
	check(s0.rollbacks > 0, "bad network causes rollbacks (%s)" % stats(harness))
	check(s0.desyncs == 0 and harness.sessions[1].desyncs == 0, "no desyncs on a bad network")
	check(s0.get_ping(1) >= 140 and s0.get_ping(1) < 140 + 2 * 30 + 40, "measured ping is plausible (%d ms)" % s0.get_ping(1))

func test_bad_network_three_peers():
	var harness := make_harness(PackedInt32Array([0, 1, 2, 2]), 3)
	harness.network.ping_ms = 100
	harness.network.jitter_ms = 40
	harness.network.loss = 0.1
	run(harness, 0, 1200)
	check_matches_reference(harness, 4, "3 peers (one with 2 local players), 100 ms ping")

func test_stall_and_recover():
	var harness := make_harness(PackedInt32Array([0, 1]), 2)
	harness.network.ping_ms = 60
	var max_lead := [0]
	run(harness, 0, 600, func(frame):
		# the connection drops completely for 2 seconds
		harness.network.loss = 1.0 if frame >= 200 and frame < 320 else 0.0
		for s in harness.sessions:
			var lead := s.current_tick - s.get_confirmed_tick()
			max_lead[0] = maxi(max_lead[0], lead))
	var s0 := harness.sessions[0]
	check(s0.stalls > 0, "peers stall when the connection drops (%s)" % stats(harness))
	check(max_lead[0] <= RollbackSession.MAX_ROLLBACK, "never predicts further than MAX_ROLLBACK ahead (max %d)" % max_lead[0])
	check_matches_reference(harness, 2, "after a 2 second connection drop")

func test_desync_recovery():
	var harness := make_harness(PackedInt32Array([0, 1]), 2)
	run(harness, 0, 900, func(frame):
		# something goes wrong on peer 1 (e.g. a float difference): its puck ends up somewhere else
		if frame == 300:
			harness.sessions[1].state.pos[0] += Vector2(5, 0))
	var s0 := harness.sessions[0]
	var s1 := harness.sessions[1]
	check(s0.desyncs > 0 or s1.desyncs > 0, "desync is detected (%s)" % stats(harness))
	check(s0.snapshots_sent > 0 and s1.snapshots_applied > 0, "authority sends a snapshot and the other peer applies it")
	check_matches_reference(harness, 2, "after desync recovery")
