class_name ObjectiveEvaluator
extends RefCounted

enum State { READY, DRAWING, SIMULATING, WON, LOST }

var objective_type: String = "survival" # "survival", "exit", "switch"
var simulation_duration: float = 8.0
var elapsed_time: float = 0.0
var total_robots: int = 1
var alive_robots: int = 1
var robots_at_goal: int = 0
var required_switches: int = 0
var activated_switches: int = 0
var has_charger: bool = false
var loss_reason: String = ""

func configure(obj_dict: Dictionary, duration: float, robot_count: int, switch_count: int, charger_present: bool = false) -> void:
	objective_type = str(obj_dict.get("type", "survival"))
	simulation_duration = duration
	elapsed_time = 0.0
	total_robots = robot_count
	alive_robots = robot_count
	robots_at_goal = 0
	required_switches = int(obj_dict.get("required_switches", switch_count))
	activated_switches = 0
	has_charger = charger_present
	loss_reason = ""

func step(delta: float) -> State:
	if alive_robots < total_robots:
		if loss_reason == "":
			loss_reason = "A tiny robot was damaged!"
		return State.LOST
	
	elapsed_time += delta
	
	match objective_type:
		"survival":
			if elapsed_time >= simulation_duration:
				return State.WON
		"exit":
			if robots_at_goal >= total_robots:
				return State.WON
			if elapsed_time >= simulation_duration:
				loss_reason = "Time ran out before reaching the charger!"
				return State.LOST
		"switch":
			var switches_ok := activated_switches >= required_switches
			if has_charger:
				if switches_ok and robots_at_goal >= total_robots:
					return State.WON
				if elapsed_time >= simulation_duration:
					loss_reason = "Open the gate and reach the charger in time!" if not switches_ok else "Reach the charger in time!"
					return State.LOST
			else:
				if switches_ok and elapsed_time >= simulation_duration:
					return State.WON
				if elapsed_time >= simulation_duration and not switches_ok:
					loss_reason = "Switch was not activated in time!"
					return State.LOST
	
	return State.SIMULATING
