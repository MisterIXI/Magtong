extends MenuWindow
class_name Credits
## Credits window of the main menu: who made what, and the licenses that must ship with the game (Godot's own text
## and its third-party list come from Engine, GodotSteam's MIT text is below). Sources: assets/sounds/LICENSES.md,
## assets/icons/links.md. Up / down (and the mouse wheel) scroll; Back is the only button.

const SCROLL_SPEED: float = 500.0 # px per second at full stick / held key
const LICENSE_FONT_SIZE: int = 13

const CREDITS := """[center][font_size=28][b]Magtong[/b][/font_size]
A game by Oberwald Studios

[b]Music[/b]
"Game Music (Credits 2)" by AlesiaDavina (Pixabay)
"Cheerful Annoyance" by Kenney (kenney.nl, CC0)

[b]Sound effects[/b]
Kenney (kenney.nl, CC0): UI Pack, Interface Sounds, Impact Sounds, Sci-Fi Sounds
"Air horn sound effect" by DRAGON-STUDIO (Pixabay)

[b]Icons[/b]
Button prompts: "Input Prompts" by Kenney (kenney.nl, CC0)
Gamepad and keyboard icons by Delapouite (game-icons.net, CC BY 3.0, creativecommons.org/licenses/by/3.0)

[b]Made with[/b]
Godot Engine (godotengine.org)
GodotSteam by GP Garcia, Chris Ridenour and contributors (godotsteam.com)

Thank you for playing![/center]
"""

const GODOTSTEAM_LICENSE := """MIT License

Copyright (c) 2015-Current | GP Garcia, Chris Ridenour, and Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated \
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the \
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit \
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the \
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE \
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR \
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR \
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."""

var _scroll: ScrollContainer

func _init() -> void:
	super("Credits")

func _build_content() -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = Control.FOCUS_NONE
	content.add_child(_scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.focus_mode = Control.FOCUS_NONE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = CREDITS + "\n" + _licenses()
	_scroll.add_child(text)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var direction := Input.get_axis(&"ui_up", &"ui_down")
	if direction != 0.0:
		_scroll.scroll_vertical += int(direction * SCROLL_SPEED * delta)

func _licenses() -> String:
	var out := "[font_size=%d][center][b]Licenses[/b][/center]\n\n" % LICENSE_FONT_SIZE
	out += "[b]Godot Engine[/b]\n" + _escape(Engine.get_license_text()) + "\n\n"
	out += "[b]GodotSteam[/b]\n" + _escape(GODOTSTEAM_LICENSE) + "\n\n"
	out += "[b]Third-party components in Godot Engine[/b]\n"
	for component: Dictionary in Engine.get_copyright_info():
		var lines: PackedStringArray = []
		for part: Dictionary in component["parts"]:
			for holder: String in part["copyright"]:
				lines.append("© " + holder)
			lines.append("License: " + str(part["license"]))
		out += "%s: %s\n" % [_escape(component["name"]), _escape(", ".join(lines))]
	out += "\nThe full license texts of these components are part of the Godot Engine source " \
		+ "(github.com/godotengine/godot, COPYRIGHT.txt and thirdparty/).[/font_size]"
	return out

func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
