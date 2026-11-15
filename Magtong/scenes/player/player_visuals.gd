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
var ring_tween: Tween
var punch_tween: Tween
## Flip and Surge show as a ripple of the distortion shader around the player (15.11: big drawn rings were
## too intrusive). Surge is the heavier one and also punches the sprite.
const FLIP_RIPPLE_TIME: float = 0.25
const FLIP_RIPPLE_FORCE: float = 0.1
const SURGE_RIPPLE_TIME: float = 0.4
const SURGE_RIPPLE_FORCE: float = 0.16
const RIPPLE_THICKNESS: float = 0.12
const SURGE_PUNCH: float = 0.2
var _sprite_base_scale: Vector2
## the polarity color follows the magnet almost at once, so what you see is what pulls (playtest 15.11: the
## old 0.2 s fade made a player look plus while already pushing as minus)
const POLARITY_FADE_TIME: float = 0.05
@export var pol_shader_sprite: Sprite2D
# Called when the node enters the scene tree for the first time.
func _ready():
	target_speed = settings.viz_idle_speed
	_sprite_base_scale = sprite.scale


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	speed = move_toward(speed, target_speed, settings.viz_acc * delta)
	sprite.rotation += speed * delta

# Called when the player's polarity changes
func on_polarity_changed(new_pol):
	if new_pol == Simulation.Polarity.POS:
		target_speed = settings.viz_max_speed
		plus_particles.emitting = true
		minus_particles.emitting = false

	elif new_pol == Simulation.Polarity.NEG:
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
		0.5 if new_pol == Simulation.Polarity.POS else -0.5 if new_pol == Simulation.Polarity.NEG else 0.0,
		POLARITY_FADE_TIME
	)
	shader_tweener.play()


func _on_player_body_flipped(_pos: Vector2):
	# both are one_shot, so they will stop emitting by themselves
	plus_burst_particles.emitting = true
	minus_burst_particles.emitting = true
	ring_tweener(FLIP_RIPPLE_TIME, FLIP_RIPPLE_FORCE)


func _on_player_body_surged(_pos: Vector2, _pol: Simulation.Polarity):
	if _pol == Simulation.Polarity.POS:
		plus_burst_particles.emitting = true
	else:
		minus_burst_particles.emitting = true
	ring_tweener(SURGE_RIPPLE_TIME, SURGE_RIPPLE_FORCE)
	_punch()

func _on_player_body_setup_completed(player_body:PlayerBody):
	mm = player_body.mm

## A distortion ring runs from the player to the edge of the shader sprite, its push fading out on the way
## (ends at force 0, so no ring stays behind).
func ring_tweener(time: float, force: float):
	if ring_tween != null and ring_tween.is_running():
		ring_tween.kill()
	var mat: ShaderMaterial = pol_shader_sprite.material
	mat.set_shader_parameter("thickness", RIPPLE_THICKNESS)
	ring_tween = create_tween()
	ring_tween.tween_method(func(val): mat.set_shader_parameter("size", val), 0.05, 0.5, time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.parallel()
	ring_tween.tween_method(func(val): mat.set_shader_parameter("force", val), force, 0.0, time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ring_tween.play()

func _punch() -> void:
	if punch_tween != null and punch_tween.is_running():
		punch_tween.kill()
	sprite.scale = _sprite_base_scale * (1.0 + SURGE_PUNCH)
	punch_tween = create_tween()
	punch_tween.tween_property(sprite, "scale", _sprite_base_scale, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)