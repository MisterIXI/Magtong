extends Node2D
class_name GoalEffects
## The one-off effects of a goal: explosion in the scoring team's color, sparks, a short screen flash and
## screen shake. Like MapSounds it only reacts to state changes the views see: a goal is shown once, a
## rollback that shows the same goal again (or moves it by a tick) doesn't replay it. Runs in real time, the
## slow motion is in the simulation. Only MapScript creates this node, the main menu background stays calm.

const EXPLOSION_TIME: float = 0.9
const RING_MAX_RADIUS: float = 450.0 # Simulation.GOAL_PUSH_RANGE: the ring shows how far the shockwave reaches
const SPARK_COUNT: int = 48
const SPARK_SPEED_MIN: float = 300.0
const SPARK_SPEED_MAX: float = 1100.0
const SPARK_TIME: float = 0.8
const FLASH_ALPHA: float = 0.45
const FLASH_TIME: float = 0.25
const SHAKE_STRENGTH: float = 18.0
const SHAKE_TIME: float = 0.6

var map: MapScript
var _shown_goal_tick: int = -2 # -2: not seen yet, a goal from before (rejoin, new view) doesn't play
var _age: float = -1.0 # seconds since the shown goal, -1 = nothing playing
var _color: Color
var _sparks: Array = [] # [direction: Vector2, speed: float, size: float]
var _flash: ColorRect
var _camera: Camera2D

func _init(map: MapScript) -> void:
	self.map = map
	name = "GoalEffects"
	z_index = 50
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	layer.add_child(_flash)

## Called by MapScript every time the views were updated.
func update(state: SimState) -> void:
	if _shown_goal_tick == -2:
		_shown_goal_tick = state.last_goal_tick
	elif state.last_goal_tick > _shown_goal_tick:
		_shown_goal_tick = state.last_goal_tick
		if state.goal_puck >= 0:
			_play(state.pos[state.goal_puck], state.last_goal_team)

func _play(at: Vector2, team: int) -> void:
	position = at
	reset_physics_interpolation() # jump to the goal, don't slide there from the last explosion
	_color = Teams.color(team)
	_age = 0.0
	_sparks.clear()
	for i in SPARK_COUNT:
		_sparks.append([Vector2.from_angle(randf() * TAU), randf_range(SPARK_SPEED_MIN, SPARK_SPEED_MAX), randf_range(4.0, 10.0)])
	_camera = get_viewport().get_camera_2d()

func _process(delta: float) -> void:
	if _age < 0.0:
		return
	_age += delta
	_flash.color = Color(1, 1, 1, FLASH_ALPHA * clampf(1.0 - _age / FLASH_TIME, 0.0, 1.0))
	if _camera != null:
		var shake := SHAKE_STRENGTH * pow(clampf(1.0 - _age / SHAKE_TIME, 0.0, 1.0), 2.0)
		_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	if _age > maxf(EXPLOSION_TIME, maxf(SPARK_TIME, SHAKE_TIME)):
		_age = -1.0
		if _camera != null:
			_camera.offset = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if _age < 0.0:
		return
	var t := clampf(_age / EXPLOSION_TIME, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	# core: a bright disc that shrinks away
	var core := 1.0 - clampf(_age / 0.3, 0.0, 1.0)
	if core > 0.0:
		draw_circle(Vector2.ZERO, 90.0 * (0.5 + core), Color(1, 1, 1, 0.9 * core))
		draw_circle(Vector2.ZERO, 130.0 * (0.5 + core), Color(_color, 0.6 * core))
	# shockwave rings, the outer one reaches as far as the push
	var fade := 1.0 - t
	draw_arc(Vector2.ZERO, RING_MAX_RADIUS * ease_out, 0.0, TAU, 96, Color(_color, fade), 22.0 * fade + 2.0)
	draw_arc(Vector2.ZERO, RING_MAX_RADIUS * 0.7 * ease_out, 0.0, TAU, 96, Color(1, 1, 1, 0.7 * fade), 8.0 * fade + 1.0)
	# sparks fly out and slow down
	var st := clampf(_age / SPARK_TIME, 0.0, 1.0)
	if st < 1.0:
		var travel := 1.0 - pow(1.0 - st, 2.0)
		for spark in _sparks:
			var p: Vector2 = spark[0] * spark[1] * travel * SPARK_TIME * 0.6
			draw_circle(p, spark[2] * (1.0 - st), Color(_color.lightened(0.3), 1.0 - st))
