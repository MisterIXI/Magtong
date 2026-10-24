extends Resource
class_name PlayerSettings

# category: Magnets
@export_group("Magnets")
@export var magnet_force: float = 100
@export var magnet_dropoff: Curve
@export var magnet_range: float = 50 
@export var pulse_range: float = 150
# category: controller
@export_group("Controller")
@export var speed: float = 50
@export var accell: float = 50
@export var pulse_cooldown: float = 1.0
# category: Physics (defaults match the old RigidBody2D setup)
@export_group("Physics")
@export var player_radius: float = 22.0
@export var puck_radius: float = 16.0
@export var player_mass: float = 5.0
@export var puck_mass: float = 1.0
@export var linear_damp: float = 0.1
@export_range(0, 1, 0.01) var wall_bounce: float = 0.0
@export_range(0, 1, 0.01) var body_bounce: float = 0.0
@export var max_speed: float = 3000.0
## if true, the magnet pulls/pushes the player as well as the puck
@export var magnet_recoil: bool = true

# category: Visuals
@export_group("Visuals")
@export var viz_idle_speed: float = 3
@export var viz_acc: float = 5
@export var viz_max_speed: float = 10
@export var pol_shader_change_dur: float = 0.3
@export var team_colors = [
	Color(1,0,0),
	Color(0,0,1),
	Color(0,1,0),
	Color(1,1,0),
	Color(1,0,1),
	Color(0,1,1),
]

@export_category("Abilities")
@export_group("Impulse")
@export var impulse_cooldown: float = 1
@export var impulse_mult: float = 1.0
