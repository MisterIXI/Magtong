extends Node2D
class_name FlipRing
## Flip: an electric ring at the exact flip range (the same range Simulation._flip uses), drawn like FlipZap's
## lightning: two see-through jagged loops in the plus and minus colors (Flip swaps both ways) over thin white
## cores, crackling (re-jagged every few frames) while it expands from the player, holds at the range and fades
## in place. Shows where a Flip reaches, also when no puck was close enough. Top level and global like FlipZap (just under its
## lines), so it stays where the Flip happened; frees itself.

const EXPAND_TIME: float = 0.19
const HOLD_TIME: float = 0.05
const FADE_TIME: float = 0.22
const ALPHA: float = 0.6
const START_RADIUS: float = 0.12 # share of the range the ring starts at
## how far the loops zig and zag off the circle; mostly inward, so the ring doesn't look bigger than the range
const JAG_IN: float = 15.0
const JAG_OUT: float = 6.0
const SEGMENT_LENGTH: float = 24.0 # at full size
const FLICKER_TIME: float = 0.035

var _range: float = 100.0 # in global units
var _age: float = 0.0
var _flicker: float = 0.0
var _steps: int = 24
var _jags: Array[PackedFloat32Array] = [] # per loop: radial offset per point

## pos and range_global in global coordinates
static func spawn(parent: Node, pos: Vector2, range_global: float) -> void:
	if range_global <= 0.0:
		return
	var ring := FlipRing.new()
	ring.top_level = true
	ring.z_index = 19
	ring._range = range_global
	parent.add_child(ring)
	ring.global_position = pos
	# physics interpolation is on: without this the ring slides in from (0, 0) over the first tick
	ring.reset_physics_interpolation()

func _ready() -> void:
	_steps = clampi(int(TAU * _range / SEGMENT_LENGTH), 24, 120)
	_rejag()

func _rejag() -> void:
	_jags.clear()
	for loop in 2:
		var jag := PackedFloat32Array()
		jag.resize(_steps)
		for i in _steps:
			jag[i] = randf_range(-JAG_IN, JAG_OUT)
		_jags.append(jag)

func _process(delta: float) -> void:
	_age += delta
	if _age >= EXPAND_TIME + HOLD_TIME + FADE_TIME:
		queue_free()
		return
	_flicker += delta
	if _flicker >= FLICKER_TIME:
		_flicker = 0.0
		_rejag()
	queue_redraw()

func _draw() -> void:
	var t := clampf(_age / EXPAND_TIME, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - t, 3.0) # cubic ease out: quick start, visibly settles onto the range
	var radius := _range * lerpf(START_RADIUS, 1.0, grow)
	var fade := 1.0 - clampf((_age - EXPAND_TIME - HOLD_TIME) / FADE_TIME, 0.0, 1.0)
	# the zig-zag scales with the ring, so the small starting ring isn't a scribble
	var jag_scale := radius / _range
	for loop in 2:
		var col := FlipZap.PLUS_COLOR if loop == 0 else FlipZap.MINUS_COLOR
		var jag := _jags[loop]
		var points := PackedVector2Array()
		# the two loops start at different angles, so their corners don't line up
		var offset := PI / _steps * loop
		for i in _steps + 1:
			var k := i % _steps
			points.append(Vector2.from_angle(offset + TAU * k / _steps) * (radius + jag[k] * jag_scale))
		# a thin white core under a see-through color: softer than FlipZap's lines, so the zaps to the pucks stand out
		draw_polyline(points, Color(1, 1, 1, fade), 1.8 * fade + 0.5)
		draw_polyline(points, Color(col, ALPHA * fade), 3.0 * fade + 1.0)
