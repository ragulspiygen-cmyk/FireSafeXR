class_name SwingingLamp
extends Node3D

@export var swing_speed: float = 1.5
@export var swing_angle: float = 4.0

var _time: float = 0.0
var _initial_rot_z: float = 0.0

func _ready() -> void:
	_initial_rot_z = rotation_degrees.z

func _process(delta: float) -> void:
	_time += delta * swing_speed
	rotation_degrees.z = _initial_rot_z + sin(_time) * swing_angle
	rotation_degrees.x = cos(_time * 0.7) * (swing_angle * 0.5)
