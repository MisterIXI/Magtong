extends SceneTree
## Headless tests for the simulation. Run with:
## godot --headless --path . -s res://tests/sim_test.gd

var failures: int = 0
var settings: PlayerSettings = load("res://resources/player_settings.tres")

func _init():
	test_determinism()
	test_rollback_replay()
	test_containment()
	test_goal_right()
	test_goal_left()
	test_divider()
	test_lobby_zones()
	test_input_encoding()
	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
	print(("PASS " if cond else "FAIL ") + msg)

#region helpers
func make_rink() -> RinkOutline:
	var rink := RinkOutline.new()
	return rink

func make_match(rink: RinkOutline) -> Array:
	var sim := Simulation.new(settings, Simulation.Mode.MATCH)
	var state := SimState.new()
	state.rng = 12345
	sim.set_rink(rink, Transform2D.IDENTITY, true)
	sim.match_length_ticks = 180 * Simulation.TICK_RATE
	sim.puck_spawns = PackedVector2Array([Vector2(0, 0), Vector2(0, -86), Vector2(0, 83)])
	sim.player_spawn_groups = [
		PackedVector2Array([Vector2(-350, 0), Vector2(350, 0)]),
		PackedVector2Array([Vector2(-480, -240), Vector2(480, 240)]),
	]
	sim.add_puck(state, Vector2.ZERO)
	sim.add_player(state, Vector2.ZERO, 1, 0)
	sim.add_player(state, Vector2.ZERO, 2, 0)
	sim.add_player(state, Vector2.ZERO, 1, 1)
	sim.add_player(state, Vector2.ZERO, 2, 1)
	sim.start_match(state)
	return [sim, state]

## deterministic pseudo random inputs for player p at tick t
func fake_input(t: int, p: int) -> int:
	var h := hash(Vector2i(t / 7, p))
	var move := Vector2(((h & 0xFF) - 128) / 128.0, (((h >> 8) & 0xFF) - 128) / 128.0)
	var buttons := (h >> 16) & (SimInput.PLUS | SimInput.MINUS | SimInput.PRIMARY | SimInput.SECONDARY)
	return SimInput.encode(move, buttons)

func inputs_for(t: int, count: int) -> PackedInt32Array:
	var inputs := PackedInt32Array()
	for p in count:
		inputs.append(fake_input(t, p))
	return inputs

func run(sim: Simulation, state: SimState, from_tick: int, to_tick: int) -> void:
	for t in range(from_tick, to_tick):
		sim.step(state, inputs_for(t, sim.player_count))

func inside_rink(rink: RinkOutline, p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, rink.build_outline())
#endregion

func test_determinism():
	var rink := make_rink()
	var a: Array = make_match(rink)
	var b: Array = make_match(rink)
	run(a[0], a[1], 0, 3000)
	run(b[0], b[1], 0, 3000)
	check(a[1].checksum() == b[1].checksum(), "same inputs give the same state after 3000 ticks")
	check(a[1].tick == 3000, "tick counter advanced")
	rink.free()

func test_rollback_replay():
	var rink := make_rink()
	var a: Array = make_match(rink)
	var sim: Simulation = a[0]
	var state: SimState = a[1]
	run(sim, state, 0, 1000)
	var saved := state.copy()
	run(sim, state, 1000, 2000)
	var expected := state.checksum()
	# going back and replaying the same inputs must end up in the exact same state
	run(sim, saved, 1000, 2000)
	check(saved.checksum() == expected, "restoring a saved state and replaying gives the same state")
	# and the saved copy must not share data with the live state
	var c := state.copy()
	c.pos[0] = Vector2(9999, 9999)
	check(state.pos[0] != Vector2(9999, 9999), "state copies are independent")
	rink.free()

