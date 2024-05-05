extends Resource
class_name MapParameters

@export var map_image: Texture2D

@export_range(2,10) var team_count: int = 2
@export var team_colors: Array[Color] = [Color(1,0,0,1), Color(0,0,1,1)]
@export var team_positions: Array[Vector2] = [Vector2(0.5,0.25), Vector2(0.5,0.25)]