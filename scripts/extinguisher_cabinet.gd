class_name ExtinguisherCabinet
extends StaticBody3D

signal extinguisher_taken(ext_type: String, ext_label: String)

@export var extinguisher_type: String = "abc_dry"
@export var extinguisher_label: String = "ABC Dry Chemical"
@export var cabinet_id: String = "cabinet_a"

var is_locked: bool = false
var _is_taken: bool = false

func _ready() -> void:
	add_to_group("ext_cabinets")

func unlock() -> void:
	is_locked = false
	_update_indicator()

func take_extinguisher() -> bool:
	if _is_taken or is_locked:
		return false
	_is_taken = true
	var body_mesh = get_node_or_null("CabinetBody/DoorMesh")
	if body_mesh:
		body_mesh.visible = false
	extinguisher_taken.emit(extinguisher_type, extinguisher_label)
	return true

func _update_indicator() -> void:
	var light = get_node_or_null("LockLight")
	if light:
		light.light_color = Color(0.1, 1.0, 0.2) if not is_locked else Color(1.0, 0.1, 0.1)
