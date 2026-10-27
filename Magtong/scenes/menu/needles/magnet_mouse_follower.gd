extends Node2D
@export var particle_asset: PackedScene

func _input(event):
	if event is InputEventMouseMotion:
		position = event.position
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			spawning = event.pressed
			if event.pressed:
				pass
			else:
				pass

var spawning: bool = false
var cooldown: float = 0
const COOLDOWN_TIME = 0.01

func _physics_process(delta):
	if not spawning:
		return
	cooldown -= delta
	if cooldown <= 0:
		cooldown = COOLDOWN_TIME
		spawn_particle()

func spawn_particle():
	var particle = particle_asset.instantiate()
	get_parent().add_child(particle)
	var offset = Vector2(randf()-0.5, randf()-0.5) * 550
	particle.position = position + offset