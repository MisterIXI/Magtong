extends Resource
class_name IconPack

enum IconIDs{
    GLOBE = 0,
    GAMEPAD = 1,
    KEYBOARD = 2,
    EXIT_DOOR = 3
}

@export var player_sprites: Array[Texture2D] = []
@export var ui_icons: Array[Texture2D] = []
