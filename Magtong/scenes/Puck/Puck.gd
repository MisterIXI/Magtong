extends RigidBody2D
class_name Puck

@export var plus_sprite: Sprite2D
@export var minus_sprite: Sprite2D
var is_plus_pol: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pass  # Replace with function body.

func reset(new_forced_pos: Vector2):
	plus_sprite.show()
	minus_sprite.hide()
	is_plus_pol = true
	linear_velocity = Vector2(0, 0)
	angular_velocity = 0
	PhysicsServer2D.body_set_state(
		get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D.IDENTITY.translated(new_forced_pos)
	)

func receive_pulse():
	if is_plus_pol:
		plus_sprite.hide()
		minus_sprite.show()
		is_plus_pol = false
	else:
		plus_sprite.show()
		minus_sprite.hide()
		is_plus_pol = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
