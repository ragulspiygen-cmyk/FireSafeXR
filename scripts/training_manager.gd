class_name TrainingManager
extends Node

signal assessment_completed(report: Dictionary)

# ── Incident tracking ──────────────────────────────────────────────────────
var start_time: float = 0.0
var end_time: float = 0.0

# Stage completion
var toolkit_picked_up: bool = false
var entered_house: bool = false
var lr_fire_extinguished: bool = false
var kt_fire_extinguished: bool = false
var thermal_used_to_find_victim: bool = false
var bedroom_door_breached: bool = false
var victim_rescued: bool = false
var evacuation_complete: bool = false

# Errors / penalties
var water_on_grease_count: int = 0   # water on kitchen (Class B) = danger
var hose_on_lr_count: int = 0        # hose on LR ok but scores lower
var skipped_thermal_scan: bool = false

# Stage labels shown in HUD
var current_stage_label: String = "STAGE 1 — EXTERIOR ASSESSMENT"

func _ready() -> void:
	start_time = Time.get_ticks_msec() / 1000.0

# ── Recording methods (called from player_controller and main_game) ────────
func record_toolkit_pickup() -> void:
	toolkit_picked_up = true

func record_house_entry() -> void:
	if not entered_house:
		entered_house = true
		current_stage_label = "STAGE 2 — INTERIOR SEARCH"

func record_lr_extinguished(tool_used: String) -> void:
	lr_fire_extinguished = true
	if tool_used == "water":
		hose_on_lr_count += 1  # technically works but poor choice
	current_stage_label = "STAGE 3 — LOCATE KITCHEN FIRE"

func record_kt_extinguished(tool_used: String) -> void:
	kt_fire_extinguished = true
	current_stage_label = "STAGE 4 — SEARCH FOR VICTIMS"

func record_water_on_grease() -> void:
	water_on_grease_count += 1

func record_thermal_victim_found() -> void:
	if not thermal_used_to_find_victim:
		thermal_used_to_find_victim = true
		current_stage_label = "STAGE 5 — BREACH BEDROOM 2"

func record_door_breached() -> void:
	bedroom_door_breached = true
	current_stage_label = "STAGE 6 — RESCUE VICTIM"

func record_victim_rescued() -> void:
	if not victim_rescued:
		victim_rescued = true
		current_stage_label = "STAGE 7 — EVACUATE TO ASSEMBLY POINT"

func complete_training() -> void:
	if evacuation_complete:
		return
	evacuation_complete = true
	end_time = Time.get_ticks_msec() / 1000.0
	current_stage_label = "INCIDENT CLEARED"
	var report = _build_report()
	assessment_completed.emit(report)

# ── Scoring & report ───────────────────────────────────────────────────────
func _build_report() -> Dictionary:
	var elapsed = end_time - start_time
	var minutes = int(elapsed) / 60
	var seconds = int(elapsed) % 60

	# Score components (out of 100 each, then weighted)
	var s_entry    = 100 if toolkit_picked_up and entered_house else 50
	var s_lr       = 100 if lr_fire_extinguished else 0
	if hose_on_lr_count > 0: s_lr = max(s_lr - 10, 0)
	var s_kt       = 100 if kt_fire_extinguished else 0
	s_kt -= water_on_grease_count * 25  # heavy penalty per wrong use
	s_kt = max(s_kt, 0)
	var s_thermal  = 100 if thermal_used_to_find_victim else 35
	var s_rescue   = 0
	if bedroom_door_breached: s_rescue += 40
	if victim_rescued:        s_rescue += 60
	var s_time     = 100
	if elapsed > 180: s_time = 70
	if elapsed > 300: s_time = 40

	var overall = int(
		s_entry    * 0.10 +
		s_lr       * 0.20 +
		s_kt       * 0.25 +
		s_thermal  * 0.15 +
		s_rescue   * 0.20 +
		s_time     * 0.10
	)

	var status = "INCIDENT CLEARED ✅" if overall >= 70 else "FURTHER TRAINING REQUIRED ⚠️"
	if water_on_grease_count >= 2:
		status = "SAFETY VIOLATION — RETRAIN REQUIRED ❌"

	return {
		"overall":         overall,
		"status":          status,
		"s_entry":         s_entry,
		"s_lr":            s_lr,
		"s_kt":            s_kt,
		"s_thermal":       s_thermal,
		"s_rescue":        s_rescue,
		"s_time":          s_time,
		"water_on_grease": water_on_grease_count,
		"hose_on_lr":      hose_on_lr_count,
		"thermal_used":    thermal_used_to_find_victim,
		"victim_rescued":  victim_rescued,
		"time_str":        "%02d:%02d" % [minutes, seconds]
	}
