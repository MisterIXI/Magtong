extends Node
class_name MatchManager

var match_time: float = 300
var im : InputManager
var gm: GameManager

@export var p1_score_label: Label
@export var p2_score_label: Label
@export var timer_label: Label
@export var status_label: Label

var player1_score: int = 0
var player2_score: int = 0

@export var game_timer: Timer
@export var countdown_timer: Timer
var countdown 
var game_running: bool = false
@export var ms: MapScript

@rpc("authority", "call_local", "reliable")
func setup(match_time: float):
	self.match_time = match_time
	im = globInputManager
	gm = globGameManager
	ms.setup(self)
	if multiplayer.is_server():
		ms.goal_scored.connect(on_goal_scored)

func _ready():
	if multiplayer.is_server():
		setup.rpc(300)
		restart_match.rpc()

@rpc("authority", "call_local", "reliable")
func restart_match():
	countdown_timer.stop()
	game_timer.start(match_time)
	im.input_locked = false
	gm.print_message("Starting new match!")
	game_running = true
	p1_score_label.text = "P1 " + str(player1_score).pad_zeros(2)
	p2_score_label.text = str(player2_score).pad_zeros(2) + " P2"
	ms.reset_field()

@rpc("authority", "call_local", "reliable")
func score_for_team(team: int):
	if team == 1:
		player1_score += 1
		gm.print_message("Player 1 scored!")
	elif team == 2:
		player2_score += 1
		gm.print_message("Player 2 scored!")
	gm.print_message("Score: " + str(player1_score) + " - " + str(player2_score))
	p1_score_label.text = "P1 " + str(player1_score).pad_zeros(2)
	p2_score_label.text = str(player2_score).pad_zeros(2) + " P2"
	game_timer.paused = true
	game_timer.paused = true
	ms.reset_field()
	if multiplayer.is_server():
		im.input_locked = true
		countdown = 4
		_on_countdown_timer_timeout()

@rpc("authority", "call_local", "reliable")
func resume_game():
	if multiplayer.is_server():
		im.input_locked = false
	game_timer.paused = false
	countdown_timer.stop()

@rpc("authority", "call_local", "reliable")
func spawn_map(_map_id: int):
	pass

@rpc("authority", "call_local", "reliable")
func game_over(winning_team: int):
	game_timer.stop()
	game_running = false
	timer_label.text = "Game Over!"
	if winning_team == 1:
		status_label.text = "Player 1 Wins!"
	elif winning_team == 2:
		status_label.text = "Player 2 Wins!"
	else:
		status_label.text = "It's a tie!"
	gm.print_message("Game Over!")
	gm.print_message(status_label.text)
	ms.reset_field()
	if multiplayer.is_server():
		im.input_locked = true


func _process(_delta):
	if game_running and not game_timer.paused:
		# formate game_timer.time_left to MM:SS:MS
		var minutes = int(game_timer.time_left / 60)
		var seconds = int(game_timer.time_left) % 60
		var milliseconds = int((game_timer.time_left - int(game_timer.time_left)) * 100)
		timer_label.text = str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2) + ":" + str(milliseconds).pad_zeros(2)

func on_goal_scored(team_id: int):
	score_for_team.rpc(team_id)

func start_game_countdown():
	countdown_timer.start()
	countdown = 3
	timer_label.text = str(countdown) + "..."

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
		im.input_locked = false
		return
	gm.send_message.rpc(str(countdown) + "...")
	countdown_timer.start(1)

func _on_goal_south_body_entered(body:Node2D):
	if body.is_in_group("puck"):
		player2_score += 1
		print("Player 2 scored!")
		status_label.text = "Player 2 scored!"
		score_for_team.rpc(2)

func _on_goal_north_body_entered(body:Node2D):
	if body.is_in_group("puck"):
		player1_score += 1
		print("Player 1 scored!")
		status_label.text = "Player 1 scored!"
		score_for_team.rpc(1)

func _on_game_timeout():
	var winning_team = 0
	if player1_score > player2_score:
		winning_team = 1
	elif player2_score > player1_score:
		winning_team = 2
	game_over.rpc(winning_team)