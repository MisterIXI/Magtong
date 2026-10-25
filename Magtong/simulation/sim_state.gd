class_name SimState
extends RefCounted
## Everything that changes during a simulation step. This is what gets saved and restored for rollback,
## so it only holds plain data. Static data (geometry, radii, masses, spawns) lives in Simulation.
## Bodies are stored pucks first, then players: body index of player i is puck_count + i.

var tick: int = 0
var rng: int = 1

# all bodies
var pos: PackedVector2Array = PackedVector2Array()
var vel: PackedVector2Array = PackedVector2Array()

# pucks
var puck_plus: PackedByteArray = PackedByteArray()

# players
var polarity: PackedInt32Array = PackedInt32Array()
var prev_buttons: PackedInt32Array = PackedInt32Array()
var pulse_cd: PackedInt32Array = PackedInt32Array()
var ability_cd: PackedInt32Array = PackedInt32Array()
var last_pulse_tick: PackedInt32Array = PackedInt32Array()
var last_ability_tick: PackedInt32Array = PackedInt32Array()
var zone: PackedInt32Array = PackedInt32Array() # lobby team area the player touches, -1 = none
var skin: PackedInt32Array = PackedInt32Array()

# match
var phase: int = Simulation.Phase.NONE
var phase_ticks: int = 0 # ticks left in the countdown
var match_ticks: int = 0 # ticks left of regular time
var overtime: bool = false
var overtime_ticks: int = 0
var scores: PackedInt32Array = PackedInt32Array([0, 0])
var winner: int = -1 # 0 = tie, 1/2 = team
var last_goal_tick: int = -1
var last_goal_team: int = 0
var reset_tick: int = -1 # last tick bodies were teleported (views skip interpolation)

# lobby
var start_tick: int = -1 # tick a player started the match from the lobby

func copy() -> SimState:
	var c := SimState.new()
	c.tick = tick
	c.rng = rng
	c.pos = pos.duplicate()
	c.vel = vel.duplicate()
	c.puck_plus = puck_plus.duplicate()
	c.polarity = polarity.duplicate()
	c.prev_buttons = prev_buttons.duplicate()
	c.pulse_cd = pulse_cd.duplicate()
	c.ability_cd = ability_cd.duplicate()
	c.last_pulse_tick = last_pulse_tick.duplicate()
	c.last_ability_tick = last_ability_tick.duplicate()
	c.zone = zone.duplicate()
	c.skin = skin.duplicate()
	c.phase = phase
	c.phase_ticks = phase_ticks
	c.match_ticks = match_ticks
	c.overtime = overtime
	c.overtime_ticks = overtime_ticks
	c.scores = scores.duplicate()
	c.winner = winner
	c.last_goal_tick = last_goal_tick
	c.last_goal_team = last_goal_team
	c.reset_tick = reset_tick
	c.start_tick = start_tick
	return c

## Removes a player (lobby leave). body is the body index, player the player index.
func remove_player(body: int, player: int) -> void:
	pos.remove_at(body)
	vel.remove_at(body)
	for array_name in [&"polarity", &"prev_buttons", &"pulse_cd", &"ability_cd", &"last_pulse_tick", &"last_ability_tick", &"zone", &"skin"]:
		var array: PackedInt32Array = get(array_name)
		array.remove_at(player)
		set(array_name, array)

const FIELDS: Array[StringName] = [
	&"tick", &"rng", &"pos", &"vel", &"puck_plus", &"polarity", &"prev_buttons", &"pulse_cd", &"ability_cd",
	&"last_pulse_tick", &"last_ability_tick", &"zone", &"skin", &"phase", &"phase_ticks", &"match_ticks", &"overtime",
	&"overtime_ticks", &"scores", &"winner", &"last_goal_tick", &"last_goal_team", &"reset_tick", &"start_tick",
]

## Hash of the full state, used to detect desyncs between peers.
func checksum() -> int:
	return hash(to_bytes())

## Full state as bytes, used for desync recovery snapshots.
func to_bytes() -> PackedByteArray:
	var parts := []
	for field in FIELDS:
		parts.append(get(field))
	return var_to_bytes(parts)

static func from_bytes(bytes: PackedByteArray) -> SimState:
	var parts: Array = bytes_to_var(bytes)
	var s := SimState.new()
	for i in FIELDS.size():
		s.set(FIELDS[i], parts[i])
	return s
