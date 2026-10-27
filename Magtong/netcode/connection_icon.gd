extends CanvasLayer
class_name ConnectionIcon
## Connection problem icon (crossed out wifi symbol, top right). Shown while a peer has not been heard
## from for a while, so a stalled game does not look like a freeze. Added by globNet.

const TEXTURE: Texture2D = preload("res://assets/Icons/connection_lost.svg")
const SIZE: float = 48.0
const MARGIN: float = 16.0
const PULSE_SPEED: float = 4.0

var _icon: TextureRect
var _time: float = 0.0

func _init() -> void:
	layer = 100
	_icon = TextureRect.new()
	_icon.texture = TEXTURE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_icon.size = Vector2(SIZE, SIZE)
	_icon.position = Vector2(-SIZE - MARGIN, MARGIN)
	add_child(_icon)
	visible = false

func set_shown(shown: bool) -> void:
	if shown and not visible:
		_time = 0.0
	visible = shown

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_icon.modulate.a = lerpf(0.5, 1.0, 0.5 + 0.5 * cos(_time * PULSE_SPEED))
