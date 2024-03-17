class_name Player
extends Object

var id: int
var remote: bool
var input_name: String
var ready: bool
var team: int
var player_icon_id: int
var input_icon_id: int

func _init(player_id: int, is_remote: bool, input_name: String):
    self.id = player_id
    self.remote = is_remote
    self.input_name = input_name
    self.ready = false
    self.team = 0
    self.player_icon_id = 0
    