extends MenuWindow
class_name SettingsMenu
## Settings window of the main menu and the pause menu. Shows the values of the Settings autoload and changes them.

const CONTROL_WIDTH: float = 420.0

var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var window_mode_option: OptionButton
var vsync_check: CheckButton
var anti_aliasing_option: OptionButton

func _init() -> void:
	super("Settings")

func _build_content() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 50)
	grid.add_theme_constant_override(&"v_separation", 26)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	content.add_child(grid)
	master_slider = _row(grid, "Master Volume", HSlider.new())
	sfx_slider = _row(grid, "SFX Volume", HSlider.new())
	music_slider = _row(grid, "Music Volume", HSlider.new())
	window_mode_option = _row(grid, "Window Mode", OptionButton.new())
	vsync_check = _row(grid, "VSync", CheckButton.new())
	anti_aliasing_option = _row(grid, "Anti-Aliasing", OptionButton.new())

	_bind_volume(master_slider, "Master")
	_bind_volume(music_slider, "Music")
	_bind_volume(sfx_slider, "SFX")
	for i in Settings.WINDOW_MODE_NAMES.size():
		window_mode_option.add_item(Settings.WINDOW_MODE_NAMES[i], i)
	window_mode_option.select(Settings.get_window_mode())
	window_mode_option.item_selected.connect(func(index: int): Settings.set_window_mode(index))
	vsync_check.button_pressed = Settings.get_vsync()
	vsync_check.toggled.connect(Settings.set_vsync)
	for i in Settings.ANTI_ALIASING_NAMES.size():
		anti_aliasing_option.add_item(Settings.ANTI_ALIASING_NAMES[i], i)
	anti_aliasing_option.select(Settings.get_anti_aliasing())
	anti_aliasing_option.item_selected.connect(Settings.set_anti_aliasing)

func focus_first() -> void:
	master_slider.grab_focus.call_deferred()

## Values may have changed elsewhere (the other instance), so refresh them when the window opens.
func refresh() -> void:
	master_slider.set_value_no_signal(Settings.get_volume("Master"))
	music_slider.set_value_no_signal(Settings.get_volume("Music"))
	sfx_slider.set_value_no_signal(Settings.get_volume("SFX"))
	window_mode_option.select(Settings.get_window_mode())
	vsync_check.set_pressed_no_signal(Settings.get_vsync())
	anti_aliasing_option.select(Settings.get_anti_aliasing())

func _row(grid: GridContainer, text: String, control: Control) -> Control:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	control.custom_minimum_size.x = CONTROL_WIDTH
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if control is CheckButton:
		control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		control.custom_minimum_size.x = 0
	grid.add_child(control)
	return control

func _bind_volume(slider: HSlider, bus: String) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.get_volume(bus)
	slider.value_changed.connect(func(value: float): Settings.set_volume(bus, value))
