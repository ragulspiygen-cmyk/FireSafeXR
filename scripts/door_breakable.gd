class_name BreachableDoor
extends StaticBody3D

signal door_breached()

@export var hits_required: int = 3

var hit_count: int = 0
var is_breached: bool = false

func take_halligan_hit() -> bool:
	if is_breached:
		return false
	hit_count += 1
	if hit_count >= hits_required:
		_breach()
		return true
	return false

func _breach() -> void:
	is_breached = true
	collision_layer = 0
	collision_mask = 0
	var mesh = get_node_or_null("DoorMesh")
	if mesh:
		mesh.visible = false
	door_breached.emit()

func get_hits_remaining() -> int:
	return hits_required - hit_count
