extends Node
## Player settings (autoload Settings), saved to user://settings.cfg and applied at startup.
## Volumes are linear 0..1 per audio bus (Master, Music, SFX from default_bus_layout.tres).

const PATH: String = "user://settings.cfg"
const VOLUME_BUSES: Array[String] = ["Master", "Music", "SFX"]

enum WindowMode { WINDOWED, FULLSCREEN, EXCLUSIVE_FULLSCREEN }
const WINDOW_MODE_NAMES: Array[String] = ["Windowed", "Fullscreen", "Exclusive Fullscreen"]

var _config := ConfigFile.new()

func _ready() -> void:
	_config.load(PATH) # a missing file just means defaults
	for bus in VOLUME_BUSES:
		_apply_volume(bus, get_volume(bus))
	_apply_window_mode(get_window_mode())
	_apply_vsync(get_vsync())

func get_volume(bus: String) -> float:
	return _config.get_value("audio", bus.to_lower(), 0.8)

func set_volume(bus: String, value: float) -> void:
	_config.set_value("audio", bus.to_lower(), clampf(value, 0.0, 1.0))
	_apply_volume(bus, value)
	_save()

func get_window_mode() -> WindowMode:
	return _config.get_value("display", "window_mode", WindowMode.WINDOWED)

func set_window_mode(mode: WindowMode) -> void:
	_config.set_value("display", "window_mode", mode)
	_apply_window_mode(mode)
	_save()

func get_vsync() -> bool:
	return _config.get_value("display", "vsync", true)

func set_vsync(enabled: bool) -> void:
	_config.set_value("display", "vsync", enabled)
	_apply_vsync(enabled)
	_save()

func _apply_volume(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		push_warning("audio bus %s is missing" % bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(value))
	AudioServer.set_bus_mute(index, value <= 0.0)

func _apply_window_mode(mode: WindowMode) -> void:
	if DisplayServer.get_name() == "headless":
		return
	match mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_vsync(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)

func _save() -> void:
	var err := _config.save(PATH)
	if err != OK:
		push_warning("could not save settings: %s" % error_string(err))
