class_name PlayerController
extends CharacterBody3D

# ── Constants ──────────────────────────────────────────────────────────────
const SPEED         := 4.8
const SPRINT_SPEED  := 7.2
const SMOKE_SPEED   := 2.4
const JUMP_VELOCITY := 4.0
const ACCEL         := 18.0
const FRICTION      := 14.0
const MOUSE_SENS    := 0.0018
const GRAVITY       := 9.8
const SPRAY_DRAIN   := 8.0    # reserve/sec for extinguisher (was 12 — too fast)
const HOSE_DRAIN    := 3.0    # hose drains even slower
const EXT_CAPACITY  := 280.0  # ~35s of spray
const REFILL_RATE   := 18.0   # reserve/sec when near truck

# ── Node references ────────────────────────────────────────────────────────
@onready var camera: Camera3D             = $Camera3D
@onready var interact_ray: RayCast3D      = $Camera3D/InteractRay
@onready var spray_ray: RayCast3D         = $Camera3D/SprayRay
@onready var action_prompt: Label         = $HUD/ActionPrompt
@onready var stage_label: Label           = $HUD/StageLabel
@onready var timer_label: Label           = $HUD/TimerLabel
@onready var thermal_overlay: ColorRect   = $HUD/ThermalOverlay
@onready var smoke_vignette: ColorRect    = $HUD/SmokeVignette
@onready var tool_bar: HBoxContainer      = $HUD/ToolBar
@onready var assessment_panel: PanelContainer = $HUD/AssessmentPanel
@onready var crosshair: Label             = $HUD/Crosshair
@onready var no_toolkit_hint: Label       = $HUD/NoToolkitHint

# Viewmodel nodes
@onready var vm_thermal:      Node3D = $Camera3D/HandPivot/VMThermal
@onready var vm_extinguisher: Node3D = $Camera3D/HandPivot/VMExtinguisher
@onready var vm_hose:         Node3D = $Camera3D/HandPivot/VMHose
@onready var vm_halligan:     Node3D = $Camera3D/HandPivot/VMHalligan

# ── State ──────────────────────────────────────────────────────────────────
var tools: FirefighterTools   = null
var training_manager: TrainingManager = null
var _is_spraying: bool        = false
var _pin_pulled: bool         = false
var _sweep_acc: float         = 0.0
var _elapsed: float           = 0.0
var _in_smoke: bool           = false
var _thermal_scanning: bool   = false
var _victims_in_scene: Array  = []
var last_tool_used: String    = ""
var _halligan_hits: int       = 0
var _current_door: BreachableDoor = null
var _near_truck: bool         = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	tools = FirefighterTools.new()
	tools.extinguisher_reserve = EXT_CAPACITY
	tools.tool_changed.connect(_on_tool_changed)
	tools.toolkit_acquired.connect(_on_toolkit_acquired)
	add_child(tools)
	_update_viewmodels()
	if assessment_panel: assessment_panel.visible = false
	if thermal_overlay:  thermal_overlay.visible = false
	if smoke_vignette:   smoke_vignette.visible = false
	if no_toolkit_hint:  no_toolkit_hint.visible = true
	_set_action_prompt("Walk to the FIRE TRUCK and press [E] to pick up your toolkit")

func set_training_manager(tm: TrainingManager) -> void:
	training_manager = tm

func _input(event: InputEvent) -> void:
	if assessment_panel and assessment_panel.visible:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: tools.switch_to(FirefighterTools.Tool.THERMAL_CAM)
			KEY_2: tools.switch_to(FirefighterTools.Tool.EXTINGUISHER)
			KEY_3: tools.switch_to(FirefighterTools.Tool.WATER_HOSE)
			KEY_4: tools.switch_to(FirefighterTools.Tool.HALLIGAN)
			KEY_E: _try_interact()
			KEY_Q:
				if tools.current_tool == FirefighterTools.Tool.EXTINGUISHER:
					_pin_pulled = true
					_set_action_prompt("✅ Pin pulled — Aim at fire base — Hold LEFT-CLICK to spray")
			KEY_ESCAPE:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _on_use_start()
		else: _on_use_stop()

