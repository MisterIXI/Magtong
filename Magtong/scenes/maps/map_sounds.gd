extends Node
class_name MapSounds
## Gameplay and lobby sounds of a map, on the SFX bus. Like the other views it only reacts to state changes it
## sees after the simulation stepped, never from inside Simulation.step. A rollback can show the same event again
## at a slightly different tick, so a puck hit closer than HIT_MIN_GAP_TICKS to the last played one is skipped.
## Only MapScript creates this node, so the main menu background (same views, own simulation) stays silent.

const PUCK_HITS: Array[AudioStream] = [
	preload("res://assets/sounds/sfx/puck_hit_1.ogg"),
	preload("res://assets/sounds/sfx/puck_hit_2.ogg"),
	preload("res://assets/sounds/sfx/puck_hit_3.ogg"),
	preload("res://assets/sounds/sfx/puck_hit_4.ogg"),
]
const MAGNET_LOOP: AudioStream = preload("res://assets/sounds/sfx/magnet_loop.ogg")
const FLIP_CLACK: AudioStream = preload("res://assets/sounds/sfx/dead.wav")
const MATCH_END: AudioStream = preload("res://assets/sounds/sfx/match_end.ogg")
const GOAL: AudioStream = preload("res://assets/sounds/sfx/goal_horn.mp3")
const LOBBY_JOIN: AudioStream = preload("res://assets/sounds/ui/lobby_join.ogg")
const LOBBY_READY: AudioStream = preload("res://assets/sounds/ui/lobby_ready.ogg")
const TEAM_PICK: AudioStream = preload("res://assets/sounds/ui/team_pick.ogg")

## Puck hits below this speed (along the contact normal) are silent, e.g. a puck held against a wall.
const HIT_MIN_SPEED: float = 40.0
## Puck hits at this speed or faster play at full volume.
const HIT_FULL_SPEED: float = 800.0
const HIT_MIN_GAP_TICKS: int = 6
const HIT_RANDOM_PITCH: float = 1.08
const WALL_HIT_PITCH: float = 1.2
## playtest 15.11: the hum was annoying at -14 dB; a softer replacement is still open (audio plan)
const MAGNET_VOLUME_DB: float = -20.0
const MAGNET_NEG_PITCH: float = 0.8
## Surge (B): the player's hum jumps louder and higher, then falls back over SURGE_TIME.
const SURGE_TIME: float = 0.35
const SURGE_DB: float = 10.0
const SURGE_PITCH: float = 0.6 # +60 % at the peak
## Flip (A, flips nearby pucks): a short hum sweep from low to high, like the field reversing, plus a
## metallic clack. Works without a magnet held, so the sweep has its own player per magnet.
const FLIP_TIME: float = 0.25
const FLIP_PITCH_FROM: float = 0.5
const FLIP_PITCH_TO: float = 1.6
const FLIP_VOLUME_DB: float = -8.0
const FLIP_CLACK_VOLUME_DB: float = -8.0
const TEAM_PICK_VOLUME_DB: float = -6.0
## seconds; a player wobbling on the edge of a team area doesn't rattle the click
const TEAM_PICK_MIN_GAP: float = 0.3
## The countdown uses the team pick click (playtest 15.11: softer than the old beep), "go" pitched up.
const COUNTDOWN_VOLUME_DB: float = -3.0
const GO_PITCH: float = 2.0
const UNREADY_PITCH: float = 0.8
## the horn alone at full volume was too loud and stuck out (14.11)
const GOAL_VOLUME_DB: float = -8.0

