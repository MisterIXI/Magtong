class_name UiTheme
## The look of the menu windows (Settings, How to Play, Credits), the pause menu and the main menu's message box:
## "Rink Green" (picked 21.11 from three options). Built in code because the slider knob and the toggle switch are
## drawn here; UiTheme.window() builds it once and hands out the same Theme. Change the look with the colors below.

const PANEL := Color(0.02, 0.07, 0.03, 0.95)
const PANEL_SOLID := Color(0.03, 0.1, 0.04) # dropdown lists
## pale mint: stands out against the green rink behind the windows and against the dark panel
const PANEL_BORDER := Color(0.78, 1.0, 0.72, 0.9)
const PANEL_SHADOW := Color(0, 0, 0, 0.45)
const ACCENT := Color(0.0, 0.57, 0.06)
const ACCENT_HOVER := Color(0.08, 0.66, 0.12)
const ACCENT_PRESSED := Color(0.0, 0.46, 0.05)
const ACCENT_SHADE := Color(0.0, 0.36, 0.04) # bottom edge of buttons
const FOCUS := Color(0.78, 1.0, 0.35)
const TEXT := Color.WHITE
const TITLE := Color(0.85, 1.0, 0.8)
const TRACK := Color(0.13, 0.2, 0.14) # empty part of sliders, switch when off
const KNOB := Color.WHITE

static var _window: Theme

static func window() -> Theme:
	if _window == null:
		_window = _build()
	return _window

static func _build() -> Theme:
	var t := Theme.new()
	var panel := _flat(PANEL, 14)
	panel.set_border_width_all(3)
	panel.border_color = PANEL_BORDER
	panel.shadow_color = PANEL_SHADOW
	panel.shadow_size = 14
	panel.set_content_margin_all(24)
	t.set_stylebox(&"panel", &"Panel", panel)
	t.set_stylebox(&"panel", &"PanelContainer", panel)

	t.set_font_size(&"font_size", &"Label", 20)
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_type_variation(&"HeaderLarge", &"Label")
	t.set_font_size(&"font_size", &"HeaderLarge", 34)
	t.set_color(&"font_color", &"HeaderLarge", TITLE)
	t.set_font_size(&"normal_font_size", &"RichTextLabel", 18)
	t.set_font_size(&"bold_font_size", &"RichTextLabel", 18)
	t.set_color(&"default_color", &"RichTextLabel", TEXT)

	for type: StringName in [&"Button", &"OptionButton"]:
		t.set_stylebox(&"normal", type, _button(ACCENT, 5))
		t.set_stylebox(&"hover", type, _button(ACCENT_HOVER, 5))
		t.set_stylebox(&"pressed", type, _button(ACCENT_PRESSED, 2))
		t.set_stylebox(&"hover_pressed", type, _button(ACCENT_PRESSED, 2))
		t.set_stylebox(&"disabled", type, _button(Color(0.3, 0.3, 0.3), 5))
		t.set_stylebox(&"focus", type, _focus_ring())
		for color: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color",
				&"font_hover_pressed_color"]:
			t.set_color(color, type, TEXT)
	t.set_font_size(&"font_size", &"Button", 24)
	t.set_font_size(&"font_size", &"OptionButton", 20)

	var list := _flat(PANEL_SOLID, 8)
	list.set_border_width_all(2)
	list.border_color = ACCENT
	list.set_content_margin_all(6)
	t.set_stylebox(&"panel", &"PopupMenu", list)
	t.set_stylebox(&"hover", &"PopupMenu", _flat(ACCENT, 6))
	t.set_color(&"font_color", &"PopupMenu", TEXT)
	t.set_color(&"font_hover_color", &"PopupMenu", TEXT)
	t.set_font_size(&"font_size", &"PopupMenu", 20)
	t.set_constant(&"v_separation", &"PopupMenu", 10)

	t.set_stylebox(&"slider", &"HSlider", _bar(TRACK))
	t.set_stylebox(&"grabber_area", &"HSlider", _bar(ACCENT))
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", _bar(ACCENT_HOVER))
	t.set_icon(&"grabber", &"HSlider", _circle(22, KNOB, ACCENT, 3.0))
	t.set_icon(&"grabber_highlight", &"HSlider", _circle(26, KNOB, FOCUS, 4.0))

	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(4)
	for style: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		t.set_stylebox(style, &"CheckButton", empty)
	t.set_stylebox(&"focus", &"CheckButton", _focus_ring())
	t.set_icon(&"checked", &"CheckButton", _switch(true))
	t.set_icon(&"unchecked", &"CheckButton", _switch(false))

	var line := StyleBoxLine.new()
	line.color = Color(PANEL_BORDER, 0.4)
	line.thickness = 2
	t.set_stylebox(&"separator", &"HSeparator", line)
	t.set_stylebox(&"grabber", &"VScrollBar", _flat(ACCENT, 4))
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", _flat(ACCENT_HOVER, 4))
	t.set_stylebox(&"scroll", &"VScrollBar", _flat(TRACK, 4))
	return t

static func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box

## rounded button with a darker bottom edge (thinner while pressed, so it looks pushed in)
static func _button(color: Color, edge: int) -> StyleBoxFlat:
	var box := _flat(color, 8)
	box.border_width_bottom = edge
	box.border_color = ACCENT_SHADE
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 5
	box.content_margin_bottom = 7 + (5 - edge)
	return box

static func _focus_ring() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_corner_radius_all(10)
	box.set_border_width_all(3)
	box.border_color = FOCUS
	box.set_expand_margin_all(3)
	return box

## slider track: the content margins set its thickness
static func _bar(color: Color) -> StyleBoxFlat:
	var box := _flat(color, 4)
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box

## antialiased disc with a ring (slider knob)
static func _circle(size: int, fill: Color, ring: Color, ring_width: float) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) / 2.0
	var radius := size / 2.0 - 0.5
	for y in size:
		for x in size:
			var distance := Vector2(x - center, y - center).length()
			var alpha := clampf(radius - distance + 0.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var color := fill if distance < radius - ring_width else ring
			color.a *= alpha
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

## toggle switch: a pill in the accent (on) or track color (off) with the knob on the right / left
static func _switch(on: bool) -> ImageTexture:
	var width := 50
	var height := 26
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var radius := height / 2.0
	var knob_x := width - radius if on else radius
	var track := ACCENT if on else TRACK
	for y in height:
		for x in width:
			var pixel := Vector2(x + 0.5, y + 0.5)
			var on_axis := Vector2(clampf(pixel.x, radius, width - radius), radius)
			var alpha := clampf(radius - pixel.distance_to(on_axis), 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var knob := clampf(radius - 4.0 - pixel.distance_to(Vector2(knob_x, radius)), 0.0, 1.0)
			var color := track.lerp(KNOB, knob)
			color.a *= alpha
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
