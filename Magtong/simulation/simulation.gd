class_name Simulation
extends RefCounted
## Tick based game simulation. step() is the only place gameplay happens: it reads the inputs of one
## tick and advances a SimState. It must stay deterministic (same state + same inputs = same result),
## so no engine physics, no Timers, no randi(), no delta from the engine, and fixed iteration orders.
## This class only holds static data (geometry, body sizes, spawns), everything that changes is in SimState.

enum Mode { SANDBOX, LOBBY, MATCH }
enum Phase { NONE, COUNTDOWN, PLAYING, GAME_OVER }
enum Polarity { IDLE, POS, NEG }

const TICK_RATE: int = 60
const DT: float = 1.0 / TICK_RATE
const SUBSTEPS: int = 4
const COUNTDOWN_TICKS: int = 3 * TICK_RATE
const FALLOFF_SAMPLES: int = 256

var settings: PlayerSettings
var mode: Mode

# static geometry (line segments)
var seg_a: PackedVector2Array = PackedVector2Array()
var seg_b: PackedVector2Array = PackedVector2Array()
var seg_normal: PackedVector2Array = PackedVector2Array() # inward normal of one sided walls, ZERO for two sided
var seg_players_only: PackedByteArray = PackedByteArray()
var goal_center: Vector2 = Vector2.ZERO
var goal_line_dist: float = INF # distance of the goal lines from goal_center, INF = no goals
var goal_half_width: float = 0.0

# lobby team areas
var team_areas: Array[Rect2] = []
var team_area_team: PackedInt32Array = PackedInt32Array()

# bodies: pucks first, then players
var puck_count: int = 0
var player_count: int = 0
var radius: PackedFloat32Array = PackedFloat32Array()
var inv_mass: PackedFloat32Array = PackedFloat32Array()
var player_team: PackedInt32Array = PackedInt32Array() # 1 or 2 in matches, 0 otherwise
var player_team_slot: PackedInt32Array = PackedInt32Array() # index of the player within its team

# spawns
var puck_spawns: PackedVector2Array = PackedVector2Array()
var player_spawn_groups: Array[PackedVector2Array] = [] # [group][team - 1]
var match_length_ticks: int = 0

var pulse_cd_ticks: int
var ability_cd_ticks: int
var falloff: PackedFloat32Array = PackedFloat32Array()

func _init(settings: PlayerSettings, mode: Mode = Mode.SANDBOX) -> void:
	self.settings = settings
	self.mode = mode
	pulse_cd_ticks = roundi(settings.pulse_cooldown * TICK_RATE)
	ability_cd_ticks = roundi(settings.impulse_cooldown * TICK_RATE)
	# bake the curve, so the simulation only does plain arithmetic on fixed values
	falloff.resize(FALLOFF_SAMPLES)
	for i in FALLOFF_SAMPLES:
		falloff[i] = settings.magnet_dropoff.sample(float(i) / (FALLOFF_SAMPLES - 1))

#region setup
## to_sim: transform from the rink node into simulation space (only translation is supported for goals)
func set_rink(rink: RinkOutline, to_sim: Transform2D, use_divider: bool) -> void:
	var outline := rink.build_outline()
	for i in outline.size():
		_add_segment(to_sim * outline[i], to_sim * outline[(i + 1) % outline.size()], true, false)
	if use_divider and rink.has_divider:
		var divider := rink.get_divider()
		_add_segment(to_sim * divider[0], to_sim * divider[1], false, true)
	goal_center = to_sim.origin.snapped(Vector2(RinkOutline.SNAP, RinkOutline.SNAP))
	goal_line_dist = rink.get_goal_line_x()
	goal_half_width = rink.goal_half_width

func _add_segment(a: Vector2, b: Vector2, one_sided: bool, players_only: bool) -> void:
	a = a.snapped(Vector2(RinkOutline.SNAP, RinkOutline.SNAP))
	b = b.snapped(Vector2(RinkOutline.SNAP, RinkOutline.SNAP))
	if a.is_equal_approx(b):
		return
	seg_a.append(a)
	seg_b.append(b)
	# outline runs clockwise on screen (y down), so the inside is to the right of the direction
	var d := (b - a).normalized()
	seg_normal.append(Vector2(-d.y, d.x) if one_sided else Vector2.ZERO)
	seg_players_only.append(1 if players_only else 0)

