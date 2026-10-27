extends Node
class_name MatchManager
## Match UI. The match itself (countdown, clock, goals, overtime, game over, restart) runs in the
## Simulation, this node only shows its state and reacts to changes. After the game over a player can
## send everybody back to the lobby, which is also decided in the simulation.

var match_time: float = 180
var gm: GameManager

@export var overlay_left: Control
@export var overlay_right: Control

@export var p1_score_label: Label
@export var p2_score_label: Label
@export var timer_label: Label
@export var status_label: Label

@export var countdown_node: Control
@export var countdown_label: Label

@export var ms: MapScript

var _shown_scores: PackedInt32Array = PackedInt32Array([0, 0])
var _shown_phase: Simulation.Phase = Simulation.Phase.NONE
var _shown_overtime: bool = false
var _last_goal_time: int = 0
var _leaving: bool = false

func _ready():
	gm = globGameManager
	ms.setup(self, match_time)
	_set_score_labels(ms.state.scores)
	if globNet.mode == NetGame.Mode.HOST:
		globNet.peer_left.connect(_on_peer_left)

## Host: a machine left, its players can not be simulated anymore, so everybody goes back to the lobby.
func _on_peer_left(peer: int) -> void:
	globNet.roster = globNet.roster.filter(func(entry): return entry["peer"] != peer)
	gm.print_message("A player left, back to the lobby")
	globNet.request_return_to_lobby()

func _process(_delta):
	var state := ms.state
	_update_phase(state)
	_update_scores(state)
	_update_countdown(state)
	if state.overtime:
		_update_timer_label(float(state.overtime_ticks) / Simulation.TICK_RATE)
	else:
		_update_timer_label(float(state.match_ticks) / Simulation.TICK_RATE)
	if not _leaving:
		# only leave from a confirmed state, a predicted leave could still be rolled back
		var confirmed := ms.session.get_confirmed_state() if ms.session != null else null
		if confirmed != null and confirmed.lobby_tick != -1:
			_leaving = true
			gm.return_to_lobby()

func _update_phase(state: SimState) -> void:
	if state.overtime and not _shown_overtime:
		gm.print_message("Tie! Game will be decided with the next goal!")
	_shown_overtime = state.overtime
	if state.phase == _shown_phase:
		return
	if state.phase == Simulation.Phase.COUNTDOWN and _shown_phase in [Simulation.Phase.NONE, Simulation.Phase.GAME_OVER]:
		gm.print_message("Starting new match!")
	elif state.phase == Simulation.Phase.PLAYING:
		_last_goal_time = Time.get_ticks_msec()
	elif state.phase == Simulation.Phase.GAME_OVER:
		gm.print_message("Game Over!")
		gm.print_message(_winner_text(state.winner))
	_shown_phase = state.phase

func _update_scores(state: SimState) -> void:
	if state.scores == _shown_scores:
		return
	for team in [1, 2]:
		if state.scores[team - 1] > _shown_scores[team - 1]:
			_flash_overlay(overlay_left if team == 1 else overlay_right)
			gm.print_message("Player " + str(team) + " scored after " + str((Time.get_ticks_msec() - _last_goal_time) / 1000) + " seconds!")
			gm.print_message("Score: " + str(state.scores[0]) + " - " + str(state.scores[1]))
	_shown_scores = state.scores.duplicate()
	_set_score_labels(state.scores)

func _set_score_labels(scores: PackedInt32Array) -> void:
	p1_score_label.text = str(scores[0]).pad_zeros(2)
	p2_score_label.text = str(scores[1]).pad_zeros(2)

func _update_countdown(state: SimState) -> void:
	match state.phase:
		Simulation.Phase.COUNTDOWN:
			countdown_node.show()
			var seconds_left := ceili(float(state.phase_ticks) / Simulation.TICK_RATE)
			countdown_label.text = str(seconds_left)
			# shrink during each second
			var second_left := float(state.phase_ticks - (seconds_left - 1) * Simulation.TICK_RATE) / Simulation.TICK_RATE
			countdown_node.scale = Vector2.ONE * lerpf(0.05, 1.0, second_left)
		Simulation.Phase.GAME_OVER:
			countdown_node.show()
			countdown_node.scale = Vector2.ONE * 0.5
			countdown_label.text = "Game Over!\n" + _winner_text(state.winner) + "\n\nStart / Esc: rematch\nSelect / Backspace: lobby"
		_:
			countdown_node.hide()

func _flash_overlay(overlay: Control) -> void:
	var tween = overlay.create_tween()
	tween.tween_property(overlay, "modulate", Color(1,1,1,0.5),0.25)
	tween.tween_property(overlay, "modulate", Color(1,1,1,0),0.25)
	tween.set_loops(3)

func _winner_text(winner: int) -> String:
	if winner == 1 or winner == 2:
		return "Player " + str(winner) + " Wins!"
	return "It's a tie!"

func _update_timer_label(time: float):
	# formate time to MM:SS
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	timer_label.text = str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2)
