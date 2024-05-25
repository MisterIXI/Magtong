extends Node
class_name AbilityBase

@export var ability_name: String
@export var player: PlayerBody
var map: MapScript

func setup(map: MapScript):
	self.map = map

func _ability_button_down():
	pass

func _ability_button_up():
	pass

func _ability_reset():
	pass

