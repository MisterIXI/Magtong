extends Node2D
class_name FlipZap
## Flip: short lightning lines from the player to every puck it flipped, in each puck's new color. Shows cause
## and effect at a glance (playtest 15.11: Flip was hard to see, and needed a look of its own next to Surge's
## ripple). Global coordinates and top level, so the lines stay where the Flip happened; frees itself.

const TIME: float = 0.22
const JAGGED: float = 9.0 # how far the bolt zigzags off the straight line
const SEGMENT_LENGTH: float = 18.0
## placeholder until the new colors are decided (release plan), same as the magnet colors
const PLUS_COLOR := Color(1.0, 0.35, 0.3)
const MINUS_COLOR := Color(0.35, 0.55, 1.0)

var _bolts: Array = [] # [points: PackedVector2Array, color: Color]
var _age: float = 0.0

## from and targets in global coordinates, plus: the new polarity of each target puck
static func spawn(parent: Node, from: Vector2, targets: PackedVector2Array, plus: Array) -> void:
	if targets.is_empty():
		return
	var zap := FlipZap.new()
	zap.top_level = true
	zap.z_index = 20
	for i in targets.size():
		zap._bolts.append([_bolt(from, targets[i]), PLUS_COLOR if plus[i] else MINUS_COLOR])
	parent.add_child(zap)

static func _bolt(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var steps := maxi(2, int(from.distance_to(to) / SEGMENT_LENGTH))
	var side := (to - from).normalized().orthogonal()
	for i in range(1, steps):
		points.append(from.lerp(to, float(i) / steps) + side * randf_range(-JAGGED, JAGGED))
	points.append(to)
	return points

func _process(delta: float) -> void:
	_age += delta
	if _age >= TIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var fade := 1.0 - _age / TIME
	for bolt in _bolts:
		draw_polyline(bolt[0], Color(bolt[1], fade), 7.0 * fade + 1.0)
		draw_polyline(bolt[0], Color(1, 1, 1, fade), 2.5 * fade + 0.5)
