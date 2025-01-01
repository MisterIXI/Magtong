extends AIController2D
class_name AIController

@onready var player: PlayerBody = get_parent()
@onready var map_script: AIMapScript = get_node("../../../../.")
var mult: float = 0.0
var puck: Puck
var other_player: PlayerBody
var own_goal: Area2D
var other_goal: Area2D
var attempt_start_time: int = 0
const MAP_MULT: float = 600.0

func _ready():
	reset_after = 500
	super._ready()
	mult = 1.0 if player.player_input.team == 1 else -1.0
	puck = map_script.pucks[0]
	other_player = map_script.players[1 if player.player_input.team == 1 else 0][0]
	own_goal = map_script.goal_t1 if player.player_input.team == 1 else map_script.goal_t2
	other_goal = map_script.goal_t2 if player.player_input.team == 1 else map_script.goal_t1

func get_obs() -> Dictionary:
	# division by 600 to scale positions roughly to -1 to 1
	return {"obs": [
		# own pos
		player.position.x * mult / MAP_MULT,
		player.position.y * mult / MAP_MULT,
		# own vel
		player.linear_velocity.x * mult,
		player.linear_velocity.y * mult,
		# enemy pos
		other_player.position.x * mult / MAP_MULT,
		other_player.position.y * mult / MAP_MULT,
		# enemy vel
		other_player.linear_velocity.x * mult,
		other_player.linear_velocity.y * mult,
		# puck pos
		puck.position.x * mult / MAP_MULT,
		puck.position.y * mult / MAP_MULT,
		# puck vel
		puck.linear_velocity.x * mult,
		puck.linear_velocity.y * mult,
		# pulse cooldown
		player.pulse_timer.time_left,
		# skill cooldown
		player.current_ability.cd_timer.time_left,
		# puck polarity
		1 if puck.is_plus_pol else -1
	]}


func get_reward() -> float:
	# set rewards for player
	var result = reward
	zero_reward()
	# reward for ball close to enemy goal
	result += (1 - ((puck.position * mult).distance_to(other_goal.position * mult) / MAP_MULT)) * 10
	if player.player_input.team == 1:
		map_script.p1_rewards_received(result)
	else:
		map_script.p2_rewards_received(result)
	# time penalty
	result += -(Time.get_ticks_msec() - attempt_start_time) / 1000.0 + 1
	return result


func get_action_space() -> Dictionary:
	return {
		"move": {"size": 2, "action_type": "continuous"},
		"magnetism": {"size": 2, "action_type": "continuous"},
		"switch": {"size": 1, "action_type": "discrete"},
		"ability": {"size": 1, "action_type": "discrete"},
	}


func set_action(action) -> void:
	var input_info = InputInfo.new()
	# moveX
	input_info.input_type = InputInfo.InputType.MOVE_X
	input_info.axis_value = action["move"][0]
	player.on_input(input_info)
	# moveY
	input_info.input_type = InputInfo.InputType.MOVE_Y
	input_info.axis_value = action["move"][1]
	player.on_input(input_info)
	# magnetismX
	input_info.input_type = InputInfo.InputType.PLUS
	input_info.axis_value = action["magnetism"][0]
	player.on_input(input_info)
	# magnetismY
	input_info.input_type = InputInfo.InputType.MINUS
	input_info.axis_value = action["magnetism"][1]
	player.on_input(input_info)

	input_info.axis_value = 0.0
	# switch
	input_info.input_type = InputInfo.InputType.PRIMARY
	input_info.is_pressed = action["switch"] == 1
	player.on_input(input_info)
	# ability
	input_info.input_type = InputInfo.InputType.SECONDARY
	input_info.is_pressed = action["ability"] == 1
	player.on_input(input_info)

func _physics_process(_delta):
	n_steps += 1
	if n_steps > reset_after:
		# print("N_steps: ", n_steps)
		needs_reset = true
	if needs_reset:
		# print("Needs_reset: ", needs_reset)
		map_script.reset_all()

func reset():
	n_steps = 0
	needs_reset = false
	attempt_start_time = Time.get_ticks_msec()
	pass



