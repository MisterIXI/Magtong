class_name Simulation
extends RefCounted
## Tick based game simulation. step() is the only place gameplay happens: it reads the inputs of one
## tick and advances a SimState. It must stay deterministic (same state + same inputs = same result),
## so no engine physics, no Timers, no randi(), no delta from the engine, and fixed iteration orders.
## This class only holds static data (geometry, body sizes, spawns), everything that changes is in SimState.

enum Mode { SANDBOX, LOBBY, MATCH }
enum Phase { NONE, COUNTDOWN, PLAYING, GAME_OVER, GOAL }
enum Polarity { IDLE, POS, NEG }

const TICK_RATE: int = 60
const DT: float = 1.0 / TICK_RATE
const SUBSTEPS: int = 4
const COUNTDOWN_TICKS: int = 3 * TICK_RATE
## Lobby: every team player holds both magnets this long to start the match
const START_HOLD_TICKS: int = TICK_RATE
## how fast a released magnet's start bar empties again, in ticks per tick
const START_HOLD_DRAIN: int = 3
const FALLOFF_SAMPLES: int = 256
## Goal celebration: the GOAL phase between a goal and the reset. The scoring puck leaves play, a shockwave
## knocks everything else away, the players drift without control. (Slow motion was tried and dropped
## 15.11: without control it only made the knockback look wrong.)
const GOAL_TICKS: int = 2 * TICK_RATE
const GOAL_PUSH_RANGE: float = 450.0
## speed a body right next to the goal gets, falling off linearly to 0 at GOAL_PUSH_RANGE
const GOAL_PUSH_SPEED: float = 1400.0

var settings: PlayerSettings
var mode: Mode

# static geometry (line segments)
var seg_a: PackedVector2Array = PackedVector2Array()
var seg_b: PackedVector2Array = PackedVector2Array()
var seg_normal: PackedVector2Array = PackedVector2Array() # inward normal of one sided walls, ZERO for two sided
var seg_players_only: PackedByteArray = PackedByteArray()
## 1 = no contact with this end point: it is a corner the rink bends around (like the steps of a rounded
## corner), there the neighbouring segment gives the right normal and the end point would give a sideways one
var seg_skip_a: PackedByteArray = PackedByteArray()
var seg_skip_b: PackedByteArray = PackedByteArray()
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
var skin_count: int = 1

var flip_cd_ticks: int
var surge_cd_ticks: int
var falloff: PackedFloat32Array = PackedFloat32Array()

func _init(settings: PlayerSettings, mode: Mode = Mode.SANDBOX) -> void:
	self.settings = settings
	self.mode = mode
	flip_cd_ticks = roundi(settings.flip_cooldown * TICK_RATE)
	surge_cd_ticks = roundi(settings.surge_cooldown * TICK_RATE)
	# bake the curve, so the simulation only does plain arithmetic on fixed values
	falloff.resize(FALLOFF_SAMPLES)
	for i in FALLOFF_SAMPLES:
		falloff[i] = settings.magnet_dropoff.sample(float(i) / (FALLOFF_SAMPLES - 1))

#region setup
## to_sim: transform from the rink node into simulation space (only translation is supported for goals)
func set_rink(rink: RinkOutline, to_sim: Transform2D, use_divider: bool) -> void:
	var outline := rink.build_outline()
	var first := seg_a.size()
	for i in outline.size():
		_add_segment(to_sim * outline[i], to_sim * outline[(i + 1) % outline.size()], true, false)
	_mark_inner_corners(first, seg_a.size())
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
	seg_skip_a.append(0)
	seg_skip_b.append(0)

## The outline is a closed clockwise chain (y down): where it turns clockwise, the corner bends around the
## inside like a bowl and the end points there never are the right contact. Only corners that stick out into
## the rink (goal posts) keep their end point contacts.
func _mark_inner_corners(first: int, end: int) -> void:
	var n := end - first
	for j in n:
		var i := first + j
		var next := first + (j + 1) % n
		if seg_b[i] != seg_a[next]:
			continue
		if (seg_b[i] - seg_a[i]).cross(seg_b[next] - seg_a[next]) > 0.0:
			seg_skip_b[i] = 1
			seg_skip_a[next] = 1

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
	state.puck_angle.append(0.0)
	state.puck_spin.append(0.0)
	state.puck_hit_tick.append(-1)
	state.puck_hit_speed.append(0.0)
	state.puck_hit_wall.append(0)
	state.puck_wall_touch_tick.append(-2)
	state.puck_body_touch_tick.append(-2)
	puck_count += 1
	return puck_count - 1

