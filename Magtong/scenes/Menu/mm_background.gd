class_name MMBackground
extends Node2D
## Main menu background: a sandbox simulation (no walls, no match) with scripted player inputs.

const PUCK_PAIRS: int = 8

var players: Array[PlayerBody] = []
var pucks: Array[Puck] = []
var p1_start_pos: Vector2 = Vector2(-1100, -500)
var p2_start_pos: Vector2 = Vector2(1100, 500)
var p3_start_pos: Vector2 = Vector2(-700, 0.0)
var p4_start_pos: Vector2 = Vector2(700, 0.0)
var tween1: Tween
var tween2: Tween
var tween3: Tween
var tween4: Tween
@export var settings: PlayerSettings
var sim: Simulation
var state: SimState
# scripted input per player
var moves: Array[Vector2] = []
var buttons: PackedInt32Array = PackedInt32Array()

func _ready():
	sim = Simulation.new(settings, Simulation.Mode.SANDBOX)
	state = SimState.new()
	# spawn pucks (the simulation needs them before the players)
	for i in range(PUCK_PAIRS):
		_spawn_puck(p1_start_pos + Vector2.DOWN * 100 * (i+1), i % 2 != 0)
		_spawn_puck(p2_start_pos + Vector2.UP * 100 * (i+1), i % 2 != 0)
	# spawn players
	for start_pos in [p1_start_pos, p2_start_pos, p3_start_pos, p4_start_pos]:
		_spawn_player(start_pos)
	_update_views()
	start_tweens()

func start_tweens():
	await get_tree().physics_frame
	var p1 = 0
	
	# tween for body 1
	tween1 = create_tween()
	# move right
	tween1.tween_callback(_set_x.bind(p1, 0.5))
	tween1.tween_interval(1.5)
	tween1.tween_callback(_set_plus.bind(p1, 1.0))
	tween1.tween_interval(1.5)
	# move left and down
	tween1.tween_method(
		func (x): _set_y(p1, x),
		0.0,
		0.5,
		0.5,
	)
	tween1.parallel()
	tween1.tween_method(
		func (x): _set_x(p1, x),
		0.5,
		-0.5,
		1.5,
	)
	# move down and right
	tween1.tween_callback(_set_plus.bind(p1, 0.0))
	tween1.tween_callback(_set_minus.bind(p1, 1.0))
	tween1.tween_method(
		func (x): x = clampf(x, 0.0, 0.5); _set_y(p1, x),
		1.5,
		0.0,
		1.5,
	)
	tween1.parallel()
	tween1.tween_method(
		func (x): _set_x(p1, x),
		-0.5,
		0.5,
		1.5,
	)
	tween1.tween_callback(_set_y.bind(p1, 0.0))
	tween1.tween_callback(_set_x.bind(p1, -0.5))
	tween1.tween_interval(1.5)
	tween1.tween_callback(_set_minus.bind(p1, 0.0))
	tween1.tween_interval(1.5)
	tween1.tween_callback(_set_x.bind(p1, 0.0))
	tween1.tween_callback(_teleport.bind(p1, p1_start_pos))
	tween1.tween_interval(1.0)
	tween1.set_loops()
	tween1.play()

	# tween for body 2
	var p2 = 1
	tween2 = create_tween()
	# move right
	tween2.tween_callback(_set_x.bind(p2, -0.5))
	tween2.tween_interval(1.5)
	tween2.tween_callback(_set_minus.bind(p2, 1.0))
	tween2.tween_interval(1.5)
	# move left and down
	tween2.tween_method(
		func (x): _set_y(p2, x),
		0.0,
		-0.5,
		0.5,
	)
	tween2.parallel()
	tween2.tween_method(
		func (x): _set_x(p2, x),
		-0.5,
		0.5,
		1.5,
	)
	# move down and right
	tween2.tween_callback(_set_minus.bind(p2, 0.0))
	tween2.tween_callback(_set_plus.bind(p2, 1.0))
	tween2.tween_method(
		func (x): x = clampf(x, -0.5, 0.0); _set_y(p2, x),
		-1.5,
		0.0,
		1.5,
	)
	tween2.parallel()
	tween2.tween_method(
		func (x): _set_x(p2, x),
		0.5,
		-0.5,
		1.5,
	)
	tween2.tween_callback(_set_y.bind(p2, 0.0))
	tween2.tween_callback(_set_x.bind(p2, 0.5))
	tween2.tween_interval(1.5)
	tween2.tween_callback(_set_plus.bind(p2, 0.0))
	tween2.tween_interval(1.5)
	tween2.tween_callback(_set_x.bind(p2, 0.0))
	tween2.tween_callback(_teleport.bind(p2, p2_start_pos))
	tween2.tween_interval(1.0)
	tween2.set_loops()
	tween2.play()

	# simple loops for p3 and p4
	# p3 up and down
	var p3 = 2
	_set_minus(p3, 1.0)
	_set_y(p3, 0.3)
	tween3 = create_tween()
	# tween3.tween_callback(_set_y.bind(p3, 0.3))
	tween3.tween_interval(1.75)
	tween3.tween_method(
		func (x): _set_y(p3, x),
		0.3,
		-0.3,
		1.0,
	)
	tween3.tween_interval(3.5)
	tween3.tween_method(
		func (x): _set_y(p3, x),
		-0.3,
		0.3,
		1.0,
	)
	tween3.tween_interval(1.75)
	tween3.set_loops()
	
func _physics_process(_delta):
	var inputs := PackedInt32Array()
	for i in players.size():
		inputs.append(SimInput.encode(moves[i], buttons[i]))
	sim.step(state, inputs)
	_update_views()

func _update_views() -> void:
	for k in pucks.size():
		pucks[k].update_from_sim(state, k)
	for i in players.size():
		players[i].update_from_sim(state, sim.player_body(i), i)

func _set_x(player: int, value: float) -> void:
	moves[player].x = value

func _set_y(player: int, value: float) -> void:
	moves[player].y = value

func _set_plus(player: int, value: float) -> void:
	_set_button(player, SimInput.PLUS, value > 0.0)

func _set_minus(player: int, value: float) -> void:
	_set_button(player, SimInput.MINUS, value > 0.0)

func _set_button(player: int, button: int, pressed: bool) -> void:
	if pressed:
		buttons[player] |= button
	else:
		buttons[player] &= ~button

func _teleport(player: int, pos: Vector2) -> void:
	sim.teleport(state, sim.player_body(player), pos)

func _spawn_puck(pos: Vector2, is_plus: bool) -> void:
	var puck: Puck = globResourceManager.puck_scene.instantiate()
	add_child(puck)
	sim.add_puck(state, pos, is_plus)
	pucks.append(puck)

func _spawn_player(pos: Vector2) -> void:
	var new_player: PlayerBody = globResourceManager.player_scene.instantiate()
	add_child(new_player, true)
	sim.add_player(state, pos)
	players.append(new_player)
	moves.append(Vector2.ZERO)
	buttons.append(0)
