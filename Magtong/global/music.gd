extends Node
## Background music (autoload Music) on the Music bus.
## Menu and lobby share Kenney's cheerful "Cheerful Annoyance" (it keeps playing into the lobby, quieter).
## Entering a match fades it out, the countdown is quiet, and the DnB match loop (AlesiaDavina) kicks in hard
## on "go" (start_match(), called by MapSounds): the switch is the "lock in" moment. Goals duck the music for a
## moment (duck(), also MapSounds). Sources and loop cuts: assets/sounds/LICENSES.md.

enum Track { NONE, CHEERFUL, MATCH }

const STREAMS: Dictionary[Track, AudioStream] = {
	Track.CHEERFUL: preload("res://assets/sounds/music/menu_cheerful_annoyance.ogg"),
	Track.MATCH: preload("res://assets/sounds/music/match_loop.ogg"),
}
## Measured loudness of each file (integrated LUFS, ffmpeg -af ebur128), so tracks from different sources
## end up equally loud.
const FILE_LUFS: Dictionary[Track, float] = {
	Track.CHEERFUL: -14.9,
	Track.MATCH: -9.2,
}
## How loud each track plays (LUFS at full Music volume): quiet under the sound effects.
const TARGET_LUFS: Dictionary[Track, float] = {
	Track.CHEERFUL: -26.0,
	Track.MATCH: -28.0,
}
## In the lobby the menu music keeps playing, this much quieter and at this pitch (1.0 = unchanged; lower is
## slower and deeper, like a slowed tape).
const LOBBY_DB: float = -5.0
const LOBBY_PITCH: float = 1.0
## How fast level and pitch glide to the lobby/menu values (per second).
const LEVEL_GLIDE_DB: float = 5.0
const PITCH_GLIDE: float = 0.1

const FADE_TIME: float = 1.0
## Lobby swell (set_lobby_progress(), from MapSounds): once everyone is in a team the music comes back up to
## the menu level, and while the start bars fill it swells up to LOBBY_SWELL_DB above that.
const LOBBY_SWELL_DB: float = 4.0
const SWELL_GLIDE_DB: float = 20.0
## Leaving the lobby for a match: the menu music fades out under the countdown.
const MATCH_ENTER_FADE: float = 1.5
## The match loop starts at full volume on "go" (a few ms only, against a click).
const MATCH_START_FADE: float = 0.02
## Goal duck: down by DUCK_DB within DUCK_ATTACK, held for DUCK_HOLD, back up over DUCK_RELEASE.
const DUCK_DB: float = -12.0
const DUCK_ATTACK: float = 0.08
const DUCK_HOLD: float = 1.2
const DUCK_RELEASE: float = 1.0

## Two players so the old track fades out while the new one fades in.
var _players: Array[AudioStreamPlayer] = []
var _weights: Array[float] = [0.0, 0.0]
var _tracks: Array[Track] = [Track.NONE, Track.NONE]
var _current: int = 0 # index of the player with the current track
var _fade_in_time: float = FADE_TIME
var _fade_out_time: float = FADE_TIME
var _level_db: float = 0.0 # lobby offset, gliding
var _target_level_db: float = 0.0
var _swell_db: float = 0.0 # start bar swell, gliding
var _target_swell_db: float = 0.0
var _pitch: float = 1.0
var _target_pitch: float = 1.0
var _duck_time: float = -1.0 # seconds since the last duck started, -1 = not ducking

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # keeps fading while the tree is paused
	for stream in STREAMS.values():
		stream.loop = true
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_players.append(player)
	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.current_state, GameManager.current_state)

## Switches to track, fading the old one out over fade_out and the new one in over fade_in.
## Does nothing if the track is already playing (it keeps going, no restart).
func play(track: Track, fade_in: float = FADE_TIME, fade_out: float = FADE_TIME) -> void:
	if _tracks[_current] == track:
		return
	_fade_in_time = fade_in
	_fade_out_time = fade_out
	_current = 1 - _current
	var player := _players[_current]
	_tracks[_current] = track
	_weights[_current] = 0.0
	if track == Track.NONE:
		player.stop()
		return
	player.stream = STREAMS[track]
	player.play()
	_update_volumes()

## "Go" of a match countdown: the match loop kicks in (keeps running if it already is, e.g. after a goal).
func start_match() -> void:
	play(Track.MATCH, MATCH_START_FADE, MATCH_ENTER_FADE)

## Lobby state for the swell: ready = every player in a team, hold = how full the start bars are (0..1).
func set_lobby_progress(ready: bool, hold: float) -> void:
	if GameManager.current_state != GameManager.State.LOBBY:
		return
	_target_level_db = 0.0 if ready else LOBBY_DB
	_target_swell_db = LOBBY_SWELL_DB * clampf(hold, 0.0, 1.0)

func duck() -> void:
	_duck_time = 0.0

func _on_state_changed(_old_state: GameManager.State, new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.MENU:
			_target_level_db = 0.0
			_target_swell_db = 0.0
			_target_pitch = 1.0
			play(Track.CHEERFUL)
		GameManager.State.LOBBY:
			_target_level_db = LOBBY_DB
			_target_swell_db = 0.0
			_target_pitch = LOBBY_PITCH
			play(Track.CHEERFUL)
		GameManager.State.GAME:
			play(Track.NONE, FADE_TIME, MATCH_ENTER_FADE)

func _process(delta: float) -> void:
	for i in 2:
		var is_current := i == _current
		var fade_time := _fade_in_time if is_current else _fade_out_time
		_weights[i] = move_toward(_weights[i], 1.0 if is_current else 0.0, delta / fade_time)
		if _weights[i] == 0.0 and _players[i].playing:
			_players[i].stop()
	_level_db = move_toward(_level_db, _target_level_db, LEVEL_GLIDE_DB * delta)
	_swell_db = move_toward(_swell_db, _target_swell_db, SWELL_GLIDE_DB * delta)
	_pitch = move_toward(_pitch, _target_pitch, PITCH_GLIDE * delta)
	if _duck_time >= 0.0:
		_duck_time += delta
		if _duck_time > DUCK_ATTACK + DUCK_HOLD + DUCK_RELEASE:
			_duck_time = -1.0
	_update_volumes()

## 0 = no duck, 1 = fully ducked
func _duck_amount() -> float:
	if _duck_time < 0.0:
		return 0.0
	if _duck_time < DUCK_ATTACK:
		return _duck_time / DUCK_ATTACK
	if _duck_time < DUCK_ATTACK + DUCK_HOLD:
		return 1.0
	return 1.0 - (_duck_time - DUCK_ATTACK - DUCK_HOLD) / DUCK_RELEASE

func _update_volumes() -> void:
	var duck_db := DUCK_DB * _duck_amount()
	for i in 2:
		var track := _tracks[i]
		if track == Track.NONE:
			continue
		# the lobby offset and pitch only apply to the menu music, the match loop always plays as is
		var cheerful := track == Track.CHEERFUL
		_players[i].pitch_scale = _pitch if cheerful else 1.0
		# fade in linear amplitude (sounds even), then the per-track level, lobby offset and duck in dB
		_players[i].volume_db = linear_to_db(maxf(_weights[i], 0.0001)) \
				+ TARGET_LUFS[track] - FILE_LUFS[track] + (_level_db + _swell_db if cheerful else 0.0) + duck_db
