extends Node
class_name MatchManager

var match_time: float = 180
var im: InputManager
var gm: GameManager

@export var overlay_left: Control
@export var overlay_right: Control

@export var p1_score_label: Label
@export var p2_score_label: Label
@export var timer_label: Label
@export var status_label: Label

@export var countdown_node: Control
@export var countdown_label: Label

var player1_score: int = 0
var player2_score: int = 0

@export var game_timer: Timer
@export var countdown_timer: Timer
var game_running: bool = false
@export var ms: MapScript
var is_in_overtime: bool = false
var overtime_start_time: float = 0
var time_since_last_goal: float = 0

func setup(match_time: float):
	self.match_time = match_time
	im = globInputManager
	gm = globGameManager
	ms.setup(self)
	ms.goal_scored.connect(on_goal_scored)

func _ready():
	setup(match_time)
	restart_match()

func restart_match():
	countdown_timer.stop()
	game_timer.stop()
	game_timer.start(match_time)
	game_timer.paused = true
	gm.print_message("Starting new match!")
	game_running = true
	player1_score = 0
	player2_score = 0
	is_in_overtime = false
	p1_score_label.text = str(player1_score).pad_zeros(2)
	p2_score_label.text = str(player2_score).pad_zeros(2)
	ms.reset_field()
	im.set_input_locked(true)
	start_game_countdown()

func score_for_team(team: int):
	if team == 1:
		player1_score += 1
		# var tween = p1_score_label.create_tween()
		# tween.tween_property(p1_score_label, "theme_override_colors/font_color", Color(0.5,0.5,0.5,1),0.5)
		# tween.tween_property(p1_score_label, "theme_override_colors/font_color", Color(1,1,1,1),0.5)
		var tween = overlay_left.create_tween()
		tween.tween_property(overlay_left, "modulate", Color(1,1,1,0.5),0.25)
		tween.tween_property(overlay_left, "modulate", Color(1,1,1,0),0.25)
		tween.set_loops(3)
		gm.print_message("Player 1 scored after " + str((Time.get_ticks_msec() - time_since_last_goal) / 1000) + " seconds!")
	elif team == 2:
		player2_score += 1
		var tween = overlay_right.create_tween()
		tween.tween_property(overlay_right, "modulate", Color(1,1,1,0.5),0.25)
		tween.tween_property(overlay_right, "modulate", Color(1,1,1,0),0.25)
		tween.set_loops(3)
		gm.print_message("Player 2 scored after " + str((Time.get_ticks_msec() - time_since_last_goal) / 1000) + " seconds!")
	elif team == 0:
		is_in_overtime = true
		gm.print_message("Tie! Game will be decided with the next goal!")
	gm.print_message("Score: " + str(player1_score) + " - " + str(player2_score))
	p1_score_label.text = str(player1_score).pad_zeros(2)
	p2_score_label.text = str(player2_score).pad_zeros(2)
	game_timer.paused = true
	if is_in_overtime and team != 0:
		game_over(_determine_winner())
	else:
		ms.reset_field()
		im.set_input_locked(true)
		start_game_countdown()

func resume_game():
	im.set_input_locked(false)
	if is_in_overtime:
		overtime_start_time = Time.get_ticks_msec()
	else:
		game_timer.paused = false
	countdown_timer.stop()

func game_over(winning_team: int):
	game_timer.stop()
	game_running = false
	_update_timer_label(0)
	countdown_label.text = "Game Over!"
	countdown_node.show()
	countdown_node.scale = Vector2.ONE * 0.5
	if winning_team == 1:
		countdown_label.text += "\nPlayer 1 Wins!"
	elif winning_team == 2:
		countdown_label.text += "\nPlayer 2 Wins!"
	else:
		countdown_label.text += "\nIt's a tie!"
	gm.print_message("Game Over!")
	gm.print_message(status_label.text)
	ms.reset_field(true)
	im.set_input_locked(true)

func request_restart():
	if not game_running:
		restart_match()

func _process(_delta):
	if game_running and countdown_timer.is_stopped() and (not game_timer.paused or is_in_overtime):
		if is_in_overtime:
			_update_timer_label((Time.get_ticks_msec() - overtime_start_time) / 1000)
		else:
			_update_timer_label(game_timer.time_left)

func _update_timer_label(time: float):
	# formate game_timer.time_left to MM:SS:MS
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	timer_label.text = str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2)

func on_goal_scored(team_id: int):
	score_for_team(team_id)

func start_game_countdown():
	countdown_node.show()
	var loop_func = func(x):
		countdown_node.scale = Vector2.ONE
		countdown_label.text = str(3 - x)
		gm.print_message(str(3 - x) + "...")
	loop_func.call(0)
	var tween = countdown_node.create_tween()
	tween.set_loops(3)
	tween.tween_property(countdown_node, "scale", Vector2.ONE * 0.05, 1.0)
	tween.loop_finished.connect(loop_func)
	tween.finished.connect(func():
		# countdown finished, starting game
		time_since_last_goal = Time.get_ticks_msec()
		if game_running:
			resume_game()
		else:
			game_timer.start()
			game_running = true
		countdown_node.hide()
		)
	_update_timer_label(game_timer.time_left)

func _determine_winner() -> int:
	if player1_score > player2_score:
		return 1
	elif player2_score > player1_score:
		return 2
	else:
		return 0

func _on_game_timeout():
	var winning_team = _determine_winner()
	if winning_team == 0:
		is_in_overtime = true
		overtime_start_time = Time.get_ticks_msec()
		score_for_team(0)
	else:
		game_running = false
		game_over(winning_team)
