extends Control
class_name SettingsMenu
## Settings panel of the main menu and the pause menu. Shows the values of the Settings autoload and changes them.
## The owner shows and hides it; the X button emits `closed`.

signal closed

@export var master_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider
@export var window_mode_option: OptionButton
@export var vsync_check: CheckButton
@export var anti_aliasing_option: OptionButton

func _ready() -> void:
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

## Focus for gamepad / keyboard navigation when the panel opens.
func focus_first() -> void:
	master_slider.grab_focus.call_deferred()

## Values may have changed elsewhere (the other instance), so refresh them when the panel opens.
func refresh() -> void:
	master_slider.set_value_no_signal(Settings.get_volume("Master"))
	music_slider.set_value_no_signal(Settings.get_volume("Music"))
	sfx_slider.set_value_no_signal(Settings.get_volume("SFX"))
	window_mode_option.select(Settings.get_window_mode())
	vsync_check.set_pressed_no_signal(Settings.get_vsync())
	anti_aliasing_option.select(Settings.get_anti_aliasing())

func close() -> void:
	closed.emit()

func _bind_volume(slider: HSlider, bus: String) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.get_volume(bus)
	slider.value_changed.connect(func(value: float): Settings.set_volume(bus, value))
