class_name Door
extends Node3D

@export var door_hinge: Node3D
@export var open_angle_deg: float = 90.0
@export var is_open: bool = true

var _initial_rotation_y: float = 0.0
var _tween: Tween

func _ready() -> void:
	if door_hinge == null:
		door_hinge = self
	_initial_rotation_y = door_hinge.rotation_degrees.y
	# Pre-open door by default for seamless room traversal
	if is_open:
		door_hinge.rotation_degrees.y = _initial_rotation_y + open_angle_deg

func toggle_door() -> void:
	is_open = !is_open
	var target_angle = _initial_rotation_y + (open_angle_deg if is_open else 0.0)
	
	if _tween and _tween.is_running():
		_tween.kill()
		
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(door_hinge, "rotation_degrees:y", target_angle, 0.8)
