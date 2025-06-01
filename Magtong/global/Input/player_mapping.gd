extends Node
class_name PlayerMapping

var player_id: int
var is_keyboard: bool
var k_up: Key
var k_down: Key
var k_left: Key
var k_right: Key
var k_plus: Key
var k_minus: Key
var k_primary: Key
var k_secondary: Key
var k_menu: Key
var k_aux_left: Key
var k_aux_right: Key
var j_x_axis: JoyAxis
var j_y_axis: JoyAxis
var j_plus: JoyAxis
var j_plusB: JoyButton
var j_minus: JoyAxis
var j_minusB: JoyButton
var j_primary: JoyButton
var j_secondary: JoyButton
var j_menu: JoyButton
var j_d_left: JoyButton
var j_d_right: JoyButton
var j_b_left: JoyButton
var j_b_right: JoyButton
var j_aux_left: JoyButton
var j_aux_right: JoyButton

var k_right_pressed: bool = false
var k_left_pressed: bool = false
var k_up_pressed: bool = false
var k_down_pressed: bool = false

func _init(player_id: int, is_keyboard: bool):
	self.player_id = player_id
	self.is_keyboard = is_keyboard
	if is_keyboard:
		set_keyboard_mapping1()
	else:
		set_gamepad_mapping1()

func set_gamepad_mapping1():
	self.j_x_axis = JOY_AXIS_LEFT_X
	self.j_y_axis = JOY_AXIS_LEFT_Y
	self.j_plus = JOY_AXIS_TRIGGER_RIGHT
	self.j_plusB = JOY_BUTTON_RIGHT_SHOULDER
	self.j_minus = JOY_AXIS_TRIGGER_LEFT
	self.j_minusB = JOY_BUTTON_LEFT_SHOULDER
	self.j_primary = JOY_BUTTON_A
	self.j_secondary = JOY_BUTTON_B
	self.j_menu = JOY_BUTTON_START
	self.j_aux_left = JOY_BUTTON_DPAD_LEFT
	self.j_aux_right = JOY_BUTTON_DPAD_RIGHT
	self.j_b_left = JOY_BUTTON_LEFT_SHOULDER
	self.j_b_right = JOY_BUTTON_RIGHT_SHOULDER

func set_keyboard_mapping1():
	self.k_up = KEY_W
	self.k_down = KEY_S
	self.k_left = KEY_A
	self.k_right = KEY_D
	self.k_plus = KEY_J
	self.k_minus = KEY_K
	self.k_primary = KEY_SPACE
	self.k_secondary = KEY_L
	self.k_menu = KEY_ESCAPE
	self.k_aux_left = KEY_U
	self.k_aux_right = KEY_O

func set_keyboard_mapping2():
	self.k_up = KEY_UP
	self.k_down = KEY_DOWN
	self.k_left = KEY_LEFT
	self.k_right = KEY_RIGHT
	self.k_plus = KEY_K
	self.k_minus = KEY_L
	self.k_primary = KEY_J
	self.k_secondary = KEY_I
	self.k_menu = KEY_NUMBERSIGN
	self.k_aux_left = KEY_COMMA
	self.k_aux_right = KEY_PERIOD

