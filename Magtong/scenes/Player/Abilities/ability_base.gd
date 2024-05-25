extends Node2D
class_name AbilityBase

@export var ability_name: String
@export var player: PlayerBody
var map: MapScript
var settings: PlayerSettings

func setup(map: MapScript):
	self.map = map
	settings = globResourceManager.player_settings
	_setup()

func _setup():
	pass

func _ability_button_down():
	pass

func _ability_button_up():
	pass

func _ability_reset():
	pass
