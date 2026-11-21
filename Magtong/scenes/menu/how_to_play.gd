extends MenuWindow
class_name HowToPlay
## How-to-play window of the main menu and the pause menu: the rules in a few lines and the controls for gamepad
## and keyboard (PlayerMapping's defaults).

const GAMEPAD_ICON: Texture2D = preload("res://assets/icons/gamepad.svg")
const KEYBOARD_ICON: Texture2D = preload("res://assets/icons/keyboard.svg")
const PLUS_HEX := "#ff5a4d" # FlipZap.PLUS_COLOR, readable on the dark panel
const MINUS_HEX := "#598cff" # FlipZap.MINUS_COLOR
const ICON_SIZE := Vector2(28, 28)
const TEXT_COLOR_DIM := Color(1, 1, 1, 0.75)

const RULES: Array[String] = [
	"Get the pucks into the other team's goal. Most goals when the time runs out wins, a tie goes to overtime: "
		+ "the next goal wins.",
	"Every puck is [color=%s]+[/color] or [color=%s]−[/color]. Hold a magnet: opposite poles pull the puck in, "
		+ "the same pole pushes it away.",
	"[b]Flip[/b] switches the pole of every puck close to you. [b]Surge[/b] is a short, strong burst of the magnet "
		+ "you're holding.",
]
## Button glyphs: Kenney "Input Prompts" (CC0), files in PROMPTS_DIR without the .svg. Face buttons are shown by
## position (face_button_south/east), Godot maps JOY_BUTTON_A/B by position on every controller.
const PROMPTS_DIR := "res://assets/icons/prompts/"
const GLYPH_SIZE := Vector2(32, 32)
## action, gamepad glyphs, keyboard glyphs ("/" = or)
const CONTROLS: Array = [
	["Move", ["xbox_stick_l"], ["keyboard_w", "keyboard_a", "keyboard_s", "keyboard_d"]],
	["[color=%s]+[/color] magnet", ["xbox_rt", "/", "xbox_rb"], ["keyboard_k"]],
	["[color=%s]−[/color] magnet", ["xbox_lt", "/", "xbox_lb"], ["keyboard_j"]],
	["Flip", ["face_button_south"], ["keyboard_space"]],
	["Surge (with a magnet held)", ["face_button_east"], ["keyboard_l"]],
	["Change skin (lobby)", ["xbox_dpad_horizontal"], ["keyboard_u", "/", "keyboard_o"]],
	["Menu", ["xbox_button_menu"], ["keyboard_escape"]],
]

func _init() -> void:
	super("How to Play")

func _build_content() -> void:
	var rules := VBoxContainer.new()
	rules.add_theme_constant_override(&"separation", 4)
	content.add_child(rules)
	content.add_theme_constant_override(&"separation", 10)
	for i in RULES.size():
		var text := RULES[i] % [PLUS_HEX, MINUS_HEX] if i == 1 else RULES[i]
		rules.add_child(_rich("•  " + text))
	content.add_child(HSeparator.new())
	content.add_child(_controls_grid())

func _controls_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 48)
	grid.add_theme_constant_override(&"v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_child(Control.new())
	grid.add_child(_device_header(GAMEPAD_ICON, "Gamepad"))
	grid.add_child(_device_header(KEYBOARD_ICON, "Keyboard"))
	for row in CONTROLS:
		var action: String = row[0]
		if action.contains("%s"):
			action = action % (PLUS_HEX if action.contains("+") else MINUS_HEX)
		grid.add_child(_rich(action, 0))
		grid.add_child(_glyphs(row[1]))
		grid.add_child(_glyphs(row[2]))
	return grid

func _glyphs(names: Array) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	for glyph_name: String in names:
		if glyph_name == "/":
			var slash := _label("/")
			slash.add_theme_color_override(&"font_color", TEXT_COLOR_DIM)
			box.add_child(slash)
			continue
		var rect := TextureRect.new()
		rect.texture = load(PROMPTS_DIR + glyph_name + ".svg")
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = GLYPH_SIZE
		box.add_child(rect)
	return box

func _device_header(icon: Texture2D, text: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	var rect := TextureRect.new()
	rect.texture = icon
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = ICON_SIZE
	box.add_child(rect)
	var label := _label(text)
	label.add_theme_color_override(&"font_color", TEXT_COLOR_DIM)
	box.add_child(label)
	return box

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

## min_width 0: as wide as the text (grid cells), otherwise wraps inside the panel
func _rich(text: String, min_width: int = -1) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = text
	if min_width == 0:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label