func add_team_area(rect: Rect2, team: int) -> void:
	team_areas.append(rect)
	team_area_team.append(team)

func add_puck(state: SimState, pos: Vector2, is_plus: bool = true) -> int:
	assert(player_count == 0, "Pucks have to be added before players")
	radius.append(settings.puck_radius)
	inv_mass.append(1.0 / settings.puck_mass)
	state.pos.append(pos)
	state.vel.append(Vector2.ZERO)
	state.puck_plus.append(1 if is_plus else 0)
	puck_count += 1
	return puck_count - 1

## Adds a player and returns its player index (body index is puck_count + player index).
func add_player(state: SimState, pos: Vector2, team: int = 0, team_slot: int = 0) -> int:
	radius.append(settings.player_radius)
	inv_mass.append(1.0 / settings.player_mass)
	player_team.append(team)
	player_team_slot.append(team_slot)
	state.pos.append(pos)
	state.vel.append(Vector2.ZERO)
	state.polarity.append(Polarity.IDLE)
	state.prev_buttons.append(0)
	state.pulse_cd.append(0)
	state.ability_cd.append(0)
	state.last_pulse_tick.append(-1)
	state.last_ability_tick.append(-1)
	state.zone.append(-1)
	player_count += 1
	return player_count - 1

func player_body(player_index: int) -> int:
	return puck_count + player_index

func teleport(state: SimState, body: int, pos: Vector2) -> void:
	state.pos[body] = pos
	state.vel[body] = Vector2.ZERO
	state.reset_tick = state.tick

func start_match(state: SimState) -> void:
	state.scores = PackedInt32Array([0, 0])
	state.winner = -1
	state.overtime = false
	state.overtime_ticks = 0
	state.match_ticks = match_length_ticks
	_reset_field(state)
	_start_countdown(state)
#endregion

#region step
func step(state: SimState, inputs: PackedInt32Array) -> void:
	state.tick += 1
	var controls_active := mode != Mode.MATCH or state.phase == Phase.PLAYING
	var menu_pressed := false
	for i in player_count:
		var body := puck_count + i
		var input: int = inputs[i] if i < inputs.size() else SimInput.EMPTY
		var buttons := SimInput.get_buttons(input)
		var pressed := buttons & ~state.prev_buttons[i]
		state.prev_buttons[i] = buttons
		if pressed & SimInput.MENU:
			menu_pressed = true
		if state.pulse_cd[i] > 0:
			state.pulse_cd[i] -= 1
		if state.ability_cd[i] > 0:
			state.ability_cd[i] -= 1
		var target_vel := Vector2.ZERO
		var pol := Polarity.IDLE
		if controls_active:
			target_vel = SimInput.get_move(input).limit_length(1.0) * settings.speed
			# plus has priority
			if buttons & SimInput.PLUS:
				pol = Polarity.POS
			elif buttons & SimInput.MINUS:
				pol = Polarity.NEG
		state.polarity[i] = pol
		state.vel[body] = state.vel[body].move_toward(target_vel, settings.accell * DT)
		if controls_active:
			if pressed & SimInput.PRIMARY and state.pulse_cd[i] == 0:
				_pulse(state, i)
			if pressed & SimInput.SECONDARY and state.ability_cd[i] == 0 and pol != Polarity.IDLE:
				_impulse(state, i)
	_apply_magnets(state)
	_integrate(state)
	match mode:
		Mode.LOBBY:
			_update_zones(state)
		Mode.MATCH:
			_step_match(state, menu_pressed)

func _apply_magnets(state: SimState) -> void:
	var pos := state.pos
	var vel := state.vel
	for i in player_count:
		var pol := state.polarity[i]
		if pol == Polarity.IDLE:
			continue
		var body := puck_count + i
		for k in puck_count:
			var diff := pos[k] - pos[body]
			var dist := diff.length()
			if dist <= 0.0:
				continue
			var force := _falloff(dist / settings.magnet_range) * settings.magnet_force
			var is_repelling := (state.puck_plus[k] == 1) == (pol == Polarity.POS)
			if not is_repelling:
				force = -force
			var dv := diff / dist * force * DT
			vel[k] += dv * inv_mass[k]
			if settings.magnet_recoil:
				vel[body] -= dv * inv_mass[body]
	state.vel = vel