## Adds a player and returns its player index (body index is puck_count + player index).
func add_player(state: SimState, pos: Vector2, team: int = 0, team_slot: int = 0, skin: int = 0) -> int:
	radius.append(settings.player_radius)
	inv_mass.append(1.0 / settings.player_mass)
	player_team.append(team)
	player_team_slot.append(team_slot)
	state.pos.append(pos)
	state.vel.append(Vector2.ZERO)
	state.polarity.append(Polarity.IDLE)
	state.prev_buttons.append(0)
	state.flip_cd.append(0)
	state.surge_cd.append(0)
	state.last_flip_tick.append(-1)
	state.last_surge_tick.append(-1)
	state.zone.append(-1)
	state.skin.append(skin)
	state.start_hold_plus.append(0)
	state.start_hold_minus.append(0)
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
	var back_pressed := false
	for i in player_count:
		var body := puck_count + i
		var input: int = inputs[i] if i < inputs.size() else SimInput.EMPTY
		var buttons := SimInput.get_buttons(input)
		var pressed := buttons & ~state.prev_buttons[i]
		state.prev_buttons[i] = buttons
		if pressed & SimInput.MENU:
			menu_pressed = true
		if pressed & SimInput.BACK:
			back_pressed = true
		if mode == Mode.LOBBY:
			if pressed & SimInput.AUX_LEFT:
				state.skin[i] = posmod(state.skin[i] - 1, skin_count)
			if pressed & SimInput.AUX_RIGHT:
				state.skin[i] = posmod(state.skin[i] + 1, skin_count)
		if state.flip_cd[i] > 0:
			state.flip_cd[i] -= 1
		if state.surge_cd[i] > 0:
			state.surge_cd[i] -= 1
		var target_vel := Vector2.ZERO
		var pol := Polarity.IDLE
		if controls_active:
			target_vel = SimInput.get_move(input).limit_length(1.0) * settings.speed
			pol = _choose_polarity(buttons, pressed, state.polarity[i])
		state.polarity[i] = pol
		if state.phase != Phase.GOAL:
			state.vel[body] = state.vel[body].move_toward(target_vel, settings.accell * DT)
		if controls_active:
			if pressed & SimInput.FLIP and state.flip_cd[i] == 0:
				_flip(state, i)
			if pressed & SimInput.SURGE and state.surge_cd[i] == 0 and pol != Polarity.IDLE:
				_surge(state, i)
	var frozen := state.goal_puck if state.phase == Phase.GOAL else -1
	_apply_magnets(state, frozen)
	_integrate(state, frozen)
	match mode:
		Mode.LOBBY:
			_update_zones(state)
			_update_start_hold(state)
		Mode.MATCH:
			_step_match(state, menu_pressed, back_pressed)

## One magnet button gives its polarity. With both held the last pressed one wins, so switching doesn't need a
## release; pressed on the same tick (or held since before the controls were active) plus wins.
func _choose_polarity(buttons: int, pressed: int, previous: Polarity) -> Polarity:
	var plus := (buttons & SimInput.PLUS) != 0
	var minus := (buttons & SimInput.MINUS) != 0
	if plus and minus:
		if pressed & SimInput.PLUS:
			return Polarity.POS
		if pressed & SimInput.MINUS:
			return Polarity.NEG
		return previous if previous != Polarity.IDLE else Polarity.POS
	if plus:
		return Polarity.POS
	if minus:
		return Polarity.NEG
	return Polarity.IDLE

## frozen: a puck that is out of play (the scoring puck during the goal celebration), -1 = none
func _apply_magnets(state: SimState, frozen: int) -> void:
	var pos := state.pos
	var vel := state.vel
	for i in player_count:
		var pol := state.polarity[i]
		if pol == Polarity.IDLE:
			continue
		var body := puck_count + i
		for k in puck_count:
			if k == frozen:
				continue
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

