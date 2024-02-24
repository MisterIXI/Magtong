extends Node2D

@export var sprite: Sprite2D
@export var player: PlayerBody

# speed of the spinning
var speed: float = 0.1
@export var idle_speed: float = 0.1
@export var spin_change_speed: float = 0.1


# Called when the node enters the scene tree for the first time.
func _ready():
	pass  # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# get player state
	if player.current_state == player.state.IDLE:
		# idle lazy spinning
		if speed > 0:
			# move speed towards positive
			speed = move_toward(speed, idle_speed, spin_change_speed * delta)
		pass
	pass
