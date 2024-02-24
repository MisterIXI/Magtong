extends Node2D

@export var sprite: Sprite2D
@export var player: PlayerBody

# speed of the spinning
var speed: float = 0.1
@export var settings: PlayerSettings = null
var target_speed: float


# Called when the node enters the scene tree for the first time.
func _ready():
	target_speed = settings.viz_idle_speed


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	speed = move_toward(speed, target_speed, settings.viz_acc * delta)
	sprite.rotation += speed * delta


# Called when the player's polarity changes
func on_polarity_changed(new_pol):
	if new_pol == player.polarity.POS:
		target_speed = settings.viz_max_speed
	elif new_pol == player.polarity.NEG:
		target_speed = -settings.viz_max_speed
	else:
		if speed > 0:
			target_speed = settings.viz_idle_speed
		else:
			target_speed = -settings.viz_idle_speed
