extends Node2D
class_name Game

@export var player1 : PlayerBody
@export var player2 : PlayerBody
@export var puck : Puck

@export var goalSouth: Area2D
@export var goalNorth: Area2D

var player1_score: int = 0
var player2_score: int = 0

@export var p1_score_label: Label
@export var p2_score_label: Label
@export var timer_label: Label
@export var status_label: Label

@export var game_timer: Timer
@export var countdown_timer: Timer

@export var center_point: Node2D
var countdown: int = 3
var game_running : bool = false

var input_locked: bool = true

func _ready():
	reset_game()
	start_game_countdown()

func _process(_delta):
	if game_running and not game_timer.paused:
		# formate game_timer.time_left to MM:SS:MS
		var minutes = int(game_timer.time_left / 60)
		var seconds = int(game_timer.time_left) % 60
		var milliseconds = int((game_timer.time_left - int(game_timer.time_left)) * 100)
		timer_label.text = str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2) + ":" + str(milliseconds).pad_zeros(2)
	if not game_running:
		# if R button is pressed, start a new game
		if Input.is_action_just_pressed("restart") and input_locked and  countdown_timer.is_stopped():
			reset_game()
			start_game_countdown()
func reset_game():
	player1.reset(center_point.global_position + Vector2(0,300))
	player2.reset(center_point.global_position + Vector2(0,-300))
	puck.reset(center_point.global_position)
	player1_score = 0
	player2_score = 0
	p1_score_label.text = "P1 " + str(player1_score).pad_zeros(2)
	p2_score_label.text = str(player2_score).pad_zeros(2) + " P2"
	game_timer.stop()
	countdown_timer.stop()

func on_goal_scored():
	p1_score_label.text = "P1 " + str(player1_score).pad_zeros(2)
	p2_score_label.text = str(player2_score).pad_zeros(2) + " P2"
	game_timer.paused = true
	player1.reset(center_point.global_position + Vector2(0,300))
	player2.reset(center_point.global_position + Vector2(0,-300))
	puck.reset(center_point.global_position)
	start_game_countdown()

func start_game_countdown():
	countdown_timer.start()
	countdown = 3
	timer_label.text = str(countdown) + "..."
	input_locked = true

func _on_countdown_timer_timeout():
	countdown -= 1
	timer_label.text = str(countdown) + "..."
	if countdown == 0:
		timer_label.text = "GO!"
		if game_running:
			game_timer.paused = false
		else:
			game_timer.start()
			game_running = true
		status_label.text = ""
		countdown_timer.stop()
		countdown = 3
		input_locked = false
		return
	countdown_timer.start()

func _on_goal_south_body_entered(body:Node2D):
	if body.is_in_group("puck"):
		player2_score += 1
		print("Player 2 scored!")
		status_label.text = "Player 2 scored!"
		on_goal_scored()

func _on_goal_north_body_entered(body:Node2D):
	if body.is_in_group("puck"):
		player1_score += 1
		print("Player 1 scored!")
		status_label.text = "Player 1 scored!"
		on_goal_scored()


func _on_game_timeout():
	game_timer.stop()
	game_running = false
	timer_label.text = "Game Over!"
	if player1_score > player2_score:
		status_label.text = "Player 1 Wins!"
	elif player2_score > player1_score:
		status_label.text = "Player 2 Wins!"
	else:
		status_label.text = "It's a tie!"
	input_locked = true
	player1.reset(player1.global_position)
	player2.reset(player2.global_position)
	puck.reset(puck.global_position)