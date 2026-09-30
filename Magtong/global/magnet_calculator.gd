class_name MagnetCalculator
extends Node

var magnet_bodies: Array[PlayerBody] = []
var pucks: Array[Puck] = []


func _physics_process(delta):
	for body in magnet_bodies:
		
		for puck in pucks:
			pass