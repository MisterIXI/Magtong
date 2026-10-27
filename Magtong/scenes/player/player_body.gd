extends Node2D
class_name PlayerBody
## Visual representation of one simulated player. Gameplay happens in Simulation, this node only
## mirrors the state and turns state changes into signals for the visuals.

signal polarity_changed(new_pol: Simulation.Polarity)
signal pulse_emitted(pulse_position: Vector2)
signal impulse_emitted(pulse_position: Vector2, pol: Simulation.Polarity)
signal setup_completed(player_body: PlayerBody)

@export var player_skin: Sprite2D

var state: Simulation.Polarity = Simulation.Polarity.IDLE
var player_input: PlayerInput
var is_in_lobby: bool = false
var mm: MatchManager
var map: MapScript
var _skin: int = -1
var _last_pulse_tick: int = -1
var _last_ability_tick: int = -1
var _last_reset_tick: int = -2 # so the first update always resets the interpolation

## player_input is null for players controlled on another machine.
func setup_player(map: MapScript, player_input: PlayerInput, is_in_lobby: bool = false):
	self.map = map
	self.player_input = player_input
	self.is_in_lobby = is_in_lobby
	if not is_in_lobby:
		mm = GameManager.scene_root.current_scene as MatchManager
	setup_completed.emit(self)

## Called every tick after the simulation stepped.
func update_from_sim(sim_state: SimState, body: int, player: int) -> void:
	position = sim_state.pos[body]
	if sim_state.reset_tick != _last_reset_tick:
		_last_reset_tick = sim_state.reset_tick
		reset_physics_interpolation()
	if sim_state.skin[player] != _skin:
		_skin = sim_state.skin[player]
		set_skin(_skin)
	var new_pol: Simulation.Polarity = sim_state.polarity[player]
	if new_pol != state:
		state = new_pol
		polarity_changed.emit(state)
	# only newer ticks, a rollback can move these back and the effect must not play again
	if sim_state.last_pulse_tick[player] > _last_pulse_tick:
		_last_pulse_tick = sim_state.last_pulse_tick[player]
		pulse_emitted.emit(global_position)
	if sim_state.last_ability_tick[player] > _last_ability_tick:
		_last_ability_tick = sim_state.last_ability_tick[player]
		impulse_emitted.emit(global_position, state)

func set_skin(player_sprite_id: int):
	var sprites: Array = ResourceManager.icons.player_sprites
	player_skin.texture = sprites[posmod(player_sprite_id, sprites.size())]
