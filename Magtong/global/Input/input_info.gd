class_name InputInfo
var input_type : InputType
var is_pressed: bool 
var axis_value: float

func _init():
	self.input_type = InputType.EMPTY
	self.is_pressed = false
	self.axis_value = 0.0

func _to_string():
	var result = "InputInfo: ("
	result += "input_type: " + str(self.input_type) + ", "
	result += "is_pressed: " + str(self.is_pressed) + ", "
	result += "axis_value: " + str(self.axis_value) + ")"
	return result
	
enum InputType{
	# default (empty)
	EMPTY = 0,
	# axis inputs
	MOVE_Y = 1,
	MOVE_X = 2,
	PLUS = 3,
	MINUS = 4,
	# button inputs
	PRIMARY = 5,
	SECONDARY = 6
}
