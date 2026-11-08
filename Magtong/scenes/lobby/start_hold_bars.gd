extends Node2D
class_name StartHoldBars
## Lobby hold-to-start bars below a player: red (plus magnet) fills from the left, blue (minus magnet) from the
## right, they meet in the middle when both are full. Only shows the simulation's start_hold_* values.

const PLUS_COLOR := Color(1, 0, 0) # pos_col of the magnet aura
const MINUS_COLOR := Color(0, 0.35, 1) # neg_col, a bit lighter so it reads on the dark frame
const FRAME_COLOR := Color(0, 0, 0, 0.6)
const FULL_FRAME_COLOR := Color(1, 1, 1, 0.9)
const SIZE := Vector2(76, 14)
const BORDER: float = 2.0
const OFFSET_Y: float = 46.0 # below the player, the ready banner covers the area above

var plus: float = 0.0
var minus: float = 0.0

func _init() -> void:
	name = "StartHoldBars"
	z_index = 100
	visible = false

## plus and minus are 0..1.
func set_progress(new_plus: float, new_minus: float) -> void:
	if is_equal_approx(new_plus, plus) and is_equal_approx(new_minus, minus):
		return
	plus = new_plus
	minus = new_minus
	queue_redraw()

func _draw() -> void:
	var full := plus >= 1.0 and minus >= 1.0
	var outer := Rect2(Vector2(-SIZE.x / 2.0, OFFSET_Y - SIZE.y / 2.0), SIZE)
	draw_rect(outer.grow(BORDER), FULL_FRAME_COLOR if full else FRAME_COLOR)
	var half := SIZE.x / 2.0
	if plus > 0.0:
		draw_rect(Rect2(outer.position, Vector2(half * plus, SIZE.y)), PLUS_COLOR)
	if minus > 0.0:
		var width := half * minus
		draw_rect(Rect2(Vector2(outer.end.x - width, outer.position.y), Vector2(width, SIZE.y)), MINUS_COLOR)
