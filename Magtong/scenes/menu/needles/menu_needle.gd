extends Sprite2D

var parent: MagneticField2D

func _ready():
	parent = get_parent()

func _physics_process(_delta):
	var field = parent.calculate_field_at_point(global_position)
	var angle = field.angle_to(Vector2.RIGHT)
	rotation = -angle