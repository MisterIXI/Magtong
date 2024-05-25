extends AbilityBase
class_name OrbitLock

var joints: Array[PinJoint2D] = []
var lines: Array[Line2D] = []
var active_lines: Array[bool] = []
@export var max_orbit_timer: Timer
@export var orbit_cd: Timer
var is_active: bool = false

func _setup():
	for i in range(map.pucks.size()):
		if multiplayer.is_server():
			var joint = PinJoint2D.new()
			joint.process_mode = Node.PROCESS_MODE_DISABLED
			joint.disable_collision = false
			joint.softness = 1
			joints.append(joint)
			add_child(joint)
		var line = Line2D.new()
		line.visible = false
		lines.append(line)
		active_lines.append(false)
		add_child(line)
	map.goal_scored.connect(self._ability_reset.unbind(1))


func _ability_button_down():
	# check for cd
	if not orbit_cd.is_stopped():
		return
	var in_distance: Array[bool] = []
	for i in range(map.pucks.size()):
		var puck := map.pucks[i]
		if puck.global_position.distance_to(player.global_position) < self.settings.orbitlock_max_dist:
			in_distance.append(true)
		else:
			in_distance.append(false)
	activate_ability.rpc(in_distance)

func _ability_button_up():
	if is_active:
		deactivate_ability.rpc()

func _ability_reset():
	if is_active:
		deactivate_ability.rpc()
	orbit_cd.stop()
	max_orbit_timer.stop()

func _on_max_orbit_timer_timeout():
	if is_active:
		deactivate_ability.rpc()

func _process(_delta):
	if is_active:
		for i in range(map.pucks.size()):
			if active_lines[i]:
				lines[i].points = [Vector3.ZERO, map.pucks[i].global_position - player.global_position]

@rpc("authority", "call_local", "reliable")
func activate_ability(active_pucks: Array):
	active_lines = active_pucks
	var has_hit_something = false
	for i in range(map.pucks.size()):
		var puck := map.pucks[i]
		if puck.global_position.distance_to(player.global_position) < self.settings.orbitlock_max_dist:
			if multiplayer.is_server():
				joints[i].node_a = player.get_path()
				joints[i].node_b = puck.get_path()
			active_lines[i] = true
			lines[i].visible = true
			lines[i].points = [Vector3.ZERO, map.pucks[i].global_position - player.global_position]
			has_hit_something = true
	if not has_hit_something:
		# TODO: play fizzle effect
		pass
	is_active = true
	if multiplayer.is_server():
		max_orbit_timer.start(self.settings.orbitlock_max_duration)

@rpc("authority", "call_local", "reliable")
func deactivate_ability():
	if is_active:
		for i in range(map.pucks.size()):
			if multiplayer.is_server():
				joints[i].node_b = ""
			active_lines[i] = false
			lines[i].visible = false
		is_active = false
	orbit_cd.start(self.settings.orbitlock_cooldown)

