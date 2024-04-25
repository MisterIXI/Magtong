extends Resource
class_name PlayerSettings

# category: Magnets
@export_group("Magnets")
@export var magnet_force: float = 100
@export var magnet_dropoff: Curve
@export var magnet_range: float = 50 
@export var pulse_range: float = 150
@export var impulse_mult: float = 1.0
# category: controller
@export_group("Controller")
@export var speed: float = 50
@export var accell: float = 50

# category: Visuals
@export_group("Visuals")
@export var viz_idle_speed: float = 3
@export var viz_acc: float = 5
@export var viz_max_speed: float = 10