func _flip(state: SimState, player: int) -> void:
	var body := puck_count + player
	state.flip_cd[player] = flip_cd_ticks
	state.last_flip_tick[player] = state.tick
	var range_sq := settings.flip_range * settings.flip_range
	for k in puck_count:
		if state.pos[k].distance_squared_to(state.pos[body]) < range_sq:
			state.puck_plus[k] = 1 - state.puck_plus[k]

func _surge(state: SimState, player: int) -> void:
	var body := puck_count + player
	var pol := state.polarity[player]
	state.surge_cd[player] = surge_cd_ticks
	state.last_surge_tick[player] = state.tick
	for k in puck_count:
		var diff := state.pos[k] - state.pos[body]
		var dist := diff.length()
		if dist <= 0.0:
			continue
		var puck_pol := Polarity.POS if state.puck_plus[k] == 1 else Polarity.NEG
		var mult := 1.0 if puck_pol == pol else -1.0
		var force := _falloff(dist / settings.magnet_range) * settings.magnet_force * mult * settings.surge_mult
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
func _integrate(state: SimState, frozen: int) -> void:
	var pos := state.pos
	var vel := state.vel
	var spin := state.puck_spin
	var body_count := puck_count + player_count
	var damp := maxf(0.0, 1.0 - settings.linear_damp * DT)
	for b in body_count:
		vel[b] = (vel[b] * damp).limit_length(settings.max_speed)
	var spin_damp := maxf(0.0, 1.0 - settings.puck_spin_damp * DT)
	for k in puck_count:
		spin[k] *= spin_damp
	if frozen != -1:
		vel[frozen] = Vector2.ZERO
	var sub_dt := DT / SUBSTEPS
	for s in SUBSTEPS:
		for b in body_count:
			pos[b] += vel[b] * sub_dt
		_collide_bodies(state, pos, vel, spin, body_count, frozen)
		# walls last, so they always win against body pushes
		_collide_walls(state, pos, vel, spin, body_count, frozen)
	var angle := state.puck_angle
	for k in puck_count:
		angle[k] = wrapf(angle[k] + spin[k] * DT, -PI, PI)
	state.pos = pos
	state.vel = vel
	state.puck_spin = spin
	state.puck_angle = angle

## Remembers the strongest new puck contact of this tick for the views. A contact that already existed in the
## previous tick (pushing a puck, sliding along a wall) is not a hit. Never changes the physics.
func _record_hit(state: SimState, puck: int, speed: float, is_wall: bool) -> void:
	if state.puck_hit_tick[puck] == state.tick:
		# an earlier substep of this tick already started a contact, keep the strongest
		if speed > state.puck_hit_speed[puck]:
			state.puck_hit_speed[puck] = speed
			state.puck_hit_wall[puck] = 1 if is_wall else 0
		return
	var touch_ticks := state.puck_wall_touch_tick if is_wall else state.puck_body_touch_tick
	var is_new_contact := touch_ticks[puck] < state.tick - 1
	touch_ticks[puck] = state.tick
	if is_wall:
		state.puck_wall_touch_tick = touch_ticks
	else:
		state.puck_body_touch_tick = touch_ticks
	if not is_new_contact:
		return
	state.puck_hit_tick[puck] = state.tick
	state.puck_hit_speed[puck] = speed
	state.puck_hit_wall[puck] = 1 if is_wall else 0

## Friction at a contact turns sliding into puck spin, a part (grip) per substep. slip is how fast the puck's
## surface slides along the contact, against the tangent perp(normal), normal pointing out of the other body.
## Only the spin changes, the movement of the bodies stays as it is (spin is cosmetic).
func _grip_spin(spin: PackedFloat32Array, puck: int, slip: float) -> void:
	spin[puck] += settings.puck_spin_grip * slip / radius[puck]

