extends Control
@onready var input_manager: InputManager = globInputManager
@export var player_container: PackedScene
@export var lobby_container: HFlowContainer
var current_container: PlayerContainer
func _ready():
	create_new_container()

func check_for_ready():
	assert(multiplayer.is_server())
	print("Check for ready...")
	# check if all players are ready
	var is_ready = true
	if input_manager.total_player_count() < 2:
		# not enough players
		is_ready = false
	else:
		for peer in input_manager.player_inputs:
			for player_input in input_manager.player_inputs[peer]:
				if not input_manager.player_inputs[peer][player_input].is_ready:
					is_ready = false
					break
	if is_ready:
		# all players are ready, start the lobby countdown
		globGameManager.start_countdown()
	else:
		# in case someone unreadied, cancel the countdown
		globGameManager.cancel_countdown()

func set_current_container(input: PlayerInput):
	current_container.set_player(input)
	create_new_container()

func create_new_container():
	var new_player_container = player_container.instantiate()
	new_player_container.set_name("PlayerContainer")
	lobby_container.add_child(new_player_container)
	current_container = new_player_container