var map: MapScript
var _hit_stream := AudioStreamRandomizer.new()
var _hit_players: Array[AudioStreamPlayer] = []
var _played_hit_tick: PackedInt32Array = PackedInt32Array()
var _hums: Array[AudioStreamPlayer] = []
var _flip_clack: AudioStreamPlayer
var _team_pick: AudioStreamPlayer
# per player, rebuilt with the hums when the roster changes
var _sweeps: Array[AudioStreamPlayer] = []
var _shown_flip_tick: PackedInt32Array = PackedInt32Array()
var _shown_surge_tick: PackedInt32Array = PackedInt32Array()
var _surge_start: PackedFloat64Array = PackedFloat64Array() # seconds, -1 = none
var _flip_start: PackedFloat64Array = PackedFloat64Array()
var _shown_zone: PackedInt32Array = PackedInt32Array() # team area each player was in last update, -1 = none
var _team_pick_time: PackedFloat64Array = PackedFloat64Array() # seconds of the last click per player
var _beep: AudioStreamPlayer
var _match_end: AudioStreamPlayer
var _goal: AudioStreamPlayer
var _shown_goal_tick: int = -2 # -2: not seen yet, so a goal from before (e.g. a rejoin) doesn't play
var _join: AudioStreamPlayer
var _ready_sound: AudioStreamPlayer
var _last_tick: int = 0
var _shown_phase: Simulation.Phase = Simulation.Phase.NONE
var _shown_seconds: int = 0
var _shown_player_count: int = -1
var _shown_ready: bool = false

func _init(map: MapScript) -> void:
	self.map = map
	name = "MapSounds"
	for stream in PUCK_HITS:
		_hit_stream.add_stream(-1, stream)
	_hit_stream.random_pitch = HIT_RANDOM_PITCH
	_beep = _new_player(TEAM_PICK, COUNTDOWN_VOLUME_DB)
	_match_end = _new_player(MATCH_END)
	_goal = _new_player(GOAL)
	_goal.volume_db = GOAL_VOLUME_DB
	_flip_clack = _new_player(FLIP_CLACK, FLIP_CLACK_VOLUME_DB, 4)
	_team_pick = _new_player(TEAM_PICK, TEAM_PICK_VOLUME_DB, 4)
	_join = _new_player(LOBBY_JOIN)
	_ready_sound = _new_player(LOBBY_READY)

## Called by MapScript every time the views were updated.
func update(state: SimState) -> void:
	if state.tick < _last_tick - Simulation.TICK_RATE:
		# a new state (fresh lobby), not a rollback: the old hit ticks mean nothing anymore
		_played_hit_tick.fill(-HIT_MIN_GAP_TICKS - 1)
		_shown_flip_tick.fill(-1)
		_shown_surge_tick.fill(-1)
	_last_tick = state.tick
	_update_pucks(state)
	_update_magnets(state)
	if map.is_lobby_map:
		_update_lobby(state)
	else:
		_update_match(state)

func _update_pucks(state: SimState) -> void:
	while _hit_players.size() < map.pucks.size():
		var player := _new_player(_hit_stream)
		player.max_polyphony = 3
		_hit_players.append(player)
		_played_hit_tick.append(-HIT_MIN_GAP_TICKS - 1)
	for k in map.pucks.size():
		var tick := state.puck_hit_tick[k]
		if tick < _played_hit_tick[k] + HIT_MIN_GAP_TICKS or state.puck_hit_speed[k] < HIT_MIN_SPEED:
			continue
		_played_hit_tick[k] = tick
		var player := _hit_players[k]
		player.volume_db = linear_to_db(clampf(state.puck_hit_speed[k] / HIT_FULL_SPEED, 0.1, 1.0))
		player.pitch_scale = WALL_HIT_PITCH if state.puck_hit_wall[k] == 1 else 1.0
		player.play()

func _update_magnets(state: SimState) -> void:
	if _hums.size() != map.players.size():
		# lobby rebuilt with a different roster
		for player in _hums + _sweeps:
			player.queue_free()
		_hums.clear()
		_sweeps.clear()
		for i in map.players.size():
			_hums.append(_new_player(MAGNET_LOOP, MAGNET_VOLUME_DB))
			_sweeps.append(_new_player(MAGNET_LOOP, FLIP_VOLUME_DB))
		# the current state counts as already heard, so a rebuilt roster doesn't replay old abilities
		_shown_flip_tick = state.last_flip_tick.duplicate()
		_shown_surge_tick = state.last_surge_tick.duplicate()
		_surge_start.resize(_hums.size())
		_surge_start.fill(-1.0)
		_flip_start.resize(_hums.size())
		_flip_start.fill(-1.0)
		_shown_zone = state.zone.duplicate()
		_team_pick_time.resize(_hums.size())
		_team_pick_time.fill(-TEAM_PICK_MIN_GAP)
	var now := Time.get_ticks_msec() / 1000.0
	for i in _hums.size():
		_update_abilities(state, i, now)
		var pol: Simulation.Polarity = state.polarity[i]
		var hum := _hums[i]
		if pol == Simulation.Polarity.IDLE:
			if hum.playing:
				hum.stop()
			continue
		var surge := _envelope(_surge_start[i], SURGE_TIME, now)
		hum.volume_db = MAGNET_VOLUME_DB + SURGE_DB * surge
		hum.pitch_scale = (MAGNET_NEG_PITCH if pol == Simulation.Polarity.NEG else 1.0) * (1.0 + SURGE_PITCH * surge)
		if not hum.playing:
			hum.play()