func _collide_bodies(state: SimState, pos: PackedVector2Array, vel: PackedVector2Array, spin: PackedFloat32Array, body_count: int, frozen: int) -> void:
	for i in body_count:
		if i == frozen:
			continue
		for j in range(i + 1, body_count):
			if j == frozen:
				continue
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
			# spin: surface of i at the contact moves with vel_i + spin_i * r_i * tangent, j's with
			# vel_j - spin_j * r_j * tangent, friction turns both pucks by the same sign
			if i < puck_count:
				var tangent := Vector2(-normal.y, normal.x)
				var slip := (vel[j] - vel[i]).dot(tangent) - spin[i] * radius[i]
				if j < puck_count:
					slip -= spin[j] * radius[j]
					_grip_spin(spin, j, slip)
				_grip_spin(spin, i, slip)
			# bounce
			var vn := (vel[j] - vel[i]).dot(normal)
			if vn < 0.0:
				var impulse := normal * (-(1.0 + settings.body_bounce) * vn / w)
				vel[i] -= impulse * wi
				vel[j] += impulse * wj
				# pucks come first, so i is a puck whenever a puck is involved
				if i < puck_count:
					_record_hit(state, i, -vn, false)
				if j < puck_count:
					_record_hit(state, j, -vn, false)

func _collide_walls(state: SimState, pos: PackedVector2Array, vel: PackedVector2Array, spin: PackedFloat32Array, body_count: int, frozen: int) -> void:
	for b in body_count:
		if b == frozen:
			continue
		var is_player := b >= puck_count
		var r := radius[b]
		for s in seg_a.size():
			if seg_players_only[s] == 1 and not is_player:
				continue
			var a := seg_a[s]
			var ab := seg_b[s] - a
			var t_raw := (pos[b] - a).dot(ab) / ab.length_squared()
			if (t_raw <= 0.0 and seg_skip_a[s] == 1) or (t_raw >= 1.0 and seg_skip_b[s] == 1):
				continue # the neighbouring segment handles this contact
			var t := clampf(t_raw, 0.0, 1.0)
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
				var point_contact := t_raw <= 0.0 or t_raw >= 1.0
				var rewind := _end_point_rewind(diff, vel[b], r) if point_contact else -1.0
				if rewind >= 0.0:
					# a fast body sinks deep into a corner (goal post) within one substep, and the normal from
					# there points too far sideways: take it where the body first touched the corner instead
					diff -= vel[b] * rewind
					normal = diff / r
					pos[b] -= vel[b] * rewind
					dist = r
				elif dist > 0.0:
					normal = diff / dist
				elif inward != Vector2.ZERO:
					normal = inward
				else:
					normal = Vector2(-ab.y, ab.x).normalized()
				depth = r - dist
			pos[b] += normal * depth
			if not is_player:
				_grip_spin(spin, b, vel[b].dot(Vector2(-normal.y, normal.x)) - spin[b] * r)
			var vn := vel[b].dot(normal)
			if vn < 0.0:
				vel[b] -= normal * vn * (1.0 + settings.wall_bounce)
				if not is_player:
					_record_hit(state, b, -vn, true)
## How far back in time (seconds, at most one substep) a body moving with vel touched a corner end point first,
## diff = body center - end point, closer than r. -1 when it isn't moving into the corner or was already
## touching it at the start of the substep (pushed in by other bodies, resting contact).
func _end_point_rewind(diff: Vector2, vel: Vector2, r: float) -> float:
	var dv := diff.dot(vel)
	var vv := vel.length_squared()
	if dv >= 0.0 or vv == 0.0:
		return -1.0
	# |diff - vel * s| = r, the positive root (diff is inside r, so there is exactly one)
	var s := (dv + sqrt(dv * dv - vv * (diff.length_squared() - r * r))) / vv
	return s if s <= DT / SUBSTEPS else -1.0

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

## Players per lobby team area, index = team (0 = spectators).
func lobby_team_sizes(state: SimState) -> PackedInt32Array:
	var sizes := PackedInt32Array()
	for team in team_area_team:
		if team >= sizes.size():
			sizes.resize(team + 1)
	for i in player_count:
		if state.zone[i] >= 0:
			sizes[state.zone[i]] += 1
	return sizes

## Hold-to-start: while the lobby is ready, each team player's plus and minus bars fill while that magnet is
## held and drain when it's released. The match starts once every team player has both bars full.
## Spectators (zone 0) don't take part. Reads the buttons step() stored in prev_buttons this tick.
func _update_start_hold(state: SimState) -> void:
	var ready := is_lobby_ready(state)
	var everyone_full := ready
	for i in player_count:
		if not ready or state.zone[i] <= 0:
			state.start_hold_plus[i] = 0
			state.start_hold_minus[i] = 0
			continue
		var buttons := state.prev_buttons[i]
		state.start_hold_plus[i] = _hold_bar(state.start_hold_plus[i], (buttons & SimInput.PLUS) != 0)
		state.start_hold_minus[i] = _hold_bar(state.start_hold_minus[i], (buttons & SimInput.MINUS) != 0)
		if state.start_hold_plus[i] < START_HOLD_TICKS or state.start_hold_minus[i] < START_HOLD_TICKS:
			everyone_full = false
	if everyone_full and state.start_tick == -1:
		state.start_tick = state.tick

