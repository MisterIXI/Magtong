extends Node2D

@export var sprite: Sprite2D
@export var player: PlayerBody
@export var plus_particles: CPUParticles2D
@export var minus_particles: CPUParticles2D
@export var plus_burst_particles: CPUParticles2D
@export var minus_burst_particles: CPUParticles2D
# speed of the spinning
var speed: float = 0.1
@export var settings: PlayerSettings = null
var target_speed: float
var mm: MatchManager
var shader_tweener: Tween
var pulse_tween: Tween
@export var pol_shader_sprite: Sprite2D
# Called when the node enters the scene tree for the first time.
func _ready():
	target_speed = settings.viz_idle_speed


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	speed = move_toward(speed, target_speed, settings.viz_acc * delta)
	sprite.rotation += speed * delta

# Called when the player's polarity changes
func on_polarity_changed(new_pol):
	if new_pol == player.Polarity.POS:
		target_speed = settings.viz_max_speed
		plus_particles.emitting = true
		minus_particles.emitting = false

	elif new_pol == player.Polarity.NEG:
		target_speed = -settings.viz_max_speed
		plus_particles.emitting = false
		minus_particles.emitting = true
	else:
		if speed > 0:
			target_speed = settings.viz_idle_speed
		else:
			target_speed = -settings.viz_idle_speed
		plus_particles.emitting = false
		minus_particles.emitting = false

	if shader_tweener:
		shader_tweener.kill()
	shader_tweener = create_tween()
	var pol_initial = pol_shader_sprite.material.get_shader_parameter("polarity")
	shader_tweener.tween_method(
		func(val): pol_shader_sprite.material.set_shader_parameter("polarity", val),
		pol_initial,
		0.5 if new_pol == player.Polarity.POS else -0.5 if new_pol == player.Polarity.NEG else 0.0,
		0.2
	)
	shader_tweener.play()


func _on_player_body_pulse_emitted(_pos: Vector2):
	# both are one_shot, so they will stop emitting by themselves
	plus_burst_particles.emitting = true
	minus_burst_particles.emitting = true
	pulse_tweener()


func _on_player_impulse_emitted(_pos: Vector2, _pol: PlayerBody.Polarity):
	if _pol == player.Polarity.POS:
		plus_burst_particles.emitting = true
	else:
		minus_burst_particles.emitting = true
	pulse_tweener()

func _on_player_body_setup_completed(player_body:PlayerBody):
	mm = player_body.mm

func pulse_tweener():
	if pulse_tween != null and pulse_tween.is_running():
		pulse_tween.kill()
	pulse_tween = create_tween()
	pulse_tween.tween_method(
		func(val): pol_shader_sprite.material.set_shader_parameter("size", val),
		0.0,
		0.5,
		0.3
	)
	pulse_tween.parallel()
	pulse_tween.tween_method(
		func(val): pol_shader_sprite.material.set_shader_parameter("thickness", val),
		0.3,
		-0.2,
		0.3
	)
	pulse_tween.play()