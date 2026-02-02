class_name InputInfo
var input_type : InputType
var device_id: int
var peer_id: int
var is_pressed: bool 
var axis_value: float

func _init(dict:Dictionary = {}):
	if dict.size() > 0:
		self.input_type = dict["input_type"]
		self.device_id = dict["device_id"]
		self.peer_id = dict["peer_id"]
		self.is_pressed = dict["is_pressed"]
		self.axis_value = dict["axis_value"]
	else:
		self.input_type = InputType.EMPTY
		self.device_id = 0
		self.peer_id = -1
		self.is_pressed = false
		self.axis_value = 0.0

func _to_string():
	var result = "InputInfo: ("
	result += "input_type: " + str(self.input_type) + ", "
	result += "device_id: " + str(self.device_id) + ", "
	result += "peer_id: " + str(self.peer_id) + ", "
	result += "is_pressed: " + str(self.is_pressed) + ", "
	result += "axis_value: " + str(self.axis_value) + ")"
	return result
	
func to_dict() -> Dictionary:
	var result = {
		"input_type": self.input_type,
		"device_id": self.device_id,
		"peer_id": self.peer_id,
		"is_pressed": self.is_pressed,
		"axis_value": self.axis_value
	}
	return result

func pack_byte_arr() -> PackedByteArray:
	var arr = PackedByteArray()
	arr.resize(11)
	arr.encode_u8(0, input_type)
	arr.encode_s8(1, device_id)
	arr.encode_u32(2, peer_id)
	arr.encode_u8(6, is_pressed)
	arr.encode_float(7, axis_value)
	return arr

static func from_byte_arr(arr: PackedByteArray) -> InputInfo:
	var result = InputInfo.new()
	result.input_type = arr.decode_u8(0)
	result.device_id = arr.decode_s8(1)
	result.peer_id = arr.decode_u32(2)
	result.is_pressed = bool(arr[6])
	result.axis_value = arr.decode_float(7)
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
	# Auxiliary inputs
	AUX_LEFT = 8,
	AUX_RIGHT = 9,
	# BUMPER
	B_LEFT = 10,
	B_RIGHT = 11,
}