## Surge and flip. Each only plays for a newer tick than the last one played, so a rollback that shows
## the same one again doesn't repeat it.
func _update_abilities(state: SimState, i: int, now: float) -> void:
	if state.last_surge_tick[i] > _shown_surge_tick[i]:
		_shown_surge_tick[i] = state.last_surge_tick[i]
		_surge_start[i] = now
	var sweep := _sweeps[i]
	if state.last_flip_tick[i] > _shown_flip_tick[i]:
		_shown_flip_tick[i] = state.last_flip_tick[i]
		_flip_start[i] = now
		# sweep.play(randf() * MAGNET_LOOP.get_length() * 0.8)
		_flip_clack.play()
	if sweep.playing:
		var t := (now - _flip_start[i]) / FLIP_TIME
		if t >= 1.0:
			sweep.stop()
		else:
			sweep.pitch_scale = lerpf(FLIP_PITCH_FROM, FLIP_PITCH_TO, t)
			sweep.volume_db = FLIP_VOLUME_DB + linear_to_db(1.0 - t)

## 1 at start, falling to 0 after length seconds (quadratic ease out), 0 if it never started.
func _envelope(start: float, length: float, now: float) -> float:
	if start < 0.0:
		return 0.0
	var t := (now - start) / length
	if t >= 1.0:
		return 0.0
	return (1.0 - t) * (1.0 - t)

func _update_match(state: SimState) -> void:
	# only newer goals: a rollback can move last_goal_tick back, the sound must not play twice
	if _shown_goal_tick == -2:
		_shown_goal_tick = state.last_goal_tick
	elif state.last_goal_tick > _shown_goal_tick:
		_shown_goal_tick = state.last_goal_tick
		_play(_goal, 1.0)
	if state.phase == Simulation.Phase.COUNTDOWN:
		var seconds := ceili(float(state.phase_ticks) / Simulation.TICK_RATE)
		if _shown_phase != Simulation.Phase.COUNTDOWN or seconds != _shown_seconds:
			_play(_beep, 1.0)
		_shown_seconds = seconds
	elif state.phase != _shown_phase:
		if state.phase == Simulation.Phase.PLAYING and _shown_phase == Simulation.Phase.COUNTDOWN:
			_play(_beep, GO_PITCH)
		elif state.phase == Simulation.Phase.GAME_OVER:
			_play(_match_end, 1.0)
	_shown_phase = state.phase

func _update_lobby(state: SimState) -> void:
	var count := map.players.size()
	var is_ready := map.sim.is_lobby_ready(state)
	if _shown_player_count != -1:
		if count > _shown_player_count:
			_play(_join, 1.0)
		elif count == _shown_player_count and is_ready != _shown_ready:
			_play(_ready_sound, 1.0 if is_ready else UNREADY_PITCH)
	# team pick: a click on every entry into a team area, at most one per TEAM_PICK_MIN_GAP per player
	var now := Time.get_ticks_msec() / 1000.0
	for i in mini(count, _shown_zone.size()):
		var zone := state.zone[i]
		if zone >= 0 and zone != _shown_zone[i] and now - _team_pick_time[i] >= TEAM_PICK_MIN_GAP:
			_team_pick_time[i] = now
			_team_pick.play()
		_shown_zone[i] = zone
	_shown_player_count = count
	_shown_ready = is_ready

func _play(player: AudioStreamPlayer, pitch: float) -> void:
	player.pitch_scale = pitch
	player.play()

func _new_player(stream: AudioStream, volume_db: float = 0.0, polyphony: int = 1) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	player.bus = &"SFX"
	add_child(player)
	return player
