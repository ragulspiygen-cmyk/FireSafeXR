class_name Interactable
extends Node3D

## Title displayed when looking at or inspecting this item
@export var title: String = "Unknown Object"

## Short prompt displayed in the HUD crosshair (e.g. "Inspect Revolver", "Open Door")
@export var prompt: String = "Inspect"

## Detailed evidence note or description shown in the pop-up inspect window
@export_multiline var description: String = "No details available."

## Optional secondary details (e.g., "Caliber: .38 Special | Found near chalk outline")
@export var extra_info: String = ""

## Sound or visual indicator state
@export var is_active: bool = true

## Signal emitted when player interacts with this object
signal interacted(player_node)

func interact(player: Node) -> void:
	if not is_active:
		return
	emit_signal("interacted", player)
	_on_interact(player)

func _on_interact(_player: Node) -> void:
	pass
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
