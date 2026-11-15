extends Node2D
class_name Puck
## Visual representation of one simulated puck.

@export var plus_sprite: Sprite2D
@export var minus_sprite: Sprite2D
var is_plus_pol: bool = true
var _last_reset_tick: int = -2 # so the first update always resets the interpolation
## a flipped puck pops and flashes a ring, so you see which pucks a Flip caught
const FLIP_POP_TIME: float = 0.35
const FLIP_POP_SCALE: float = 0.6
var _pop_age: float = -1.0

## Called every tick after the simulation stepped.
func update_from_sim(sim_state: SimState, body: int) -> void:
	position = sim_state.pos[body]
	rotation = sim_state.puck_angle[body]
	var was_reset := sim_state.reset_tick != _last_reset_tick
	if was_reset:
		_last_reset_tick = sim_state.reset_tick
		reset_physics_interpolation()
	# the scoring puck is out of play during the goal celebration, the explosion takes its place
	visible = not (sim_state.phase == Simulation.Phase.GOAL and sim_state.goal_puck == body)
	var plus := sim_state.puck_plus[body] == 1
	if plus != is_plus_pol:
		set_polarity(plus)
		if not was_reset:
			_pop_age = 0.0

func _process(delta: float) -> void:
	if _pop_age < 0.0:
		return
	_pop_age += delta
	var t := _pop_age / FLIP_POP_TIME
	if t >= 1.0:
		_pop_age = -1.0
		scale = Vector2.ONE
	else:
		scale = Vector2.ONE * (1.0 + FLIP_POP_SCALE * sin(t * PI) * (1.0 - t))
	queue_redraw()

func _draw() -> void:
	if _pop_age < 0.0:
		return
	var t := _pop_age / FLIP_POP_TIME
	draw_arc(Vector2.ZERO, 18.0 + 22.0 * t, 0.0, TAU, 32, Color(1, 1, 1, 1.0 - t), 4.0 * (1.0 - t) + 1.0)

func set_polarity(is_now_plus_pol: bool):
	is_plus_pol = is_now_plus_pol
	plus_sprite.visible = is_plus_pol
	minus_sprite.visible = not is_plus_pol
