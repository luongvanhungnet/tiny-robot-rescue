extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	print("=== Tiny Robot Rescue Headless Test Suite ===")
	_test_levels()
	_test_stroke_builder()
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
	for i in range(1, 11):
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
	var ps := ProgressSave
	ps.data = ps.default_data()
	ps.data["unlocked_level"] = 5
	_assert(ps.save_now(test_path), "Atomic save succeeds")
	
	# Corrupt primary file
	var f := FileAccess.open(test_path, FileAccess.WRITE)
	f.store_string("{corrupt_json")
	f.close()
	
	ps.load_save(test_path)
	_assert(ps.data["schema_version"] == ps.SCHEMA_VERSION, "Save recovers from corruption")

func _test_monetization_idempotency() -> void:
	var ba := BillingAdapter
	_assert(not ba.verify_and_grant_purchase("remove_interstitial_ads", ""), "Empty token rejected")
	_assert(ba.verify_and_grant_purchase("remove_interstitial_ads", "tok_123"), "Valid token granted once")
	_assert(not ba.verify_and_grant_purchase("remove_interstitial_ads", "tok_123"), "Duplicate token rejected")
