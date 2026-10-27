extends Node2D
class_name Puck
## Visual representation of one simulated puck.

@export var plus_sprite: Sprite2D
@export var minus_sprite: Sprite2D
var is_plus_pol: bool = true
var _last_reset_tick: int = -2 # so the first update always resets the interpolation

## Called every tick after the simulation stepped.
func update_from_sim(sim_state: SimState, body: int) -> void:
	position = sim_state.pos[body]
	if sim_state.reset_tick != _last_reset_tick:
		_last_reset_tick = sim_state.reset_tick
		reset_physics_interpolation()
	var plus := sim_state.puck_plus[body] == 1
	if plus != is_plus_pol:
		set_polarity(plus)

func set_polarity(is_now_plus_pol: bool):
	is_plus_pol = is_now_plus_pol
	plus_sprite.visible = is_plus_pol
	minus_sprite.visible = not is_plus_pol
