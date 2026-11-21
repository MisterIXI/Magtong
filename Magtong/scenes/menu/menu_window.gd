extends Control
class_name MenuWindow
## Base of the menu windows (Settings, How to Play, Credits): the same dark panel, title, content area and Back
## button everywhere, styled by resources/window_theme.tres. Subclasses fill `content` in _build_content().
## The owner (main menu / pause menu) shows and hides it, handles B / Esc and listens to `closed`.

signal closed

const THEME: Theme = preload("res://resources/window_theme.tres")
## the panel's distance to the screen edges (1280x720 canvas)
const PANEL_MARGIN := Vector2(140, 40)

var title: String = ""
var content: VBoxContainer
var back_button: Button

func _init(window_title: String) -> void:
	title = window_title

func _ready() -> void:
	theme = THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = PANEL_MARGIN.x
	panel.offset_top = PANEL_MARGIN.y
	panel.offset_right = -PANEL_MARGIN.x
	panel.offset_bottom = -PANEL_MARGIN.y
	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(side, 60)
	for side in [&"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 16)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = title
	title_label.theme_type_variation = &"HeaderLarge"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title_label)

	content = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(content)
	_build_content()

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(240, 0)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.set_meta(&"ui_sound_back", true) # UiSounds: the same sound as B / Esc
	back_button.pressed.connect(close)
	stack.add_child(back_button)

## Override: add the window's controls to `content`.
func _build_content() -> void:
	pass

## Focus for gamepad / keyboard navigation when the window opens. Override to focus the first control.
func focus_first() -> void:
	back_button.grab_focus.call_deferred()

func close() -> void:
	closed.emit()