func check_input(event: InputEvent) -> InputInfo:
	# check keyboard
	var input = InputInfo.new()

	if self.is_keyboard and event is InputEventKey:
		var key_event = event as InputEventKey
		var keycode = key_event.keycode
		# print(key_event)
		if key_event.keycode == self.k_up:
			self.k_up_pressed = key_event.pressed
			input.input_type = InputInfo.InputType.MOVE_Y
			input.axis_value = average_axis(self.k_up_pressed, self.k_down_pressed)
		elif key_event.keycode == self.k_down:
			self.k_down_pressed = key_event.pressed
			input.input_type = InputInfo.InputType.MOVE_Y
			input.axis_value = average_axis(self.k_up_pressed, self.k_down_pressed)
		elif key_event.keycode == self.k_left:
			self.k_left_pressed = key_event.pressed
			input.input_type = InputInfo.InputType.MOVE_X
			input.axis_value = average_axis(self.k_left_pressed, self.k_right_pressed)
		elif key_event.keycode == self.k_right:
			self.k_right_pressed = key_event.pressed
			input.input_type = InputInfo.InputType.MOVE_X
			input.axis_value = average_axis(self.k_left_pressed, self.k_right_pressed)
		elif key_event.keycode == self.k_plus:
			input.input_type = InputInfo.InputType.PLUS
			input.axis_value = 1.0 if key_event.pressed else 0.0
		elif key_event.keycode == self.k_minus:
			input.input_type = InputInfo.InputType.MINUS
			input.axis_value = 1.0 if key_event.pressed else 0.0
		elif key_event.keycode == self.k_primary:
			input.input_type = InputInfo.InputType.PRIMARY
			input.is_pressed = key_event.pressed
		elif key_event.keycode == self.k_secondary:
			input.input_type = InputInfo.InputType.SECONDARY
			input.is_pressed = key_event.pressed
		elif key_event.keycode == self.k_menu:
			input.input_type = InputInfo.InputType.MENU
			input.is_pressed = key_event.pressed
		elif key_event.keycode == self.k_aux_left:
			input.input_type = InputInfo.InputType.AUX_LEFT
			input.is_pressed = key_event.pressed
		elif key_event.keycode == self.k_aux_right:
			input.input_type = InputInfo.InputType.AUX_RIGHT
			input.is_pressed = key_event.pressed
		# elif key_event.keycode == self.k_b_left:
		# 	input.input_type = InputInfo.InputType.B_LEFT
		# 	input.is_pressed = key_event.pressed
		# elif key_event.keycode == self.k_b_right:
		# 	input.input_type = InputInfo.InputType.B_RIGHT
		# 	input.is_pressed = key_event.pressed
	# check joystick axis
	elif not self.is_keyboard and event is InputEventJoypadMotion:
		var joy_event = event as InputEventJoypadMotion
		if joy_event.axis == self.j_x_axis:
			input.input_type = InputInfo.InputType.MOVE_X
			input.axis_value = joy_event.axis_value
		elif joy_event.axis == self.j_y_axis:
			input.input_type = InputInfo.InputType.MOVE_Y
			input.axis_value = joy_event.axis_value
		elif joy_event.axis == self.j_plus:
			input.input_type = InputInfo.InputType.PLUS
			input.axis_value = joy_event.axis_value
		elif joy_event.axis == self.j_minus:
			input.input_type = InputInfo.InputType.MINUS
			input.axis_value = joy_event.axis_value
	# check joystick buttons
	elif not self.is_keyboard and event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.button_index == self.j_plusB:
			input.input_type = InputInfo.InputType.PLUS
			input.axis_value = 1.0 if joy_event.pressed else 0.0
		elif joy_event.button_index == self.j_minusB:
			input.input_type = InputInfo.InputType.MINUS
			input.axis_value = 1.0 if joy_event.pressed else 0.0
		elif joy_event.button_index == self.j_primary:
			input.input_type = InputInfo.InputType.PRIMARY
			input.is_pressed = joy_event.pressed
		elif joy_event.button_index == self.j_secondary:
			input.input_type = InputInfo.InputType.SECONDARY
			input.is_pressed = joy_event.pressed
		elif joy_event.button_index == self.j_menu:
			input.input_type = InputInfo.InputType.MENU
			input.is_pressed = joy_event.pressed
		elif joy_event.button_index == self.j_aux_left:
			input.input_type = InputInfo.InputType.AUX_LEFT
			input.is_pressed = joy_event.pressed
		elif joy_event.button_index == self.j_aux_right:
			input.input_type = InputInfo.InputType.AUX_RIGHT
			input.is_pressed = joy_event.pressed
		elif joy_event.button_index == self.j_b_left:
			input.input_type = InputInfo.InputType.B_LEFT
			input.is_pressed = joy_event.pressed
		elif joy_event.button_index == self.j_b_right:
			input.input_type = InputInfo.InputType.B_RIGHT
			input.is_pressed = joy_event.pressed

	if input.input_type == InputInfo.InputType.EMPTY:
		return null
	else: 
		# implement deadzone
		var dead_zone: float = 0.3
		if input.axis_value < dead_zone and input.axis_value > -dead_zone:
			input.axis_value = 0.0
		return input

func average_axis(negative: bool, positive: bool) -> float:
	if positive and negative:
		return 0.0
	elif positive:
		return 1.0
	elif negative:
		return -1.0
	else:
		return 0.0