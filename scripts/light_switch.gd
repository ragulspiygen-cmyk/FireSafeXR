class_name LightSwitch
extends Interactable

@export var target_light: Light3D
@export var bulb_mesh: MeshInstance3D
@export var is_on: bool = true

@export var emissive_color_on: Color = Color(1.0, 0.9, 0.6)
@export var emissive_color_off: Color = Color(0.1, 0.1, 0.1)

func _ready() -> void:
	prompt = "Toggle Light"
	_apply_state()

func _on_interact(_player: Node) -> void:
	is_on = !is_on
	_apply_state()

func _apply_state() -> void:
	if target_light:
		target_light.visible = is_on
	
	if bulb_mesh and bulb_mesh.get_active_material(0):
		var mat = bulb_mesh.get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission_enabled = is_on
			mat.emission = emissive_color_on if is_on else emissive_color_off
