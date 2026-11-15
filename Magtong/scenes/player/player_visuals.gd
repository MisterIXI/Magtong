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
var ability_rings: AbilityRings
## the polarity color follows the magnet almost at once, so what you see is what pulls (playtest 15.11: the
## old 0.2 s fade made a player look plus while already pushing as minus)
const POLARITY_FADE_TIME: float = 0.05
@export var pol_shader_sprite: Sprite2D
# Called when the node enters the scene tree for the first time.
func _ready():
	target_speed = settings.viz_idle_speed
	# on the player, not on this scaled node, so the flip ring matches the real flip range
	ability_rings = AbilityRings.new()
	ability_rings.flip_range = settings.flip_range
	ability_rings.punch_target = sprite
	player.add_child.call_deferred(ability_rings)


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
	ring_tweener()
	ability_rings.play_flip()


func _on_player_body_surged(_pos: Vector2, _pol: Simulation.Polarity):
	if _pol == Simulation.Polarity.POS:
		plus_burst_particles.emitting = true
	else:
		minus_burst_particles.emitting = true
	ring_tweener()
	ability_rings.play_surge(_pol)

func _on_player_body_setup_completed(player_body:PlayerBody):
	mm = player_body.mm

func ring_tweener():
	if ring_tween != null and ring_tween.is_running():
		ring_tween.kill()
	ring_tween = create_tween()
	ring_tween.tween_method(
		func(val): pol_shader_sprite.material.set_shader_parameter("size", val),
		0.0,
		0.5,
		0.3
	)
	ring_tween.parallel()
	ring_tween.tween_method(
		func(val): pol_shader_sprite.material.set_shader_parameter("thickness", val),
		0.3,
		-0.2,
		0.3
	)
	ring_tween.play()