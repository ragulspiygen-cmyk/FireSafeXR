extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var training_manager: TrainingManager = $TrainingManager

func _ready() -> void:
	# Wire fires
	for node in get_tree().get_nodes_in_group("fire_hazards"):
		var fire := node as FireHazard
		if fire == null: continue
		fire.fire_extinguished.connect(_on_fire_extinguished.bind(fire))
		fire.wrong_extinguisher_used.connect(_on_wrong_ext.bind(fire))

	# Wire victims
	for node in get_tree().get_nodes_in_group("victims"):
		var v := node as Victim
		if v == null: continue
		v.victim_rescued.connect(_on_victim_rescued)

	# Wire evacuation zone
	var evac = get_node_or_null("House2BHK/EvacuationZone")
	if evac:
		evac.body_entered.connect(_on_evac_entered)

	# Wire house entry trigger
	var entry = get_node_or_null("House2BHK/EntryTrigger")
	if entry:
		entry.body_entered.connect(_on_house_entered)

	# Add toolkit box to group so player controller can detect it
	var kit := get_node_or_null("House2BHK/Exterior/FireTruck/ToolkitBox")
	if kit:
		kit.add_to_group("toolkit_box")

	# Add fire truck body to group for refill-near-truck detection
	var truck_body := get_node_or_null("House2BHK/Exterior/FireTruck/TruckBody")
	if truck_body:
		truck_body.add_to_group("fire_truck")

	# Add smoke zone node to group so player can detect it
	var smoke_zone = get_node_or_null("House2BHK/Hallway/SmokeZoneTrigger")
	if smoke_zone:
		smoke_zone.add_to_group("smoke_zone")

	# Wire player to training_manager
	if player and training_manager:
		player.set_training_manager(training_manager)

func _on_fire_extinguished(fire: FireHazard) -> void:
	if fire.hazard_class == "A":
		training_manager.record_lr_extinguished(player.last_tool_used)
	elif fire.hazard_class == "B":
		training_manager.record_kt_extinguished(player.last_tool_used)

func _on_wrong_ext(correct_types: Array, fire: FireHazard) -> void:
	if fire.hazard_class == "B":
		training_manager.record_water_on_grease()

func _on_victim_rescued() -> void:
	training_manager.record_victim_rescued()

func _on_house_entered(body: Node3D) -> void:
	if body == player:
		training_manager.record_house_entry()
		player.notify_house_entry()

func _on_evac_entered(body: Node3D) -> void:
	if body == player and training_manager.victim_rescued:
		training_manager.complete_training()
		player.show_assessment(training_manager._build_report())
