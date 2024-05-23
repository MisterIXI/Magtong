class_name InputInfo
var input_type : InputType
var is_pressed: bool 
var axis_value: float

func _init(dict:Dictionary = {}):
	if dict.size() > 0:
		self.input_type = dict["input_type"]
		self.is_pressed = dict["is_pressed"]
		self.axis_value = dict["axis_value"]
	else:
		self.input_type = InputType.EMPTY
		self.is_pressed = false
		self.axis_value = 0.0

func _to_string():
	var result = "InputInfo: ("
	result += "input_type: " + str(self.input_type) + ", "
	result += "is_pressed: " + str(self.is_pressed) + ", "
	result += "axis_value: " + str(self.axis_value) + ")"
	return result
	
func to_dict() -> Dictionary:
	var result = {
		"input_type": self.input_type,
		"is_pressed": self.is_pressed,
		"axis_value": self.axis_value
	}
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
	SECONDARY = 6,
	MENU = 7,
	# DPAD
	D_LEFT = 8,
	D_RIGHT = 9,
	# BUMPER
	B_LEFT = 10,
	B_RIGHT = 11,
}
