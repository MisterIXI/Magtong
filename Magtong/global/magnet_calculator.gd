class_name MagnetCalculator
extends Node

var magnet_bodies: Array[PlayerBody] = []
var pucks: Array[Puck] = []
@onready var settings: MagnetSettings = GlobGameManager.magnet_settings
var is_active: bool = false

func add_magnet_body(body: PlayerBody) -> void:
	if magnet_bodies.has(body):
		push_warning("tried adding a body multiple times")
		return
	magnet_bodies.append(body)

func remove_magnet_body(body: PlayerBody) -> void:
	if magnet_bodies.has(body):
		magnet_bodies.erase(body)

func add_puck(puck: Puck) -> void:
	if pucks.has(puck):
		push_warning("tried adding a puck multiple times")
		return
	pucks.append(puck)

func remove_puck(puck: Puck) -> void:
	if pucks.has(puck):
		pucks.erase(puck)

func clear_all() -> void:
	pucks.clear()
	magnet_bodies.clear()

func _physics_process(_delta):
	if not is_active:
		return
	for body in magnet_bodies:
		# skip if neutral
		if body.magnet_state == Type.MagnetState.Neutral:
			continue
		# apply force to every puck
		for puck in pucks:
			var direction: Vector2 = puck.global_position - body.global_position
			direction = direction.normalized()
			var dist: float = puck.global_position.distance_to(body.global_position)
			var force_mult: float = settings.magnet_dropoff.sample(dist / settings.magnet_range)
			var scaled_force: Vector2 = direction * force_mult * settings.magnet_force
			puck.apply_central_force(scaled_force)
			body.apply_central_force(-scaled_force)
			# puck.apply_central_force()
		# # apply force to every other body
		# for other_body in magnet_bodies:
		# 	# skip self
		# 	if body == other_body:
		# 		continue