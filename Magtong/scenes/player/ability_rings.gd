extends Node2D
class_name AbilityRings
## Code-drawn feedback for Flip and Surge, readable even on a small stream (playtest 15.11: both were hard to
## see). Flip: a crisp ring that snaps out to exactly the flip range, half plus color, half minus color, so you
## see which pucks were close enough. Surge: a thick shockwave in the player's polarity color plus a punch of
## the player sprite. Runs in real time, triggered by PlayerVisuals when the simulation shows a new ability tick.

## placeholder until the new colors are decided (release plan), same as the magnet colors
const PLUS_COLOR := Color(1.0, 0.3, 0.3)
const MINUS_COLOR := Color(0.35, 0.55, 1.0)
const FLIP_TIME: float = 0.3
const SURGE_TIME: float = 0.45
const SURGE_RADIUS: float = 320.0
const SURGE_PUNCH: float = 0.45 # the sprite grows this much at the start of a Surge

var flip_range: float = 200.0
var punch_target: Node2D # scaled by the Surge punch
var _flip_age: float = -1.0
var _surge_age: float = -1.0
var _surge_color: Color
var _punch_base: Vector2 = Vector2.ONE

func _ready() -> void:
	z_index = 5
	if punch_target != null:
		_punch_base = punch_target.scale

func play_flip() -> void:
	_flip_age = 0.0

func play_surge(pol: Simulation.Polarity) -> void:
	_surge_color = PLUS_COLOR if pol == Simulation.Polarity.POS else MINUS_COLOR
	_surge_age = 0.0

func _process(delta: float) -> void:
	if _flip_age < 0.0 and _surge_age < 0.0:
		return
	if _flip_age >= 0.0:
		_flip_age += delta
		if _flip_age > FLIP_TIME:
			_flip_age = -1.0
	if _surge_age >= 0.0:
		_surge_age += delta
		if _surge_age > SURGE_TIME:
			_surge_age = -1.0
	if punch_target != null:
		var punch := 0.0
		if _surge_age >= 0.0:
			punch = SURGE_PUNCH * pow(1.0 - _surge_age / SURGE_TIME, 3.0)
		punch_target.scale = _punch_base * (1.0 + punch)
	queue_redraw()

func _draw() -> void:
	if _flip_age >= 0.0:
		var t := _flip_age / FLIP_TIME
		# snaps out fast and stays at the range while it fades, so the reach is readable
		var r := flip_range * (1.0 - pow(1.0 - minf(t * 2.5, 1.0), 3.0))
		var a := 1.0 - t * t
		draw_arc(Vector2.ZERO, r, 0.0, PI, 48, Color(PLUS_COLOR, a), 7.0)
		draw_arc(Vector2.ZERO, r, PI, TAU, 48, Color(MINUS_COLOR, a), 7.0)
		draw_arc(Vector2.ZERO, r - 6.0, 0.0, TAU, 96, Color(1, 1, 1, a * 0.8), 2.0)
	if _surge_age >= 0.0:
		var t := _surge_age / SURGE_TIME
		var e := 1.0 - pow(1.0 - t, 2.0)
		var fade := 1.0 - t
		draw_circle(Vector2.ZERO, 40.0 + 30.0 * e, Color(_surge_color, 0.5 * fade))
		draw_arc(Vector2.ZERO, SURGE_RADIUS * e, 0.0, TAU, 96, Color(_surge_color, fade), 16.0 * fade + 2.0)
		draw_arc(Vector2.ZERO, SURGE_RADIUS * 0.75 * e, 0.0, TAU, 96, Color(1, 1, 1, 0.6 * fade), 4.0 * fade + 1.0)
