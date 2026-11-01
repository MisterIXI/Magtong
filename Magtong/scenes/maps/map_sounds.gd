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
const COUNTDOWN_BEEP: AudioStream = preload("res://assets/sounds/sfx/countdown_beep.ogg")
const MATCH_END: AudioStream = preload("res://assets/sounds/sfx/match_end.ogg")
const LOBBY_JOIN: AudioStream = preload("res://assets/sounds/ui/lobby_join.ogg")
const LOBBY_READY: AudioStream = preload("res://assets/sounds/ui/lobby_ready.ogg")

## Puck hits below this speed (along the contact normal) are silent, e.g. a puck held against a wall.
const HIT_MIN_SPEED: float = 40.0
## Puck hits at this speed or faster play at full volume.
const HIT_FULL_SPEED: float = 800.0
const HIT_MIN_GAP_TICKS: int = 6
const HIT_RANDOM_PITCH: float = 1.08
const WALL_HIT_PITCH: float = 1.2
const MAGNET_VOLUME_DB: float = -14.0
const MAGNET_NEG_PITCH: float = 0.8
const GO_PITCH: float = 1.5
const UNREADY_PITCH: float = 0.8

var map: MapScript
var _hit_stream := AudioStreamRandomizer.new()
var _hit_players: Array[AudioStreamPlayer] = []
var _played_hit_tick: PackedInt32Array = PackedInt32Array()
var _hums: Array[AudioStreamPlayer] = []
var _beep: AudioStreamPlayer
var _match_end: AudioStreamPlayer
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
	_beep = _new_player(COUNTDOWN_BEEP)
	_match_end = _new_player(MATCH_END)
	_join = _new_player(LOBBY_JOIN)
	_ready_sound = _new_player(LOBBY_READY)

## Called by MapScript every time the views were updated.
func update(state: SimState) -> void:
	if state.tick < _last_tick - Simulation.TICK_RATE:
		# a new state (fresh lobby), not a rollback: the old hit ticks mean nothing anymore
		_played_hit_tick.fill(-HIT_MIN_GAP_TICKS - 1)
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
		for hum in _hums:
			hum.queue_free()
		_hums.clear()
		for i in map.players.size():
			var hum := _new_player(MAGNET_LOOP)
			hum.volume_db = MAGNET_VOLUME_DB
			_hums.append(hum)
	for i in _hums.size():
		var pol: Simulation.Polarity = state.polarity[i]
		var hum := _hums[i]
		if pol == Simulation.Polarity.IDLE:
			if hum.playing:
				hum.stop()
			continue
		hum.pitch_scale = MAGNET_NEG_PITCH if pol == Simulation.Polarity.NEG else 1.0
		if not hum.playing:
			hum.play()

func _update_match(state: SimState) -> void:
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
	_shown_player_count = count
	_shown_ready = is_ready

func _play(player: AudioStreamPlayer, pitch: float) -> void:
	player.pitch_scale = pitch
	player.play()

func _new_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	add_child(player)
	return player
