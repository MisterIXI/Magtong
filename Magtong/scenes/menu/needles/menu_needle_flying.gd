extends RigidBody2D

var parent: MagneticField2D

# Called when the node enters the scene tree for the first time.
func _ready():
	parent = get_parent()


func _physics_process(delta):
	var field = parent.calculate_field_at_point(global_position)
	# add angular velocity towards correct orientation
	var target_angle = -field.angle_to(Vector2.RIGHT)
	# figure out the angular velocity needed to reach the target angle in 0.5s
	var angle_diff = target_angle - rotation
	var new_vel = angle_diff / 0.5
	angular_velocity = move_toward(angular_velocity, new_vel, 5)
	apply_central_force(field * 50000000)