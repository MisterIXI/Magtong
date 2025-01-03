extends MapScript
class_name AIMapScript

@export var pb_scene: PackedScene
@export var goal_t1: Area2D
@export var goal_t2: Area2D
var p1_aic: AIController
var p2_aic: AIController
@export var info_label_1: Label
@export var info_label_2: Label
var p1_rewards: Array[float] = []
var p2_rewards: Array[float] = []
var p1_goals: int = 0
var p2_goals: int = 0
const GOAL_REWARD = 50.0
var puck_pos_times_p1: Array[int] = []
var puck_pos_times_p2: Array[int] = []
const PUCK_STEP_SIZE = 100
const PUCK_STEP_MAX_TIME = 1000.0
const PUCK_STEP_REWARD = 3

func _ready():
	super._ready()
	globGameManager.toggle_message_panel()
	# local server setup
	# globGameManager.host_game(true)
	disable_lobby_features()
	pucks.append(spawn_puck())
	# spawn players
	setup_ai_players(true)
	reset_field()
	goal_scored.connect(on_goal_scored)


func _physics_process(delta):
	super._physics_process(delta)
	# check if ball has progressed for any player
	check_puck_rewards()

func check_puck_rewards():
	if puck_pos_times_p1.size() == 0:
		return
	var size = puck_pos_times_p1.size()
	var _time_spent = 0
	var _reward = 0.0
	if pucks[0].position.x > size * PUCK_STEP_SIZE:
		puck_pos_times_p1.append(Time.get_ticks_msec())
		# time_spent = (puck_pos_times_p1[-1] - puck_pos_times_p1[-2])
		# # reward variable as percentage of max reward per step
		# reward = time_spent / PUCK_STEP_MAX_TIME * PUCK_STEP_REWARD
		# # cap reward at max reward per step
		# reward = min(PUCK_STEP_REWARD, reward)
		# # cap reward at 10% min of max reward per step
		# reward = max(PUCK_STEP_REWARD * 0.1, reward)
		# p1_receive_reward(reward)
		p1_receive_reward(PUCK_STEP_REWARD)
	if p2_aic:
		size = puck_pos_times_p2.size()
		if pucks[0].position.x < -size * PUCK_STEP_SIZE:
			puck_pos_times_p2.append(Time.get_ticks_msec())
			# time_spent = (puck_pos_times_p2[-1] - puck_pos_times_p2[-2])
			# reward = time_spent / PUCK_STEP_MAX_TIME * PUCK_STEP_REWARD
			# reward = min(PUCK_STEP_REWARD, reward)
			# reward = max(PUCK_STEP_REWARD * 0.1, reward)
			# p2_receive_reward(reward)
			p2_receive_reward(PUCK_STEP_REWARD)

	
func setup_ai_players(only_one: bool):
	var p1_input = PlayerInput.new(-1, -1, 0, true)
	p1_input.team = 1
	var p1 = pb_scene.instantiate() as PlayerBody
	p1.name = "AI1"
	var p2_input = PlayerInput.new(-1, -1, 1, true)
	p2_input.team = 2
	var p2 = pb_scene.instantiate() as PlayerBody
	p2.name = "AI2"
	mp_root.add_child(p1)
	mp_root.add_child(p2)
	players = [[p1], [p2]]
	p1.setup_player(self, p1_input)
	p2.setup_player(self, p2_input)
	p1_aic = AIController.new()
	p1.add_child(p1_aic)
	if not only_one:
		p2_aic = AIController.new()
		p2.add_child(p2_aic)
	else:
		p2.add_child(RandomInputController.new())
	# var sync_node = Sync.new()
	# p1.add_child(sync_node)
	p1.pulse_emitted.connect(on_pulse_from)
	p2.pulse_emitted.connect(on_pulse_from)
	info_label_1.text = "0.00 | 0G"
	if p2_aic:
		info_label_2.text = "0G | 0.00"
	else:
		info_label_2.text = "0G | Random"

func p1_receive_reward(reward: float):
	p1_aic.reward += reward
	p1_rewards.append(reward)
	if p1_rewards.size() > 60:
		p1_rewards.pop_front()
	var sum = p1_rewards.reduce(func(acc, x): return acc + x, 0) / 60
	info_label_1.text = str("%.2f" % sum) + " | " + str(p1_goals) + "G"

func p2_receive_reward(reward: float):
	if not p2_aic:
		update_rand_p2_goals()
		return
	p2_aic.reward += reward
	p2_rewards.append(reward)
	if p2_rewards.size() > 60:
		p2_rewards.pop_front()
	var sum = p2_rewards.reduce(func(acc, x): return acc + x, 0) / 60
	info_label_2.text = str(p2_goals) + "G" + " | " + str("%.2f" % sum)

func update_rand_p2_goals():
	info_label_2.text = str(p2_goals) + "G" + " | Random"

func reset_all():
	# print("P1: ", p1_aic.needs_reset, ";  P2: ", p2_aic.needs_reset)
	reset_field()
	puck_pos_times_p1.clear()
	puck_pos_times_p1.append(Time.get_ticks_msec())
	puck_pos_times_p2.clear()
	puck_pos_times_p2.append(Time.get_ticks_msec())
	p1_aic.reset()
	if p2_aic:
		p2_aic.reset()

func on_goal_scored(team: int):
	var p1_reward = 0.0
	var p2_reward = 0.0
	if team == 1:
		p1_goals += 1
		p1_reward += GOAL_REWARD
		p1_aic.is_success = true
		if p2_aic:
			p2_reward -= GOAL_REWARD
			p2_aic.is_success = false
		else:
			update_rand_p2_goals()
	else:
		p2_goals += 1
		if p2_aic:
			p1_reward += GOAL_REWARD
			p2_aic.is_success = true
		else:
			update_rand_p2_goals()
		p2_reward -= GOAL_REWARD
		p1_aic.is_success = false

	p1_aic.done = true
	p1_aic.needs_reset = true
	if p2_aic:
		p2_aic.done = true
		p2_aic.needs_reset = true
	p1_receive_reward(p1_reward)
	p2_receive_reward(p2_reward)
# func _physics_process(delta):
# 	super._physics_process(delta)