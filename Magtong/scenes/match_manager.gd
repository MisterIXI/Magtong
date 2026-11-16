extends Node
class_name MatchManager
## Match UI. The match itself (countdown, clock, goals, overtime, game over, restart) runs in the
## Simulation, this node only shows its state and reacts to changes. After the game over a player can
## send everybody back to the lobby, which is also decided in the simulation.

var match_time: float = 180
## The countdown label is sized for one big digit; the game over text needs a normal size
const COUNTDOWN_FONT_SIZE: int = 416
const COUNTDOWN_OUTLINE: int = 25
const GAME_OVER_FONT_SIZE: int = 56
const GAME_OVER_OUTLINE: int = 12
const GOAL_FONT_SIZE: int = 200
const GOAL_OUTLINE: int = 24

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
	if GameManager.test_match_time > 0.0 and not NetGame.is_online():
		match_time = GameManager.test_match_time
	ms.setup(self, match_time)
	add_child(PauseMenu.new(ms))
	_set_score_labels(ms.state.scores)
	if NetGame.mode == NetGame.Mode.HOST:
		NetGame.peer_left.connect(_on_peer_left)

## Host: a machine left, its players can not be simulated anymore, so everybody goes back to the lobby.
func _on_peer_left(peer: int) -> void:
	NetGame.roster = NetGame.roster.filter(func(entry): return entry["peer"] != peer)
	GameManager.print_message("A player left, back to the lobby")
	NetGame.request_return_to_lobby()

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
			GameManager.return_to_lobby()

func _update_phase(state: SimState) -> void:
	if state.overtime and not _shown_overtime:
		GameManager.print_message("Tie! Game will be decided with the next goal!")
	_shown_overtime = state.overtime
	if state.phase == _shown_phase:
		return
	if state.phase == Simulation.Phase.COUNTDOWN and _shown_phase in [Simulation.Phase.NONE, Simulation.Phase.GAME_OVER]:
		GameManager.print_message("Starting new match!")
	elif state.phase == Simulation.Phase.PLAYING:
		_last_goal_time = Time.get_ticks_msec()
	elif state.phase == Simulation.Phase.GAME_OVER:
		GameManager.print_message("Game Over!")
		GameManager.print_message(_winner_text(state.winner))
	_shown_phase = state.phase

func _update_scores(state: SimState) -> void:
	if state.scores == _shown_scores:
		return
	for team in [1, 2]:
		if state.scores[team - 1] > _shown_scores[team - 1]:
			_flash_overlay(overlay_left if team == 1 else overlay_right)
			_pop_label(p1_score_label if team == 1 else p2_score_label)
			GameManager.print_message("Team " + Teams.NAMES[team - 1] + " scored after " + str((Time.get_ticks_msec() - _last_goal_time) / 1000) + " seconds!")
			GameManager.print_message("Score: " + str(state.scores[0]) + " - " + str(state.scores[1]))
	_shown_scores = state.scores.duplicate()
	_set_score_labels(state.scores)

func _set_score_labels(scores: PackedInt32Array) -> void:
	p1_score_label.text = str(scores[0]).pad_zeros(2)
	p2_score_label.text = str(scores[1]).pad_zeros(2)

func _update_countdown(state: SimState) -> void:
	match state.phase:
		Simulation.Phase.COUNTDOWN:
			countdown_node.show()
			_set_countdown_text_size(COUNTDOWN_FONT_SIZE, COUNTDOWN_OUTLINE)
			var seconds_left := ceili(float(state.phase_ticks) / Simulation.TICK_RATE)
			countdown_label.text = str(seconds_left)
			# shrink during each second
			var second_left := float(state.phase_ticks - (seconds_left - 1) * Simulation.TICK_RATE) / Simulation.TICK_RATE
			countdown_node.scale = Vector2.ONE * lerpf(0.05, 1.0, second_left)
		Simulation.Phase.GOAL:
			# driven by the simulation's phase ticks, so a rollback shows the right moment
			countdown_node.show()
			_set_countdown_text_size(GOAL_FONT_SIZE, GOAL_OUTLINE)
			countdown_label.text = "GOAL!"
			countdown_label.add_theme_color_override(&"font_color", Teams.color(state.last_goal_team))
			var elapsed := float(Simulation.GOAL_TICKS - state.phase_ticks) / Simulation.TICK_RATE
			# pops in with an overshoot, then fades out at the end
			var pop := clampf(elapsed / 0.3, 0.0, 1.0)
			countdown_node.scale = Vector2.ONE * (1.0 + 0.35 * sin(pop * PI)) * lerpf(0.2, 1.0, pop)
			countdown_node.modulate.a = clampf(float(state.phase_ticks) / (0.3 * Simulation.TICK_RATE), 0.0, 1.0)
		Simulation.Phase.GAME_OVER:
			countdown_node.show()
			countdown_node.scale = Vector2.ONE
			_set_countdown_text_size(GAME_OVER_FONT_SIZE, GAME_OVER_OUTLINE)
			countdown_label.text = "Game Over!\n" + _winner_text(state.winner) + "\n\nStart / Esc: rematch\nSelect / Backspace: lobby"
		_:
			countdown_node.hide()

func _set_countdown_text_size(font_size: int, outline: int) -> void:
	if font_size != GOAL_FONT_SIZE:
		countdown_label.remove_theme_color_override(&"font_color")
		countdown_node.modulate.a = 1.0
	countdown_label.add_theme_font_size_override(&"font_size", font_size)
	countdown_label.add_theme_constant_override(&"outline_size", outline)

func _pop_label(label: Label) -> void:
	label.pivot_offset = label.size / 2
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.8, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _flash_overlay(overlay: Control) -> void:
	var tween = overlay.create_tween()
	tween.tween_property(overlay, "modulate", Color(1,1,1,0.5),0.25)
	tween.tween_property(overlay, "modulate", Color(1,1,1,0),0.25)
	tween.set_loops(3)

func _winner_text(winner: int) -> String:
	if winner == 1 or winner == 2:
		return "Team " + Teams.NAMES[winner - 1] + " Wins!"
	return "It's a tie!"

func _update_timer_label(time: float):
	# formate time to MM:SS
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	timer_label.text = str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2)