func _pulse(state: SimState, player: int) -> void:
	var body := puck_count + player
	state.pulse_cd[player] = pulse_cd_ticks
	state.last_pulse_tick[player] = state.tick
	var range_sq := settings.pulse_range * settings.pulse_range
	for k in puck_count:
		if state.pos[k].distance_squared_to(state.pos[body]) < range_sq:
			state.puck_plus[k] = 1 - state.puck_plus[k]

func _impulse(state: SimState, player: int) -> void:
	var body := puck_count + player
	var pol := state.polarity[player]
	state.ability_cd[player] = ability_cd_ticks
	state.last_ability_tick[player] = state.tick
	for k in puck_count:
		var diff := state.pos[k] - state.pos[body]
		var dist := diff.length()
		if dist <= 0.0:
			continue
		var puck_pol := Polarity.POS if state.puck_plus[k] == 1 else Polarity.NEG
		var mult := 1.0 if puck_pol == pol else -1.0
		var force := _falloff(dist / settings.magnet_range) * settings.magnet_force * mult * settings.impulse_mult
		state.vel[k] += diff / dist * force * inv_mass[k]

func _falloff(x: float) -> float:
	if x <= 0.0:
		return falloff[0]
	if x >= 1.0:
		return falloff[FALLOFF_SAMPLES - 1]
	var f := x * (FALLOFF_SAMPLES - 1)
	var i := int(f)
	return lerpf(falloff[i], falloff[i + 1], f - i)
#endregion

#region physics
func _integrate(state: SimState) -> void:
	var pos := state.pos
	var vel := state.vel
	var body_count := puck_count + player_count
	var damp := maxf(0.0, 1.0 - settings.linear_damp * DT)
	for b in body_count:
		vel[b] = (vel[b] * damp).limit_length(settings.max_speed)
	var sub_dt := DT / SUBSTEPS
	for s in SUBSTEPS:
		for b in body_count:
			pos[b] += vel[b] * sub_dt
		_collide_bodies(pos, vel, body_count)
		# walls last, so they always win against body pushes
		_collide_walls(pos, vel, body_count)
	state.pos = pos
	state.vel = vel

func _collide_bodies(pos: PackedVector2Array, vel: PackedVector2Array, body_count: int) -> void:
	for i in body_count:
		for j in range(i + 1, body_count):
			var r := radius[i] + radius[j]
			var diff := pos[j] - pos[i]
			var dist_sq := diff.length_squared()
			if dist_sq >= r * r:
				continue
			var dist := sqrt(dist_sq)
			var normal := diff / dist if dist > 0.0 else Vector2.RIGHT
			var wi := inv_mass[i]
			var wj := inv_mass[j]
			var w := wi + wj
			# push apart by inverse mass
			var push := normal * ((r - dist) / w)
			pos[i] -= push * wi
			pos[j] += push * wj
			# bounce
			var vn := (vel[j] - vel[i]).dot(normal)
			if vn < 0.0:
				var impulse := normal * (-(1.0 + settings.body_bounce) * vn / w)
				vel[i] -= impulse * wi
				vel[j] += impulse * wj

