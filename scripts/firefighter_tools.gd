class_name FirefighterTools
extends Node

signal tool_changed(new_tool: int)
signal toolkit_acquired()

enum Tool {
	THERMAL_CAM  = 0,
	EXTINGUISHER = 1,
	WATER_HOSE   = 2,
	HALLIGAN     = 3
}

var current_tool: int = Tool.EXTINGUISHER
var has_toolkit: bool = false
var extinguisher_reserve: float = 100.0
var hose_reserve: float = 100.0  # replenishes slowly (truck supply)
var halligan_swing_timer: float = 0.0
var is_swinging: bool = false

func _process(delta: float) -> void:
	# Hose supply replenishes (connected to truck via hose)
	hose_reserve = minf(hose_reserve + delta * 5.0, 100.0)
	# Swing cooldown
	if is_swinging:
		halligan_swing_timer -= delta
		if halligan_swing_timer <= 0.0:
			is_swinging = false

func pick_up_toolkit() -> void:
	if has_toolkit:
		return
	has_toolkit = true
	current_tool = Tool.EXTINGUISHER
	toolkit_acquired.emit()
	tool_changed.emit(current_tool)

func switch_to(tool: int) -> void:
	if not has_toolkit or tool == current_tool:
		return
	current_tool = tool
	tool_changed.emit(current_tool)

func try_swing_halligan() -> bool:
	if is_swinging:
		return false
	is_swinging = true
	halligan_swing_timer = 0.45
	return true

func get_tool_name() -> String:
	match current_tool:
		Tool.THERMAL_CAM:  return "Thermal Camera"
		Tool.EXTINGUISHER: return "Fire Extinguisher (ABC)"
		Tool.WATER_HOSE:   return "Water Hose"
		Tool.HALLIGAN:     return "Halligan Bar"
	return "No Tool"

func get_tool_hint() -> String:
	match current_tool:
		Tool.THERMAL_CAM:  return "Hold LEFT-CLICK to scan — detects heat signatures through smoke"
		Tool.EXTINGUISHER: return "Press Q to pull pin — Aim at fire base — Hold LEFT-CLICK to spray"
		Tool.WATER_HOSE:   return "Hold LEFT-CLICK to spray — HIGH PRESSURE — wrong on grease/electrical!"
		Tool.HALLIGAN:     return "LEFT-CLICK to swing — breach locked doors in 3 hits"
	return ""
