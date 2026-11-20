extends Node2D

@export var sprite: Sprite2D
@export var player: PlayerBody
@export var plus_particles: CPUParticles2D
@export var minus_particles: CPUParticles2D
# speed of the spinning
var speed: float = 0.1
@export var settings: PlayerSettings = null
var target_speed: float
var mm: MatchManager
var shader_tweener: Tween
var punch_tween: Tween
## Flip and Surge look different (15.11): Flip shows its exact range as a crisp ring (FlipRing) and zaps lines
## to the flipped pucks (FlipZap); Surge ripples the distortion shader around the player and briefly grows the
## player sprite (the punch). Surge is global, so it stays a soft, fuzzy ripple; drawn rings, burst lines and
## crescents on it were tried and dropped (20.11): too busy, and a strong ripple makes the area unreadable.
const SURGE_RIPPLE_TIME: float = 0.45
const SURGE_RIPPLE_FORCE: float = 0.02
const RIPPLE_THICKNESS: float = 0.03
## the ring widens and its tint smears out while it fades, so it dissolves instead of just running out
const RIPPLE_END_THICKNESS: float = 0.12
const RIPPLE_BAND: float = 0.04
const RIPPLE_END_BAND: float = 0.1
const SURGE_PUNCH: float = 0.1
## Flip punches the player sprite too (20.11), a bit stronger than Surge
const FLIP_PUNCH: float = 0.2
## Surge's ring gets a hue of the magnet's color (blended into the distorted screen, fades with the ring),
## so it reads as "this magnet got stronger". More saturated than the Flip zap colors: blended into the green
## rink, a light red reads as orange, the orange team's color.
const SURGE_TINT: float = 0.85
const SURGE_PLUS_COLOR := Color(1.0, 0.1, 0.1)
const SURGE_MINUS_COLOR := Color(0.15, 0.4, 1.0)
## the ring wobbles instead of being a perfect circle (share of its radius), different on every Surge
const SURGE_WIGGLE: float = 0.04
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


func _on_player_body_flipped(pos: Vector2, puck_positions: PackedVector2Array, puck_plus: Array):
	# the same range check as Simulation._flip, on the state that showed the flip
	var targets := PackedVector2Array()
	var plus := []
	var range_sq := settings.flip_range * settings.flip_range
	var to_sim := player.get_parent() as Node2D
	for k in puck_positions.size():
		if to_sim.to_local(puck_positions[k]).distance_squared_to(to_sim.to_local(pos)) < range_sq:
			targets.append(puck_positions[k])
			plus.append(puck_plus[k])
	FlipZap.spawn(player, pos, targets, plus)
	# the flip range in global units, so the ring matches the real range at any zoom
	FlipRing.spawn(player, pos, to_sim.global_transform.basis_xform(Vector2(settings.flip_range, 0)).length())
	_punch(FLIP_PUNCH)


func _on_player_body_surged(_pos: Vector2, _pol: Simulation.Polarity):
	var tint_col := SURGE_PLUS_COLOR if _pol == Simulation.Polarity.POS else SURGE_MINUS_COLOR
	ring_tweener(SURGE_RIPPLE_TIME, SURGE_RIPPLE_FORCE, tint_col, SURGE_TINT)
	_punch(SURGE_PUNCH)

func _on_player_body_setup_completed(player_body:PlayerBody):
	mm = player_body.mm

## A distortion ring runs from where the Surge happened to the edge of the shader sprite, its push and tint
## fading out on the way (ends at force 0, so no ring stays behind). It runs on its own top level copy of the
## shader sprite, so it stays at the Surge spot instead of following the player.
func ring_tweener(time: float, force: float, tint_col := Color.BLACK, tint := 0.0):
	var source_bbc := pol_shader_sprite.get_parent() as BackBufferCopy
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = source_bbc.copy_mode
	bbc.top_level = true
	bbc.transform = source_bbc.global_transform
	var ripple := Sprite2D.new()
	ripple.texture = pol_shader_sprite.texture
	ripple.transform = pol_shader_sprite.transform
	var mat := pol_shader_sprite.material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("polarity", 0.0) # the aura stays on the player
	mat.set_shader_parameter("thickness", RIPPLE_THICKNESS)
	mat.set_shader_parameter("ripple_band", RIPPLE_BAND)
	mat.set_shader_parameter("ripple_col", tint_col)
	mat.set_shader_parameter("wiggle", SURGE_WIGGLE)
	mat.set_shader_parameter("wiggle_phase", randf() * TAU)
	ripple.material = mat
	bbc.add_child(ripple)
	add_child(bbc)
	var tween := bbc.create_tween().set_parallel()
	tween.tween_method(func(val): mat.set_shader_parameter("size", val), 0.05, 0.5, time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(val): mat.set_shader_parameter("thickness", val), RIPPLE_THICKNESS,
		RIPPLE_END_THICKNESS, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_method(func(val): mat.set_shader_parameter("ripple_band", val), RIPPLE_BAND,
		RIPPLE_END_BAND, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# force and tint hold a moment, then ease out smoothly instead of dropping off
	tween.tween_method(func(val): mat.set_shader_parameter("force", val), force, 0.0, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(val): mat.set_shader_parameter("ripple_tint", val), tint, 0.0, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(bbc.queue_free)

func _punch(amount: float) -> void:
	if punch_tween != null and punch_tween.is_running():
		punch_tween.kill()
	punch_tween = create_tween()
	punch_tween.tween_property(sprite, "scale", _sprite_base_scale * (1.0 + amount), 0.05).set_trans(Tween.TRANS_LINEAR)
	punch_tween.tween_property(sprite, "scale", _sprite_base_scale, 0.25).set_ease(Tween.EASE_OUT)