func _physics_process(delta: float) -> void:
	if assessment_panel and assessment_panel.visible:
		return
	_elapsed += delta
	_update_timer()
	_update_stage_label()
	_update_context(delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump (Space)
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement (WASD)
	var input_dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_speed: float = SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED
	if _in_smoke: target_speed = minf(target_speed, SMOKE_SPEED)

	var target_vel: Vector3 = move_dir * target_speed
	velocity.x = move_toward(velocity.x, target_vel.x, ACCEL * delta) if move_dir.length() > 0.1 else move_toward(velocity.x, 0, FRICTION * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, ACCEL * delta) if move_dir.length() > 0.1 else move_toward(velocity.z, 0, FRICTION * delta)
	move_and_slide()

	if _is_spraying:
		_do_spray(delta)
	if _thermal_scanning and tools.current_tool == FirefighterTools.Tool.THERMAL_CAM:
		_do_thermal_scan()

	# Refill extinguisher when near truck
	if _near_truck and tools.has_toolkit:
		if tools.extinguisher_reserve < EXT_CAPACITY:
			tools.extinguisher_reserve = minf(tools.extinguisher_reserve + REFILL_RATE * delta, EXT_CAPACITY)

func _on_use_start() -> void:
	if not tools.has_toolkit:
		_set_action_prompt("⚠ Go to the FIRE TRUCK and press E to pick up your toolkit first!")
		return
	match tools.current_tool:
		FirefighterTools.Tool.EXTINGUISHER, FirefighterTools.Tool.WATER_HOSE:
			_is_spraying = true
		FirefighterTools.Tool.THERMAL_CAM:
			_thermal_scanning = true
			if thermal_overlay: thermal_overlay.visible = true
		FirefighterTools.Tool.HALLIGAN:
			_swing_halligan()

func _on_use_stop() -> void:
	_is_spraying = false
	_thermal_scanning = false
	if thermal_overlay: thermal_overlay.visible = false

func _do_spray(delta: float) -> void:
	var ext_type := ""
	var reserve := 0.0
	match tools.current_tool:
		FirefighterTools.Tool.EXTINGUISHER:
			if not _pin_pulled:
				_set_action_prompt("⚠ Press Q to pull the pin first!")
				_is_spraying = false
				return
			ext_type = "abc_dry"
			tools.extinguisher_reserve -= SPRAY_DRAIN * delta
			reserve = tools.extinguisher_reserve
		FirefighterTools.Tool.WATER_HOSE:
			ext_type = "water"
			tools.hose_reserve -= HOSE_DRAIN * delta
			reserve = tools.hose_reserve

	if reserve <= 0.0:
		_is_spraying = false
		if tools.current_tool == FirefighterTools.Tool.EXTINGUISHER:
			_set_action_prompt("⚠ Extinguisher empty — Return near the truck to refill!")
		return

	if spray_ray and spray_ray.is_colliding():
		var area := spray_ray.get_collider()
		if area is Area3D:
			var fire_node := area.get_parent() as FireHazard
			if fire_node and fire_node.is_active:
				var base_hit: bool = area.name == "BaseArea"
				_sweep_acc += absf(Input.get_last_mouse_velocity().x) * 0.002 * delta
				var sweeping: bool = _sweep_acc > 0.3
				last_tool_used = ext_type
				fire_node.apply_extinguisher(30.0 * delta, base_hit, sweeping, ext_type)

func _do_thermal_scan() -> void:
	if _victims_in_scene.is_empty():
		_victims_in_scene = get_tree().get_nodes_in_group("victims")

	var found_victim: bool = false
	for v in _victims_in_scene:
		if v == null or not is_instance_valid(v): continue
		var victim := v as Victim
		if victim == null or victim.is_rescued: continue
		var dist: float = global_position.distance_to(victim.global_position)
		if dist < 12.0:
			var dir: Vector3 = (victim.global_position - global_position).normalized()
			var fwd: Vector3 = -global_transform.basis.z
			if dir.dot(fwd) > 0.2:
				found_victim = true
				_set_action_prompt("🌡 THERMAL SIGNATURE DETECTED!\nVictim in locked room — use [4] Halligan Bar to breach the door")
				if training_manager and not training_manager.thermal_used_to_find_victim:
					training_manager.record_thermal_victim_found()

	if not found_victim:
		_set_action_prompt("Scanning… move closer and point toward the bedroom doors")

func _swing_halligan() -> void:
	if not tools.try_swing_halligan():
		return
	if vm_halligan:
		var tween := get_tree().create_tween()
		tween.tween_property(vm_halligan, "rotation:x", -0.9, 0.16)
		tween.tween_property(vm_halligan, "rotation:x", 0.0, 0.20)

	if interact_ray and interact_ray.is_colliding():
		var col := interact_ray.get_collider()
		var door := col as BreachableDoor
		if door == null:
			door = col.get_parent() as BreachableDoor
		if door and not door.is_breached:
			if door != _current_door:
				_current_door = door
				_halligan_hits = 0
			_halligan_hits += 1
			_set_action_prompt("Hit %d/%d — Keep swinging! (LEFT-CLICK)" % [_halligan_hits, door.hits_required])
			door.take_halligan_hit()
			if door.is_breached:
				_set_action_prompt("✅ DOOR BREACHED — Enter the room to rescue the victim!")
				if training_manager:
					training_manager.record_door_breached()
	else:
		_set_action_prompt("Aim at the LOCKED DOOR and swing — [LEFT-CLICK]")

func _try_interact() -> void:
	# ── Toolkit: proximity-based ─────────────────────────────────────────────
	if not tools.has_toolkit:
		for node in get_tree().get_nodes_in_group("toolkit_box"):
			if node is Node3D:
				if global_position.distance_to((node as Node3D).global_position) < 4.5:
					tools.pick_up_toolkit()
					tools.extinguisher_reserve = EXT_CAPACITY
					if training_manager:
						training_manager.record_toolkit_pickup()
					node.queue_free()
					return
		_set_action_prompt("⚠ Walk closer to the yellow box beside the fire truck")
		return

	# ── Victim rescue: proximity-based ───────────────────────────────────────
	for node in get_tree().get_nodes_in_group("victims"):
		var v := node as Victim
		if v and not v.is_rescued:
			if global_position.distance_to(v.global_position) < 2.5:
				v.rescue()
				_set_action_prompt("✅ VICTIM RESCUED! Walk back outside to the green ASSEMBLY ZONE!")
				return

func _update_context(delta: float) -> void:
	if not tools.has_toolkit:
		_near_truck = _check_near_group("toolkit_box")
		if _near_truck:
			_set_action_prompt("🟡 TOOLKIT NEARBY — Press [E] to pick it up")
		else:
			_set_action_prompt("Walk to the yellow box beside the FIRE TRUCK → Press [E]")
		return

	# Smoke detection
	_in_smoke = _check_near_group("smoke_zone")
	if smoke_vignette: smoke_vignette.visible = _in_smoke

	# Near truck detection (for refill)
	_near_truck = _check_near_group("toolkit_box") or _check_near_group("fire_truck")

	# Dynamic prompts when not actively using a tool
	if not _is_spraying and not _thermal_scanning:
		# Show reserve bar hint when extinguisher is low
		if tools.current_tool == FirefighterTools.Tool.EXTINGUISHER:
			var pct := int(tools.extinguisher_reserve / EXT_CAPACITY * 100.0)
			var hint := tools.get_tool_hint()
			if pct < 25:
				hint = "⚠ Extinguisher low (%d%%) — return near truck to refill" % pct
			elif not _pin_pulled:
				hint = "Press [Q] to pull pin, then hold LEFT-CLICK to spray"
			_set_action_prompt(hint)
			return

		# Raycast-based context hints
		if interact_ray and interact_ray.is_colliding():
			var col := interact_ray.get_collider()
			if col != null:
				var v := col as Victim
				if v == null: v = col.get_parent() as Victim
				if v and not v.is_rescued:
					_set_action_prompt("VICTIM FOUND — Press [E] to rescue!")
					return
				var door := col as BreachableDoor
				if door == null: door = col.get_parent() as BreachableDoor
				if door and not door.is_breached:
					_set_action_prompt("LOCKED DOOR — Switch to [4] Halligan Bar and swing to breach!")
					return

		_set_action_prompt(tools.get_tool_hint())

func _check_near_group(group_name: String) -> bool:
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node3D:
			if global_position.distance_to((node as Node3D).global_position) < 5.0:
				return true
	return false

func notify_house_entry() -> void:
	if training_manager:
		training_manager.record_house_entry()

func _on_tool_changed(new_tool: int) -> void:
	_update_viewmodels()
	# Reset pin for extinguisher only; other tools don't need it
	if new_tool == FirefighterTools.Tool.EXTINGUISHER:
		_pin_pulled = false
	_is_spraying = false
	_thermal_scanning = false
	if thermal_overlay: thermal_overlay.visible = false
	_set_action_prompt(tools.get_tool_hint())
	_update_tool_bar_highlight(new_tool)

func _on_toolkit_acquired() -> void:
	if no_toolkit_hint: no_toolkit_hint.visible = false
	_set_action_prompt("✅ TOOLKIT EQUIPPED! Enter the house. Keys 1-4 switch tools.")

func _update_viewmodels() -> void:
	if vm_thermal:      vm_thermal.visible      = tools.current_tool == FirefighterTools.Tool.THERMAL_CAM
	if vm_extinguisher: vm_extinguisher.visible = tools.current_tool == FirefighterTools.Tool.EXTINGUISHER
	if vm_hose:         vm_hose.visible         = tools.current_tool == FirefighterTools.Tool.WATER_HOSE
	if vm_halligan:     vm_halligan.visible      = tools.current_tool == FirefighterTools.Tool.HALLIGAN

func _update_tool_bar_highlight(tool: int) -> void:
	if tool_bar == null: return
	for i in tool_bar.get_child_count():
		var child := tool_bar.get_child(i)
		if child is PanelContainer:
			child.modulate = Color(1.5, 1.5, 0.5) if i == tool else Color(1, 1, 1)

func _set_action_prompt(text: String) -> void:
	if action_prompt: action_prompt.text = text

func _update_timer() -> void:
	if timer_label:
		var m := int(_elapsed) / 60
		var s := int(_elapsed) % 60
		timer_label.text = "%02d:%02d" % [m, s]

func _update_stage_label() -> void:
	if stage_label and training_manager:
		stage_label.text = training_manager.current_stage_label

func show_assessment(report: Dictionary) -> void:
	if assessment_panel == null: return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	assessment_panel.visible = true
	var set_lbl := func(nm: String, text: String) -> void:
		var n := assessment_panel.find_child(nm, true, false)
		if n is Label: n.text = text
	set_lbl.call("LOverall", "Overall Score: %d%%" % report["overall"])
	set_lbl.call("LStatus",  report["status"])
	set_lbl.call("LEntry",   "Scene Assessment: %d%%" % report["s_entry"])
	set_lbl.call("LLR",      "Living Room Fire (Class A): %d%%" % report["s_lr"])
	set_lbl.call("LKT",      "Kitchen Fire (Class B): %d%%  (%d water misuse)" % [report["s_kt"], report["water_on_grease"]])
	set_lbl.call("LThermal", "Thermal Camera: %d%%  (used: %s)" % [report["s_thermal"], "Yes" if report["thermal_used"] else "No"])
	set_lbl.call("LRescue",  "Victim Rescue: %d%%" % report["s_rescue"])
	set_lbl.call("LTime",    "Response Time: %s" % report["time_str"])