func _collide_walls(pos: PackedVector2Array, vel: PackedVector2Array, body_count: int) -> void:
	for b in body_count:
		var is_player := b >= puck_count
		var r := radius[b]
		for s in seg_a.size():
			if seg_players_only[s] == 1 and not is_player:
				continue
			var a := seg_a[s]
			var ab := seg_b[s] - a
			var t := clampf((pos[b] - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var inward := seg_normal[s]
			var side := (pos[b] - a).dot(inward)
			var normal: Vector2
			var depth: float
			if inward != Vector2.ZERO and side < 0.0 and t > 0.0 and t < 1.0:
				# center ended up behind a one sided wall, push it back inside
				normal = inward
				depth = r - side
			else:
				var diff := pos[b] - (a + ab * t)
				var dist_sq := diff.length_squared()
				if dist_sq >= r * r:
					continue
				var dist := sqrt(dist_sq)
				if dist > 0.0:
					normal = diff / dist
				elif inward != Vector2.ZERO:
					normal = inward
				else:
					normal = Vector2(-ab.y, ab.x).normalized()
				depth = r - dist
			pos[b] += normal * depth
			var vn := vel[b].dot(normal)
			if vn < 0.0:
				vel[b] -= normal * vn * (1.0 + settings.wall_bounce)
#endregion

#region game modes
func _update_zones(state: SimState) -> void:
	for i in player_count:
		var body := puck_count + i
		var center := state.pos[body]
		var r := radius[body]
		var zone := -1
		for a in team_areas.size():
			var closest := center.clamp(team_areas[a].position, team_areas[a].end)
			if closest.distance_squared_to(center) < r * r:
				zone = team_area_team[a]
				break
		state.zone[i] = zone

func _step_match(state: SimState, menu_pressed: bool) -> void:
	match state.phase:
		Phase.COUNTDOWN:
			state.phase_ticks -= 1
			if state.phase_ticks <= 0:
				state.phase = Phase.PLAYING
		Phase.PLAYING:
			if state.overtime:
				state.overtime_ticks += 1
			else:
				state.match_ticks -= 1
			var goal_team := _check_goals(state)
			if goal_team != 0:
				state.scores[goal_team - 1] += 1
				state.last_goal_tick = state.tick
				state.last_goal_team = goal_team
				if state.overtime:
					_game_over(state, goal_team)
				else:
					_reset_field(state)
					_start_countdown(state)
			elif not state.overtime and state.match_ticks <= 0:
				var leader := _leading_team(state)
				if leader == 0:
					# tie, the next goal decides
					state.overtime = true
					state.overtime_ticks = 0
					_reset_field(state)
					_start_countdown(state)
				else:
					_game_over(state, leader)
		Phase.GAME_OVER:
			if menu_pressed:
				start_match(state)

## Returns the team that scored (the right goal counts for team 1, the left one for team 2), 0 if none.
func _check_goals(state: SimState) -> int:
	for k in puck_count:
		var p := state.pos[k] - goal_center
		if absf(p.y) >= goal_half_width:
			continue
		if p.x > goal_line_dist:
			return 1
		if p.x < -goal_line_dist:
			return 2
	return 0

func _leading_team(state: SimState) -> int:
	if state.scores[0] > state.scores[1]:
		return 1
	if state.scores[1] > state.scores[0]:
		return 2
	return 0

func _start_countdown(state: SimState) -> void:
	state.phase = Phase.COUNTDOWN
	state.phase_ticks = COUNTDOWN_TICKS

func _game_over(state: SimState, winner: int) -> void:
	state.phase = Phase.GAME_OVER
	state.winner = winner
	for b in puck_count + player_count:
		state.vel[b] = Vector2.ZERO

func _reset_field(state: SimState) -> void:
	if puck_spawns.size() > 0:
		var order := _shuffled_indices(state, puck_spawns.size())
		for k in puck_count:
			state.pos[k] = puck_spawns[order[k % order.size()]]
			state.vel[k] = Vector2.ZERO
			state.puck_plus[k] = 1
	if player_spawn_groups.size() > 0:
		var order := _shuffled_indices(state, player_spawn_groups.size())
		for i in player_count:
			var body := puck_count + i
			var group := player_spawn_groups[order[player_team_slot[i] % order.size()]]
			state.pos[body] = group[(player_team[i] - 1) % group.size()]
			state.vel[body] = Vector2.ZERO
			state.polarity[i] = Polarity.IDLE
	state.reset_tick = state.tick

func _shuffled_indices(state: SimState, count: int) -> PackedInt32Array:
	var order := PackedInt32Array()
	for i in count:
		order.append(i)
	for i in range(count - 1, 0, -1):
		var j := _next_random(state) % (i + 1)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	return order

## xorshift32, the generator state is part of SimState so rollbacks replay the same numbers
func _next_random(state: SimState) -> int:
	var x := state.rng
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	state.rng = x
	return x
#endregion