func test_containment():
	var rink := make_rink()
	var sim := Simulation.new(settings, Simulation.Mode.LOBBY)
	var state := SimState.new()
	sim.set_rink(rink, Transform2D.IDENTITY, false)
	for i in 6:
		sim.add_puck(state, Vector2(-200 + i * 80, (i % 3 - 1) * 100))
	sim.add_player(state, Vector2(0, 200))
	var escaped := 0
	for t in 6000:
		# every half second, fire all pucks in a new direction at max speed
		if t % 30 == 0:
			for k in sim.puck_count:
				var angle := float(hash(Vector2i(t, k)) % 6283) / 1000.0
				state.vel[k] = Vector2.from_angle(angle) * settings.max_speed
		sim.step(state, PackedInt32Array([fake_input(t, 0)]))
		for b in sim.puck_count + sim.player_count:
			if not inside_rink(rink, state.pos[b]):
				escaped += 1
	check(escaped == 0, "no body left the rink in 6000 ticks of max speed shots (escapes: %d)" % escaped)
	rink.free()

func shoot_puck_at_goal(dir: float) -> SimState:
	var rink := make_rink()
	var a: Array = make_match(rink)
	var sim: Simulation = a[0]
	var state: SimState = a[1]
	# skip the countdown, then park the players out of the way and shoot
	for t in Simulation.COUNTDOWN_TICKS + 1:
		sim.step(state, PackedInt32Array())
	for i in sim.player_count:
		sim.teleport(state, sim.player_body(i), Vector2(-200 + i * 100, 230))
	state.pos[0] = Vector2(0, 0)
	state.vel[0] = Vector2(dir * 1500, 0)
	for t in 120:
		sim.step(state, PackedInt32Array())
	rink.free()
	return state

func test_goal_right():
	var state := shoot_puck_at_goal(1.0)
	check(state.scores[0] == 1 and state.scores[1] == 0, "puck in the right goal scores for team 1 (scores %s)" % state.scores)
	check(state.phase == Simulation.Phase.COUNTDOWN, "goal resets into the countdown")

func test_goal_left():
	var state := shoot_puck_at_goal(-1.0)
	check(state.scores[1] == 1 and state.scores[0] == 0, "puck in the left goal scores for team 2 (scores %s)" % state.scores)

func test_divider():
	var rink := make_rink()
	var a: Array = make_match(rink)
	var sim: Simulation = a[0]
	var state: SimState = a[1]
	for t in Simulation.COUNTDOWN_TICKS + 1:
		sim.step(state, PackedInt32Array())
	# team 1 player runs right into the center line for 3 seconds
	var right := SimInput.encode(Vector2.RIGHT, 0)
	var inputs := PackedInt32Array([right, 0, 0, 0])
	for i in sim.player_count:
		sim.teleport(state, sim.player_body(i), Vector2(-300 - i * 60, -150 + i * 100))
	for t in 180:
		sim.step(state, inputs)
	var player_x := state.pos[sim.player_body(0)].x
	check(player_x < 0.0, "player cannot cross the center line (x = %.1f)" % player_x)
	# the puck can
	state.pos[0] = Vector2(-100, 200)
	state.vel[0] = Vector2(800, 0)
	for t in 30:
		sim.step(state, PackedInt32Array())
	check(state.pos[0].x > 0.0, "puck passes the center line (x = %.1f)" % state.pos[0].x)
	rink.free()

func test_lobby_zones():
	var rink := make_rink()
	var sim := Simulation.new(settings, Simulation.Mode.LOBBY)
	var state := SimState.new()
	sim.set_rink(rink, Transform2D.IDENTITY, false)
	sim.add_team_area(Rect2(Vector2(-130, 225), Vector2(260, 60)), 0)
	sim.add_team_area(Rect2(Vector2(-538, -125), Vector2(145, 250)), 1)
	sim.add_puck(state, Vector2.ZERO)
	sim.add_player(state, Vector2(-300, 0))
	sim.step(state, PackedInt32Array())
	check(state.zone[0] == -1, "player outside the areas has no zone")
	var left := SimInput.encode(Vector2.LEFT, 0)
	for t in 60:
		sim.step(state, PackedInt32Array([left]))
	check(state.zone[0] == 1, "walking into the team 1 area sets the zone (zone %d)" % state.zone[0])
	rink.free()

func test_input_encoding():
	var input := SimInput.encode(Vector2(-1, 0.5), SimInput.PLUS | SimInput.MENU)
	var move := SimInput.get_move(input)
	check(is_equal_approx(move.x, -1.0) and absf(move.y - 0.5) < 0.01, "move survives encoding (%s)" % move)
	check(SimInput.get_buttons(input) == SimInput.PLUS | SimInput.MENU, "buttons survive encoding")
