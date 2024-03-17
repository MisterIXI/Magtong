extends Resource
class_name IconPack

enum ui_icon_ids{
    globe = 0,
    gamepade = 1,
    keyboard = 2,
    exit_door = 3
}

@export var player_icons: Array[Texture2D] = []
@export var ui_icons: Array[Texture2D] = []
