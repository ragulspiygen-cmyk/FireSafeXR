class_name Victim
extends Node3D

signal victim_rescued()

@export var victim_name: String = "Civilian"
var is_rescued: bool = false

func _ready() -> void:
	add_to_group("victims")

func rescue() -> void:
	if is_rescued:
		return
	is_rescued = true
	var body = get_node_or_null("Body")
	if body: body.visible = false
	var head = get_node_or_null("Head")
	if head: head.visible = false
	victim_rescued.emit()
