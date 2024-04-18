extends Node
var tween: Tween
@onready var timer: Timer = $Timer
var countdown: int = 3
func _ready():
	print(get_node("/root/Node/Node").countdown)
