class_name Teams
## Team colors and names, index = team - 1. Team 1 plays on the left, team 2 on the right.
## Not red and blue: those are the magnet polarity colors (plus / minus), and playtesters mixed them up (15.11).
## The goals, lobby team areas (map_default.tscn) and the score bar (match_clock.svg) use the same colors.

const COLORS: Array[Color] = [Color(1.0, 0.541, 0.0), Color(0.0, 0.784, 0.863)] # #FF8A00, #00C8DC
const NAMES: PackedStringArray = ["Orange", "Cyan"]

static func color(team: int) -> Color:
	return COLORS[clampi(team - 1, 0, COLORS.size() - 1)]
