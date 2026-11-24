class_name FireHazard
extends Node3D

signal fire_extinguished(hazard: FireHazard)
signal player_entered_range(hazard: FireHazard)
signal player_exited_range()
signal wrong_extinguisher_used(correct_types: Array)

@export var hazard_name: String = "Unknown Fire"
@export var hazard_class: String = "A"
@export var required_extinguisher_types: Array = ["abc_dry"]
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var is_active: bool = true
@export var is_classified: bool = true  # No quiz needed — tool choice IS the classification
@export var grows_over_time: bool = true
@export var grow_rate: float = 2.5

@onready var flame_1: MeshInstance3D = $Flames/Flame1
@onready var flame_2: MeshInstance3D = $Flames/Flame2
@onready var fire_light: OmniLight3D = $FireLight
@onready var smoke_particles: CPUParticles3D = $SmokeParticles
@onready var detection_area: Area3D = $DetectionArea

var _flicker: float = 0.0
var _flare_timer: float = 0.0
var _is_flaring: bool = false
var _being_suppressed: bool = false

func _ready() -> void:
	add_to_group("fire_hazards")
	current_health = max_health
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if not is_active:
		return
	_flicker += delta * 13.0

	if _is_flaring:
		_flare_timer -= delta
		if _flare_timer <= 0.0:
			_is_flaring = false

	# Fire grows if not being suppressed
	if grows_over_time and not _being_suppressed:
		current_health = minf(current_health + grow_rate * delta, max_health)
	_being_suppressed = false  # reset each frame

	var ratio = current_health / max_health
	var flare = 1.6 if _is_flaring else 1.0
	if fire_light:
		var base_e = 4.8 if _is_flaring else 3.2
		fire_light.light_energy = (base_e + sin(_flicker) * 0.9) * ratio
		fire_light.light_color = Color(1, 0.15, 0.05) if _is_flaring else Color(1, 0.55, 0.12)
	if flame_1 and flame_2:
		var pulse = 1.0 + sin(_flicker * 0.75) * 0.1
		var s = ratio * flare
		flame_1.scale = Vector3(s * pulse, s * pulse, s * pulse)
		flame_2.scale = Vector3(s * (2.0 - pulse), s * (2.0 - pulse), s * (2.0 - pulse))

func apply_extinguisher(amount: float, base_hit: bool, sweeping: bool, ext_type: String) -> bool:
	if not is_active:
		return false
	_being_suppressed = true
	if ext_type not in required_extinguisher_types:
		_trigger_flare()
		wrong_extinguisher_used.emit(required_extinguisher_types)
		return false
	var mult = 2.5 if base_hit else 0.35
	if sweeping: mult *= 1.8
	current_health = maxf(current_health - amount * mult, 0.0)
	if current_health <= 0.0:
		_extinguish()
	return true

func _trigger_flare() -> void:
	current_health = minf(current_health + 20.0, max_health)
	_is_flaring = true
	_flare_timer = 2.2

func _extinguish() -> void:
	is_active = false
	if flame_1: flame_1.visible = false
	if flame_2: flame_2.visible = false
	if fire_light: fire_light.visible = false
	if smoke_particles: smoke_particles.emitting = false
	fire_extinguished.emit(self)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_entered_range.emit(self)

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_exited_range.emit()
