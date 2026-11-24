class_name FireExtinguisher
extends Node3D

@export var extinguisher_type: String = "abc_dry"
@export var extinguisher_label: String = "ABC Dry Chemical"
@export var pin_pulled: bool = false
@export var agent_reserve: float = 100.0

@onready var spray_particles: CPUParticles3D = $SprayParticles
@onready var spray_raycast: RayCast3D = $SprayRayCast

var _is_spraying: bool = false
var _sweep_acc: float = 0.0
var _is_sweeping: bool = false

func pull_pin() -> bool:
	if pin_pulled:
		return false
	pin_pulled = true
	return true

func start_spray() -> bool:
	if not pin_pulled or agent_reserve <= 0.0:
		return false
	_is_spraying = true
	if spray_particles:
		spray_particles.emitting = true
	return true

func stop_spray() -> void:
	_is_spraying = false
	if spray_particles:
		spray_particles.emitting = false

func update_sweep(yaw_delta: float, delta: float) -> void:
	if abs(yaw_delta) > 0.55:
		_sweep_acc = min(_sweep_acc + delta * 3.0, 1.0)
	else:
		_sweep_acc = max(_sweep_acc - delta * 2.5, 0.0)
	_is_sweeping = _sweep_acc > 0.28

func process_spray(delta: float) -> Dictionary:
	var res = {
		"spraying": false, "base_hit": false, "sweeping": _is_sweeping,
		"reserve": agent_reserve, "correct_type": true
	}
	if not _is_spraying or agent_reserve <= 0.0:
		return res
	agent_reserve = max(agent_reserve - delta * 7.0, 0.0)
	res["spraying"] = true
	res["reserve"] = agent_reserve
	if agent_reserve <= 0.0:
		stop_spray()
		return res
	if spray_raycast and spray_raycast.is_colliding():
		var col = spray_raycast.get_collider()
		if col == null:
			return res
		var hazard: FireHazard = _find_hazard(col)
		var is_base = (col.name == "BaseArea" or (col.get_parent() != null and col.get_parent().name == "BaseArea"))
		if hazard and hazard.is_active and hazard.is_classified:
			var ok = hazard.apply_extinguisher(delta * 26.0, is_base, _is_sweeping, extinguisher_type)
			res["base_hit"] = is_base
			res["correct_type"] = ok
	return res

func _find_hazard(node: Node) -> FireHazard:
	if node == null: return null
	if node is FireHazard: return node
	var p = node.get_parent()
	if p is FireHazard: return p
	if p != null and p.get_parent() is FireHazard: return p.get_parent()
	return null

func is_correct_for(fire_class: String) -> bool:
	match fire_class:
		"A": return extinguisher_type in ["water", "abc_dry"]
		"B": return extinguisher_type in ["co2", "abc_dry"]
		"C": return extinguisher_type in ["co2", "abc_dry"]
	return false
