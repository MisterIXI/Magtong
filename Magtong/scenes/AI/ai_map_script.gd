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
const GOAL_REWARD = 5.0

func _ready():
	super._ready()
	globGameManager.toggle_message_panel()
	# local server setup
	# globGameManager.host_game(true)
	disable_lobby_features()
	pucks.append(spawn_puck())
	# spawn players
	setup_ai_players()
	reset_field()
	goal_scored.connect(on_goal_scored)

func setup_ai_players():
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
	p2_aic = AIController.new()
	p2.add_child(p2_aic)
	# var sync_node = Sync.new()
	# p1.add_child(sync_node)
	p1.pulse_emitted.connect(on_pulse_from)
	p2.pulse_emitted.connect(on_pulse_from)

func p1_rewards_received(reward: float):
	p1_rewards.append(reward)
	if p1_rewards.size() > 60:
		p1_rewards.pop_front()
	var sum = p1_rewards.reduce(func(acc, x): return acc + x, 0) / 60
	info_label_1.text = str("%.2f" % sum) + " | " + str(p1_goals) + "G"

func p2_rewards_received(reward: float):
	p2_rewards.append(reward)
	if p2_rewards.size() > 60:
		p2_rewards.pop_front()
	var sum = p2_rewards.reduce(func(acc, x): return acc + x, 0) / 60
	info_label_2.text = str(p2_goals) + "G" + " | " + str("%.2f" % sum)

func reset_all():
	# print("P1: ", p1_aic.needs_reset, ";  P2: ", p2_aic.needs_reset)
	reset_field()
	p1_aic.reset()
	p2_aic.reset()

func on_goal_scored(team: int):
	if team == 1:
		p1_goals += 1
		p1_aic.reward += GOAL_REWARD
		p2_aic.reward -= GOAL_REWARD
	else:
		p2_goals += 1
		p2_aic.reward += GOAL_REWARD
		p1_aic.reward -= GOAL_REWARD
	p1_aic.needs_reset = true
	p2_aic.needs_reset = true

# func _physics_process(delta):
# 	super._physics_process(delta)