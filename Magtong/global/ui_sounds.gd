extends Node
## Menu sounds (autoload UiSounds) on the SFX bus.
## Every button, slider and option button in the tree is hooked up automatically when it enters the tree:
## focus → move, press → confirm. Back and error are played by the menus themselves.
## Set the meta "no_ui_sound" on a control to leave it out.

enum Sound { MOVE, CONFIRM, BACK, ERROR }

const STREAMS: Dictionary[Sound, AudioStream] = {
	Sound.MOVE: preload("res://assets/sounds/ui/ui_move.ogg"),
	Sound.CONFIRM: preload("res://assets/sounds/ui/ui_confirm.ogg"),
	Sound.BACK: preload("res://assets/sounds/ui/ui_back.ogg"),
	Sound.ERROR: preload("res://assets/sounds/ui/ui_error.ogg"),
}
## Per-sound loudness, so the files (from different packs) sit together: move quietest, confirm clearest.
const VOLUME_DB: Dictionary[Sound, float] = {
	Sound.MOVE: -3.0,
	Sound.CONFIRM: 0.0,
	Sound.BACK: -9.0,
	Sound.ERROR: -7.0,
}
## A press usually moves focus too (new menu opens, clicked button grabs focus): skip that move sound.
const MOVE_QUIET_AFTER_PRESS_MS: int = 150
## Slider steps while dragging or holding a direction: at most one tick per this many ms.
const SLIDER_TICK_INTERVAL_MS: int = 60

var _players: Dictionary[Sound, AudioStreamPlayer] = {}
var _last_press_ms: int = -100000
var _last_slider_tick_ms: int = -100000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = STREAMS[sound]
		player.volume_db = VOLUME_DB[sound]
		player.bus = &"SFX"
		player.max_polyphony = 2
		add_child(player)
		_players[sound] = player
	get_tree().node_added.connect(_on_node_added)
	# the main scene's nodes enter the tree at startup before this _ready runs, so hook up what's already there
	_hook_existing.call_deferred(get_tree().root)
	# the first focus grab when the game starts shouldn't make a sound
	_last_press_ms = Time.get_ticks_msec() + 500

func play(sound: Sound) -> void:
	if sound == Sound.MOVE and Time.get_ticks_msec() - _last_press_ms < MOVE_QUIET_AFTER_PRESS_MS:
		return
	if sound == Sound.CONFIRM:
		_last_press_ms = Time.get_ticks_msec()
	_players[sound].play()

func _hook_existing(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_existing(child)

func _on_node_added(node: Node) -> void:
	if not node is Control or node.has_meta(&"no_ui_sound") or node.has_meta(&"_ui_sound_hooked"):
		return
	node.set_meta(&"_ui_sound_hooked", true)
	if node is BaseButton or node is Slider:
		node.focus_entered.connect(play.bind(Sound.MOVE))
	if node is OptionButton:
		# opening the popup is the press; picking an item confirms
		node.pressed.connect(play.bind(Sound.CONFIRM))
		node.item_selected.connect(func(_index: int): play(Sound.CONFIRM))
	elif node is BaseButton:
		node.pressed.connect(play.bind(Sound.CONFIRM))
	elif node is Slider:
		node.value_changed.connect(_on_slider_changed.bind(node))

func _on_slider_changed(_value: float, slider: Slider) -> void:
	# only player input: values set from code (e.g. loading settings) happen without focus
	if not slider.has_focus():
		return
	var now := Time.get_ticks_msec()
	if now - _last_slider_tick_ms < SLIDER_TICK_INTERVAL_MS:
		return
	_last_slider_tick_ms = now
	_players[Sound.MOVE].play()
