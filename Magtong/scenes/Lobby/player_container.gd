extends Panel

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



func set_player(player: Player) -> void:
	join_text.set_deferred("visible", false)
	main_content.set_deferred("visible", true)
	player_label.set_text("Player " + str(player.id))
	_set_player_icon(player.player_icon_id)
	input_icon.texture = glob_resource_manager.icons.input_icons[player.input_icon_id]

func _set_player_icon(id: int):
	player_icon.texture = glob_resource_manager.icons.player_icons[id]

	

