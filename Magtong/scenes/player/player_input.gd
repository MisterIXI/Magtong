class_name PlayerInput
extends Node

var listening: bool = false
var device_id: int = 0

func _input(event):
	if not listening:
		return
	if event.device == device_id:
		pass