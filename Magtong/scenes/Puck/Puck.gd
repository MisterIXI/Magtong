extends RigidBody2D
class_name Puck

@export var plus_sprite: Sprite2D
@export var minus_sprite: Sprite2D
var is_plus_pol: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pass  # Replace with function body.

@rpc("authority", "call_local", "reliable")
func reset(new_forced_pos: Vector2):
	receive_pulse(true)
	linear_velocity = Vector2(0, 0)
	angular_velocity = 0
	if is_multiplayer_authority():
		PhysicsServer2D.body_set_state(
			get_rid(),
			PhysicsServer2D.BODY_STATE_TRANSFORM,
			Transform2D.IDENTITY.translated(new_forced_pos)
		)

@rpc("authority", "call_local", "reliable")
func receive_pulse(is_now_plus_pol: bool):
	if is_now_plus_pol:
		plus_sprite.show()
		minus_sprite.hide()
		is_plus_pol = true
	else:
		plus_sprite.hide()
		minus_sprite.show()
		is_plus_pol = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
