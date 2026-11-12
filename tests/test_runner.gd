extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	print("=== Tiny Robot Rescue Headless Test Suite ===")
	_test_levels()
	_test_stroke_builder()
	_test_draw_controller()
	_test_robot_controller()
	_test_objective_evaluator()
	_test_save_recovery()
	_test_monetization_idempotency()
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + msg)

func _test_levels() -> void:
	for i in range(1, 61):
		var lvl := LevelLoader.load_level(i)
		_assert(not lvl.is_empty(), "Level %d should load and validate" % i)
		_assert(int(lvl.get("id", 0)) == i, "Level %d id matches" % i)

func _test_stroke_builder() -> void:
	var empty_body := StrokePhysicsBuilder.build_stroke_body(PackedVector2Array())
	_assert(empty_body == null, "Empty polyline returns null")
	
	var single_body := StrokePhysicsBuilder.build_stroke_body(PackedVector2Array([Vector2(10, 10)]))
	_assert(single_body == null, "Single point returns null")
	
	var valid_pts := PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(100, 20)])
	var body := StrokePhysicsBuilder.build_stroke_body(valid_pts)
	_assert(body != null, "Valid polyline builds StaticBody2D")
	if body != null:
		body.free()

func _test_draw_controller() -> void:
	var DrawScript := load("res://scripts/draw_controller.gd")
	_assert(DrawScript != null and DrawScript.can_instantiate(), "DrawController compiles and instantiates")
	if DrawScript == null or not DrawScript.can_instantiate():
		return
	var dc = DrawScript.new()
	dc.draw_zones.assign([Rect2(40, 200, 640, 900)])
	dc.forbidden_rects.assign([Rect2(160, 540, 400, 40)])
	dc.robot_positions.assign([Vector2(360, 900)])
	_assert(not dc.is_point_valid(Vector2(360, 100)), "Point in HUD is outside draw zone")
	_assert(not dc.is_point_valid(Vector2(200, 560)), "Point in forbidden zone is rejected")
	_assert(not dc.is_point_valid(Vector2(360, 900)), "Point inside robot is rejected")
	_assert(dc.is_point_valid(Vector2(200, 700)), "Point in valid area is accepted")
	_assert(not dc.is_segment_valid(Vector2(280, 900), Vector2(440, 900)), "Segment cutting across robot is rejected")
	_assert(not dc.is_segment_valid(Vector2(200, 500), Vector2(200, 620)), "Segment cutting across forbidden zone is rejected")
	_assert(dc.is_segment_valid(Vector2(200, 700), Vector2(500, 700)), "Valid bridge/roof segment is accepted")
	dc.free()

func _test_robot_controller() -> void:
	var robot_scene: PackedScene = load("res://scenes/entities/robot.tscn")
	_assert(robot_scene != null, "Robot scene loads cleanly")
	if robot_scene != null:
		var r := robot_scene.instantiate()
		_assert(r is RobotController, "Robot instantiates as RobotController")
		r.set_expression(RobotController.RobotExpression.HAPPY)
		_assert(r.current_expression == RobotController.RobotExpression.HAPPY, "RobotExpression enum works")
		var hz := HazardController.new()
		hz.hazard_type = "block"
		hz.add_to_group("hazard")
		_assert(hz.get_display_name() == "Heavy Block", "Hazard display name is readable")
		var died_info := {"reason": ""}
		r.robot_died.connect(func(msg: String): died_info["reason"] = msg)
		r._on_body_entered(hz)
		_assert(died_info["reason"] == "Hit by Heavy Block!", "Robot death uses hazard display name")
		hz.free()
		r.free()

func _test_objective_evaluator() -> void:
	var ev := ObjectiveEvaluator.new()
	ev.configure({"type": "survival"}, 5.0, 1, 0)
	_assert(ev.step(2.0) == ObjectiveEvaluator.State.SIMULATING, "Survival still running at 2s")
	_assert(ev.step(3.1) == ObjectiveEvaluator.State.WON, "Survival wins at 5.1s")
	
	ev.configure({"type": "exit"}, 5.0, 1, 0)
	ev.robots_at_goal = 1
	_assert(ev.step(0.1) == ObjectiveEvaluator.State.WON, "Exit wins when robot reaches goal")
	
	ev.configure({"type": "switch", "required_switches": 1}, 5.0, 1, 1)
	ev.activated_switches = 1
	ev.robots_at_goal = 1
	_assert(ev.step(0.1) == ObjectiveEvaluator.State.WON, "Switch wins when switch activated")

func _test_save_recovery() -> void:
	var test_path := "user://test_save_qa.json"
	var ProgressSaveScript := load("res://scripts/progress_save.gd")
	var ps = ProgressSaveScript.new()
	ps.data = ps.default_data()
	ps.data["unlocked_level"] = 5
	ps.data["last_selected_level"] = 4
	_assert(ps.save_now(test_path), "Atomic save succeeds")
	
	# Reload valid JSON from disk (JSON.parse yields TYPE_FLOAT for ints)
	var ps_reload = ProgressSaveScript.new()
	ps_reload.load_save(test_path)
	_assert(int(ps_reload.data["unlocked_level"]) == 5, "Unlocked level persists across JSON reload")
	_assert(int(ps_reload.data["last_selected_level"]) == 4, "Last selected level persists across JSON reload")
	_assert(typeof(ps_reload.data["unlocked_level"]) == TYPE_INT, "Unlocked level normalizes back to int")
	ps_reload.free()
	
	# Corrupt primary file -> falls back cleanly
	var f := FileAccess.open(test_path, FileAccess.WRITE)
	f.store_string("{corrupt_json")
	f.close()
	
	ps.load_save(test_path)
	_assert(ps.data["schema_version"] == ps.SCHEMA_VERSION, "Save recovers from corruption")
	ps.free()

func _test_monetization_idempotency() -> void:
	var ProgressSaveScript := load("res://scripts/progress_save.gd")
	var ps = ProgressSaveScript.new()
	ps.data = ps.default_data()
	var BillingScript := load("res://scripts/billing_adapter.gd")
	_assert(BillingScript != null and BillingScript.can_instantiate(), "BillingAdapter compiles and instantiates")
	if BillingScript != null and BillingScript.can_instantiate():
		var ba = BillingScript.new()
		ba.progress_save_override = ps
		_assert(not ba.verify_and_grant_purchase("remove_interstitial_ads", ""), "Empty token rejected")
		_assert(ba.verify_and_grant_purchase("remove_interstitial_ads", "tok_123"), "Valid token granted once")
		_assert(ps.has_remove_ads(), "Entitlement persisted on ProgressSave")
		_assert(not ba.verify_and_grant_purchase("remove_interstitial_ads", "tok_123"), "Duplicate token rejected")
		ba.free()
	ps.free()
