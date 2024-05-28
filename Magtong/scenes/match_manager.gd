extends Node
class_name MatchManager

var match_time: float = 180
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
var peer_ready_state: Dictionary = {}
var all_ready: bool = false
var is_in_overtime: bool = false
var overtime_start_time: float = 0
var time_since_last_goal: float = 0

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
		peer_ready_state = {}
		for peer in multiplayer.get_peers():
			peer_ready_state[peer] = false
	_ready_to_play.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _ready_to_play():
	assert(multiplayer.is_server(), "Only the server can call this function")
	var peer = multiplayer.get_remote_sender_id()
	peer_ready_state[peer] = true
	var all_ready = true
	for is_ready in peer_ready_state.values():
		if not is_ready:
			all_ready = false
			break
	if all_ready:
		self.all_ready = true
		setup.rpc(match_time)
		restart_match.rpc()

@rpc("authority", "call_local", "reliable")
func restart_match():
	countdown_timer.stop()
	game_timer.stop()
	game_timer.start(match_time)
	game_timer.paused = true
	gm.print_message("Starting new match!")
	timer_label.text = "Get Ready!"
	game_running = true
	player1_score = 0
	player2_score = 0
	is_in_overtime = false
	p1_score_label.text = "P1 " + str(player1_score).pad_zeros(2)
	p2_score_label.text = str(player2_score).pad_zeros(2) + " P2"
	ms.reset_field()
	if multiplayer.is_server():
		im.set_input_locked(true)
		countdown = 4
		_on_countdown_timer_timeout()

@rpc("authority", "call_local", "reliable")
func score_for_team(team: int):
	if team == 1:
		player1_score += 1
		gm.print_message("Player 1 scored after " + str((Time.get_ticks_msec() - time_since_last_goal) / 1000) + " seconds!")
	elif team == 2:
		player2_score += 1
		gm.print_message("Player 2 scored after " + str((Time.get_ticks_msec() - time_since_last_goal) / 1000) + " seconds!")
	elif team == 0:
		is_in_overtime = true
		gm.print_message("Tie! Game will be decided with the next goal!")
	gm.print_message("Score: " + str(player1_score) + " - " + str(player2_score))
	p1_score_label.text = "P1 " + str(player1_score).pad_zeros(2)
	p2_score_label.text = str(player2_score).pad_zeros(2) + " P2"
	game_timer.paused = true
	if multiplayer.is_server():
		if is_in_overtime and team != 0:
			game_over.rpc(_determine_winner())
		else:
			ms.reset_field()
			im.set_input_locked(true)
			countdown = 4
			_on_countdown_timer_timeout()

@rpc("authority", "call_local", "reliable")
func resume_game():
	if multiplayer.is_server():
		im.set_input_locked(false)
	if is_in_overtime:
		overtime_start_time = Time.get_ticks_msec()
	else:
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
	ms.reset_field(true)
	if multiplayer.is_server():
		im.set_input_locked(true)

@rpc("any_peer", "call_local", "reliable")
func request_restart():
	assert(multiplayer.is_server(), "Only the server can call this function")
	if not game_running and all_ready:
		restart_match.rpc()

func _process(_delta):
	if game_running and countdown_timer.is_stopped() and (not game_timer.paused or is_in_overtime):
		var time: float
		if is_in_overtime:
			time = (Time.get_ticks_msec() - overtime_start_time) / 1000
		else:
			time = game_timer.time_left
		# formate game_timer.time_left to MM:SS:MS
		var minutes = int(time / 60)
		var seconds = int(time) % 60
		var milliseconds = int((time - int(time)) * 100)
		timer_label.text = str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2) + ":" + str(milliseconds).pad_zeros(2) + (" OT" if is_in_overtime else "")

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
		time_since_last_goal = Time.get_ticks_msec()
		if game_running:
			resume_game.rpc()
		else:
			game_timer.start()
			game_running = true
		status_label.text = ""
		countdown_timer.stop()
		im.set_input_locked(false)
		return
	gm.send_message.rpc(str(countdown) + "...")
	countdown_timer.start(1)

func _on_goal_south_body_entered(body:Node2D):
	if body.is_in_group("Puck"):
		player2_score += 1
		print("Player 2 scored!")
		status_label.text = "Player 2 scored!"
		score_for_team.rpc(2)

func _on_goal_north_body_entered(body:Node2D):
	if body.is_in_group("Puck"):
		player1_score += 1
		print("Player 1 scored!")
		status_label.text = "Player 1 scored!"
		score_for_team.rpc(1)

func _determine_winner() -> int:
	if player1_score > player2_score:
		return 1
	elif player2_score > player1_score:
		return 2
	else:
		return 0

func _on_game_timeout():
	if not multiplayer.is_server():
		return
	var winning_team = _determine_winner()
	if winning_team == 0:
		is_in_overtime = true
		overtime_start_time = Time.get_ticks_msec()
		score_for_team.rpc(0)
	else:
		game_running = false
		game_over.rpc(winning_team)
