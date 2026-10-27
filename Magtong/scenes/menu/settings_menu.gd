extends Control
class_name SettingsMenu
## Settings panel of the main menu. Shows the values of the Settings autoload and changes them.

@export var master_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider
@export var window_mode_option: OptionButton
@export var vsync_check: CheckButton

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

func _bind_volume(slider: HSlider, bus: String) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.get_volume(bus)
	slider.value_changed.connect(func(value: float): Settings.set_volume(bus, value))
