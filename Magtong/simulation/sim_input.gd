class_name SimInput
## The input of one player for one tick, packed into a single int so it can be stored per tick
## and sent over the network cheaply.
## bits 0-7: move x, bits 8-15: move y (signed, -AXIS_MAX..AXIS_MAX), bits 16+: held buttons

const AXIS_MAX: int = 127

# button bits
const PLUS: int = 1 << 0
const MINUS: int = 1 << 1
const PRIMARY: int = 1 << 2
const SECONDARY: int = 1 << 3
const MENU: int = 1 << 4
const AUX_LEFT: int = 1 << 5
const AUX_RIGHT: int = 1 << 6

const EMPTY: int = 0

static func encode(move: Vector2, buttons: int) -> int:
	var x := clampi(roundi(move.x * AXIS_MAX), -AXIS_MAX, AXIS_MAX)
	var y := clampi(roundi(move.y * AXIS_MAX), -AXIS_MAX, AXIS_MAX)
	return (x & 0xFF) | ((y & 0xFF) << 8) | (buttons << 16)

static func get_move(input: int) -> Vector2:
	return Vector2(_signed_byte(input & 0xFF), _signed_byte((input >> 8) & 0xFF)) / AXIS_MAX

static func get_buttons(input: int) -> int:
	return input >> 16

static func _signed_byte(value: int) -> int:
	return value - 256 if value > 127 else value