func _hold_bar(value: int, held: bool) -> int:
	if held:
		return mini(value + 1, START_HOLD_TICKS)
	return maxi(value - START_HOLD_DRAIN, 0)

## Every player stands in a team area and every team has at least one player.
func is_lobby_ready(state: SimState) -> bool:
	for i in player_count:
		if state.zone[i] == -1:
			return false
	var sizes := lobby_team_sizes(state)
	for team in range(1, sizes.size()):
		if sizes[team] == 0:
			return false
	return player_count > 0

func _step_match(state: SimState, menu_pressed: bool, back_pressed: bool) -> void:
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
			var goal_puck := _check_goals(state)
			if goal_puck != -1:
				_start_goal(state, goal_puck)
			elif not state.overtime and state.match_ticks <= 0:
				_end_regular_time(state)
		Phase.GOAL:
			state.phase_ticks -= 1
			if state.phase_ticks <= 0:
				state.goal_puck = -1
				if state.overtime:
					_game_over(state, state.last_goal_team)
				elif state.match_ticks <= 0:
					_end_regular_time(state)
				else:
					_reset_field(state)
					_start_countdown(state)
		Phase.GAME_OVER:
			# MENU: rematch, BACK: everybody goes back to the lobby (the views leave the match on that)
			if state.lobby_tick != -1:
				pass
			elif back_pressed:
				state.lobby_tick = state.tick
			elif menu_pressed:
				start_match(state)

## Returns the puck that is in a goal, -1 if none.
func _check_goals(state: SimState) -> int:
	for k in puck_count:
		if _goal_team(state, k) != 0:
			return k
	return -1

## The team puck k scores for (the right goal counts for team 1, the left one for team 2), 0 if none.
func _goal_team(state: SimState, k: int) -> int:
	var p := state.pos[k] - goal_center
	if absf(p.y) >= goal_half_width:
		return 0
	if p.x > goal_line_dist:
		return 1
	if p.x < -goal_line_dist:
		return 2
	return 0

## Scores the goal and starts the celebration: the puck stops and leaves play, the shockwave pushes
## every other body away from it.
func _start_goal(state: SimState, goal_puck: int) -> void:
	var team := _goal_team(state, goal_puck)
	state.scores[team - 1] += 1
	state.last_goal_tick = state.tick
	state.last_goal_team = team
	state.goal_puck = goal_puck
	state.phase = Phase.GOAL
	state.phase_ticks = GOAL_TICKS
	var center := state.pos[goal_puck]
	state.vel[goal_puck] = Vector2.ZERO
	state.puck_spin[goal_puck] = 0.0
	for b in puck_count + player_count:
		if b == goal_puck:
			continue
		var diff := state.pos[b] - center
		var dist := diff.length()
		if dist >= GOAL_PUSH_RANGE:
			continue
		var dir := diff / dist if dist > 0.0 else Vector2.LEFT * signf(center.x - goal_center.x)
		state.vel[b] += dir * GOAL_PUSH_SPEED * (1.0 - dist / GOAL_PUSH_RANGE)

## Regular time is over: a leader wins, a tie goes to overtime (the next goal decides).
func _end_regular_time(state: SimState) -> void:
	var leader := _leading_team(state)
	if leader == 0:
		state.overtime = true
		state.overtime_ticks = 0
		_reset_field(state)
		_start_countdown(state)
	else:
		_game_over(state, leader)

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
	for k in puck_count:
		state.puck_spin[k] = 0.0

func _reset_field(state: SimState) -> void:
	if puck_spawns.size() > 0:
		var order := _shuffled_indices(state, puck_spawns.size())
		for k in puck_count:
			state.pos[k] = puck_spawns[order[k % order.size()]]
			state.vel[k] = Vector2.ZERO
			state.puck_plus[k] = 1
			state.puck_angle[k] = 0.0
			state.puck_spin[k] = 0.0
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
