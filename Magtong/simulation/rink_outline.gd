@tool
extends Node2D
class_name RinkOutline
## Hockey rink shape for the simulation: a rectangle with concave rounded corners and a goal pocket
## inset into each short side. Builds the static line segments the simulation collides against.
## Defaults are measured from the old hand placed colliders of map_default.

## inner half extents of the rink (distance from the center to the side walls / top and bottom walls)
@export var half_size: Vector2 = Vector2(538.0, 285.0):
	set(value):
		half_size = value
		queue_redraw()
@export var corner_radius: float = 114.0:
	set(value):
		corner_radius = value
		queue_redraw()
@export_range(2, 64) var corner_segments: int = 16:
	set(value):
		corner_segments = value
		queue_redraw()
## half the height of the goal mouth
@export var goal_half_width: float = 87.0:
	set(value):
		goal_half_width = value
		queue_redraw()
## how far the goal pocket reaches behind the side wall
@export var goal_depth: float = 33.0:
	set(value):
		goal_depth = value
		queue_redraw()
## a goal counts once the puck center is this far behind the goal mouth
@export var goal_line_offset: float = 0.0:
	set(value):
		goal_line_offset = value
		queue_redraw()
## center line that only blocks players (used in matches, not in the lobby)
@export var has_divider: bool = true:
	set(value):
		has_divider = value
		queue_redraw()
@export var debug_draw_in_game: bool = false:
	set(value):
		debug_draw_in_game = value
		queue_redraw()

# segment endpoints are snapped so every machine ends up with bit identical geometry
const SNAP: float = 1.0 / 64.0

## Closed outline, clockwise (in screen coordinates), starting at the top wall.
func build_outline() -> PackedVector2Array:
	var hw := half_size.x
	var hh := half_size.y
	var r := minf(corner_radius, minf(hw, hh - goal_half_width))
	var gw := goal_half_width
	var gd := goal_depth
	var points := PackedVector2Array()
	# top right corner
	_add_arc(points, Vector2(hw - r, -hh + r), r, -PI / 2, 0.0)
	# right goal pocket
	points.append(Vector2(hw, -gw))
	points.append(Vector2(hw + gd, -gw))
	points.append(Vector2(hw + gd, gw))
	points.append(Vector2(hw, gw))
	# bottom right corner
	_add_arc(points, Vector2(hw - r, hh - r), r, 0.0, PI / 2)
	# bottom left corner
	_add_arc(points, Vector2(-hw + r, hh - r), r, PI / 2, PI)
	# left goal pocket
	points.append(Vector2(-hw, gw))
	points.append(Vector2(-hw - gd, gw))
	points.append(Vector2(-hw - gd, -gw))
	points.append(Vector2(-hw, -gw))
	# top left corner
	_add_arc(points, Vector2(-hw + r, -hh + r), r, PI, PI * 1.5)
	for i in points.size():
		points[i] = points[i].snapped(Vector2(SNAP, SNAP))
	return points

func _add_arc(points: PackedVector2Array, center: Vector2, radius: float, from: float, to: float) -> void:
	for i in corner_segments + 1:
		var angle := lerpf(from, to, float(i) / corner_segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

func get_divider() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -half_size.y), Vector2(0, half_size.y)])

## x position of the goal line on the right side (the left one is mirrored)
func get_goal_line_x() -> float:
	return snappedf(half_size.x + goal_line_offset, SNAP)

func _draw():
	if not Engine.is_editor_hint() and not debug_draw_in_game:
		return
	var outline := build_outline()
	outline.append(outline[0])
	draw_polyline(outline, Color(0, 1, 1, 0.8), 2.0)
	for p in outline:
		draw_circle(p, 2.0, Color(0, 1, 1, 0.8))
	if has_divider:
		var d := get_divider()
		draw_line(d[0], d[1], Color(1, 0.5, 0, 0.6), 2.0)
	var gx := get_goal_line_x()
	draw_line(Vector2(gx, -goal_half_width), Vector2(gx, goal_half_width), Color(1, 0, 0, 0.8), 2.0)
	draw_line(Vector2(-gx, -goal_half_width), Vector2(-gx, goal_half_width), Color(1, 0, 0, 0.8), 2.0)
