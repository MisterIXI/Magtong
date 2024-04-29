extends Panel
class_name PlayerContainer

@export var main_content: Control
@export var join_text: Label

@export var player_label: Label

@export var input_icon: TextureRect
@export var input_label: Label

@export var player_icon: TextureRect

@export var start_selection: Control
@export var button_left: Button
@export var button_right: Button
@export var check_box_ready: CheckBox
@export var button_leave: Button
@onready var selectable_controls: Array[Control] = [button_left, button_right, check_box_ready, button_leave]

@export var selection_tweener: SelectionTweener

var player_input: PlayerInput = null
var selected_option: Control = null
var selected_skin: int = 0
var is_ready: bool = false
var last_y_input: float = 0
var last_x_input: float = 0

func _ready():
	join_text.set_deferred("visible", true)
	main_content.set_deferred("visible", false)
	_select_option(selectable_controls.find(start_selection))

func set_player(input_dict: Dictionary, readable_peer_id: int) -> void:
	if not multiplayer.is_server():
		var pi = PlayerInput.new(input_dict["peer_id"], input_dict["device_id"], input_dict["is_ready"])
		pi.from_dict(input_dict)
		player_input = pi
	join_text.set_deferred("visible", false)
	var player_name := str(readable_peer_id) + "_" + str(player_input.device_id)
	# check if online player
	if player_input.peer_id != multiplayer.get_unique_id():
		# is online player
		input_icon.texture = globResourceManager.icons.ui_icons[IconPack.IconIDs.GLOBE]
		player_label.text = "Player: " + str(player_name)
		input_label.text = "Online"
	else:
		# is local player
		if player_input.device_id == - 1:
			# is keyboard
			input_icon.texture = globResourceManager.icons.ui_icons[IconPack.IconIDs.KEYBOARD]
			player_label.text = "Player: " + str(player_name)
			input_label.text = "Keyboard"
		else:
			# is gamepad
			input_icon.texture = globResourceManager.icons.ui_icons[IconPack.IconIDs.GAMEPAD]
			player_label.text = "Player: " + str(player_name)
			input_label.text = "Gamepad " + str(player_input.device_id) 
	selected_option = start_selection
	selection_tweener.highlight_control(selected_option)

	main_content.set_deferred("visible", true)
	player_icon.texture = globResourceManager.icons.player_sprites[player_input.player_sprite_id]
	check_box_ready.button_pressed = player_input.is_ready

func connect_player(player_input: PlayerInput):
	self.player_input = player_input
	player_input.input_received.connect(_receive_input)

func _exit_tree():
	if player_input != null:
		player_input.input_received.disconnect(_receive_input)

func _receive_input(input: InputInfo) -> void:
	assert(multiplayer.is_server())
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
	elif input.input_type == InputInfo.InputType.MOVE_Y:
		# min max axis value (-1, 0, 1)
		var axis_val = -1 if input.axis_value < 0 else (1 if input.axis_value > 0 else 0)
		if axis_val != last_y_input:
			last_y_input = axis_val
			if axis_val > 0:
				if not selected_option.focus_neighbor_bottom.is_empty():
					_select_option.rpc(selectable_controls.find(selected_option.get_node(selected_option.focus_neighbor_bottom)))
			elif axis_val < 0:
				if not selected_option.focus_neighbor_top.is_empty():
					_select_option.rpc(selectable_controls.find(selected_option.get_node(selected_option.focus_neighbor_top)))
	elif input.input_type == InputInfo.InputType.MOVE_X:
		var axis_val = -1 if input.axis_value < 0 else (1 if input.axis_value > 0 else 0)
		if axis_val != last_x_input:
			last_x_input = axis_val
			if axis_val > 0:
				if not selected_option.focus_neighbor_right.is_empty():
					_select_option.rpc(selectable_controls.find(selected_option.get_node(selected_option.focus_neighbor_right)))
			elif axis_val < 0:
				if not selected_option.focus_neighbor_left.is_empty():
					_select_option.rpc(selectable_controls.find(selected_option.get_node(selected_option.focus_neighbor_left)))

@rpc("any_peer", "call_local", "reliable")
func _select_option(option: int):
	selected_option = selectable_controls[option]
	selection_tweener.highlight_control(selected_option)

@rpc("authority", "call_local", "reliable")
func _change_skin(skin: int):
	player_icon.texture = globResourceManager.icons.player_sprites[skin]
	
@rpc("authority", "call_local", "reliable")
func _change_ready(new_ready_state: bool):
	check_box_ready.button_pressed = new_ready_state
