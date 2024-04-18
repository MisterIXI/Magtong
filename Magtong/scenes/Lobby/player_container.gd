extends Panel
class_name PlayerContainer

@export var main_content: Control
@export var join_text: Label

@export var player_label: Label

@export var input_icon: TextureRect
@export var input_label: Label

@export var player_icon: TextureRect

@export var button_left: Button
@export var button_right: Button
@export var check_box_ready: CheckBox
@export var button_leave: Button

@export var selection_tweener: Node

var player_input: PlayerInput = null
var selected_option: Control = null
var selected_skin: int = 0
var is_ready: bool = false
func _ready():
	join_text.set_deferred("visible", true)
	main_content.set_deferred("visible", false)


func set_player(player_input: PlayerInput) -> void:
	join_text.set_deferred("visible", false)
	self.player_input = player_input
	var player_id := str(player_input.peer_id) + "_" + str(player_input.device_id)
	player_input.input_received.connect(_receive_input)
	# check if online player
	if player_input.peer_id != multiplayer.get_unique_id():
		# is online player
		input_icon.texture = globResourceManager.icons.ui_icons[IconPack.IconIDs.GLOBE]
		player_label.text = "Player: " + str(player_id)
		input_label.text = "Online"
	else:
		# is local player
		if player_input.device_id == - 1:
			# is keyboard
			input_icon.texture = globResourceManager.icons.ui_icons[IconPack.IconIDs.KEYBOARD]
			player_label.text = "Player: " + str(player_id)
			input_label.text = "Keyboard"
		else:
			# is gamepad
			input_icon.texture = globResourceManager.icons.ui_icons[IconPack.IconIDs.GAMEPAD]
			player_label.text = "Player: " + str(player_id)
			input_label.text = "Gamepad " + str(player_input.device_id) 
	selected_option = check_box_ready
	selection_tweener.highlight_control(selected_option)

	main_content.set_deferred("visible", true)
	player_icon.texture = globResourceManager.icons.player_sprites[0]
	player_input.team = 0
	player_input.is_ready = false
	player_input.player_sprite_id = 0
	

func _exit_tree():
	if player_input != null:
		player_input.input_received.disconnect(_receive_input)

func _receive_input(input: InputInfo) -> void:
	assert(multiplayer.is_server())
	var old_selection = selected_option
	# check for button
	if input.input_type == InputInfo.InputType.PRIMARY and input.is_pressed:
		if selected_option == button_left:
			selected_skin = (selected_skin - 1) % globResourceManager.icons.player_sprites.size()
			player_input.player_sprite_id = selected_skin
			_change_skin.rpc(selected_skin)
		elif selected_option == button_right:
			selected_skin = (selected_skin + 1) % globResourceManager.icons.player_sprites.size()
			player_input.player_sprite_id = selected_skin
			_change_skin.rpc(selected_skin)
		elif selected_option == check_box_ready:
			# ready
			if is_ready:
				is_ready = false
				check_box_ready.button_pressed = false
			else:
				is_ready = true
				check_box_ready.button_pressed = true
			player_input.is_ready = is_ready
			get_node("/root/Lobby").check_for_ready()
			_change_ready.rpc(is_ready)
	elif input.input_type == InputInfo.InputType.MOVE_Y and input.axis_value != 0:
		var move_up = input.axis_value > 0 
		if move_up:
			if selected_option == button_left or selected_option == button_right:
				selected_option = button_leave
			elif selected_option == check_box_ready:
				selected_option = button_right
			elif selected_option == button_leave:
				selected_option = check_box_ready
		else:
			if selected_option == button_left or selected_option == button_right:
				selected_option = check_box_ready
			elif selected_option == check_box_ready:
				selected_option = button_leave
			elif selected_option == button_leave:
				selected_option = button_right
	elif input.input_type == InputInfo.InputType.MOVE_X and input.axis_value != 0:
		if selected_option == button_left:
			selected_option = button_right
		elif selected_option == button_right:
			selected_option = button_left
	if selected_option != old_selection:
		if selected_option == button_left:
			_select_option.rpc(0)
		elif selected_option == button_right:
			_select_option.rpc(1)
		elif selected_option == check_box_ready:
			_select_option.rpc(2)
		elif selected_option == button_leave:
			_select_option.rpc(3)

@rpc("any_peer", "call_local", "reliable")
func _select_option(option: int):
	if option == 0:
		selected_option = button_left
	elif option == 1:
		selected_option = button_right
	elif option == 2:
		selected_option = check_box_ready
	elif option == 3:
		selected_option = button_leave
	selection_tweener.highlight_control(selected_option)

@rpc("authority", "call_local", "reliable")
func _change_skin(skin: int):
	player_icon.texture = globResourceManager.icons.player_sprites[skin]
	
@rpc("authority", "call_local", "reliable")
func _change_ready(new_ready_state: bool):
	check_box_ready.button_pressed = new_ready_state
