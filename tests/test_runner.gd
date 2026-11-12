extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	print("=== Tiny Robot Rescue Headless Test Suite ===")
	_test_levels()
	_test_scenes_compile()
	_test_stroke_builder()
	_test_draw_controller()
	_test_robot_controller()
	_test_hazard_and_world_elements()
	_test_objective_evaluator()
	_test_save_recovery_and_economy()
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
		var lvl: Dictionary = LevelLoader.load_level(i)
		_assert(not lvl.is_empty(), "Level %d loads and validates" % i)
		_assert(int(lvl.get("id", 0)) == i, "Level %d id matches" % i)
		var guide: Array = lvl.get("expected_solution_guide", [])
		_assert(guide.size() >= 2, "Level %d has solution guide" % i)
		var pts: PackedVector2Array = PackedVector2Array()
		for gp in guide:
			pts.append(Vector2(float(gp[0]), float(gp[1])))
		var glen: float = StrokePhysicsBuilder.compute_polyline_length(pts)
		_assert(glen <= float(lvl.get("max_stroke_length", 0.0)), "Level %d guide length <= max_stroke_length" % i)

func _test_scenes_compile() -> void:
	for path in ["res://scenes/home.tscn", "res://scenes/level_select.tscn", "res://scenes/gameplay.tscn"]:
		_assert(ResourceLoader.exists(path), "Scene exists: " + path)
	var robot_res: Resource = ResourceLoader.load("res://scenes/entities/robot.tscn")
	_assert(robot_res != null, "Entity scene loads cleanly: res://scenes/entities/robot.tscn")

func _test_stroke_builder() -> void:
	var empty_body: StaticBody2D = StrokePhysicsBuilder.build_stroke_body(PackedVector2Array())
	_assert(empty_body == null, "Empty polyline returns null")
	
	var single_body: StaticBody2D = StrokePhysicsBuilder.build_stroke_body(PackedVector2Array([Vector2(10, 10)]))
	_assert(single_body == null, "Single point returns null")
	
	var valid_pts: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(100, 20)])
	var body: StaticBody2D = StrokePhysicsBuilder.build_stroke_body(valid_pts)
	_assert(body != null, "Valid polyline builds StaticBody2D")
	if body != null:
		_assert(body.is_in_group("drawn_stroke"), "Built stroke has drawn_stroke group")
		body.free()

func _test_draw_controller() -> void:
	var DrawScript: GDScript = load("res://scripts/draw_controller.gd") as GDScript
	_assert(DrawScript != null and DrawScript.can_instantiate(), "DrawController compiles and instantiates")
	if DrawScript == null or not DrawScript.can_instantiate():
		return
	var dc: DrawController = DrawScript.new() as DrawController
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
	var robot_scene: PackedScene = load("res://scenes/entities/robot.tscn") as PackedScene
	_assert(robot_scene != null, "Robot scene loads cleanly")
	if robot_scene != null:
		var r: RobotController = robot_scene.instantiate() as RobotController
		_assert(r is RobotController, "Robot instantiates as RobotController")
		r.skin_id = "bot_tier_5"
		_assert(r._get_palette()["body"] == Color("#facc15"), "Golden skin palette applies")
		r.set_expression(RobotController.RobotExpression.HAPPY)
		_assert(r.current_expression == RobotController.RobotExpression.HAPPY, "RobotExpression enum works")
		var hz: HazardController = HazardController.new()
		hz.hazard_type = "block"
		hz.add_to_group("hazard")
		_assert(hz.get_display_name() == "Heavy Block", "Hazard display name is readable")
		var died_info: Dictionary = {"reason": "", "pos": Vector2.ZERO}
		r.robot_died.connect(func(msg: String, pos: Vector2):
			died_info["reason"] = msg
			died_info["pos"] = pos
		)
		r._on_body_entered(hz)
		_assert(died_info["reason"] == "Hit by Heavy Block!", "Robot death emits hazard display name")
		r.free()

		var r2: RobotController = robot_scene.instantiate() as RobotController
		r2.mark_rescued()
		r2._on_body_entered(hz)
		_assert(r2.is_alive and r2.current_expression == RobotController.RobotExpression.HAPPY, "Rescued robot ignores post-victory hazard collisions")
		hz.free()
		r2.free()

func _test_hazard_and_world_elements() -> void:
	# Conveyor gear deflection
	var cg: HazardController = HazardController.new()
	cg.hazard_type = "conveyor_gear"
	cg._ready()
	_assert(cg.gravity_scale == 0.0, "Conveyor gear starts with zero gravity on patrol")
	var stroke: StaticBody2D = StrokePhysicsBuilder.build_stroke_body(PackedVector2Array([Vector2(0, 0), Vector2(80, -40)]))
	cg._on_body_entered(stroke)
	_assert(cg._deflected and cg.gravity_scale == 1.0, "Conveyor gear deflects with gravity on hitting drawn stroke")
	stroke.free()
	cg.free()
	
	# WorldElements checks
	var gate: WorldElements.MechanicalGate = WorldElements.MechanicalGate.new()
	gate._ready()
	_assert(gate.collision_layer == 1, "MechanicalGate blocks terrain layer initially")
	gate.open_gate()
	_assert(gate.is_open and gate.collision_layer == 0, "MechanicalGate clears collision when opened")
	gate.free()
	
	var laser: WorldElements.LaserBeam = WorldElements.LaserBeam.new()
	laser.disable_laser()
	_assert(laser.disabled_by_switch, "LaserBeam disables when switch triggers")
	laser.free()
	
	var spikes: WorldElements.SpikesHazard = WorldElements.SpikesHazard.new()
	spikes._ready()
	_assert(spikes.is_in_group("hazard") and spikes.get_display_name() == "Spikes", "SpikesHazard sets hazard group and name")
	spikes.free()
	
	var fan: WorldElements.WindFan = WorldElements.WindFan.new()
	var vent: WorldElements.DroneVent = WorldElements.DroneVent.new()
	var pad: WorldElements.SpringPad = WorldElements.SpringPad.new()
	var mp: WorldElements.MovingPlatform = WorldElements.MovingPlatform.new()
	_assert(fan != null and vent != null and pad != null and mp != null, "All WorldElements instantiate cleanly")
	fan.free()
	vent.free()
	pad.free()
	mp.free()

func _test_objective_evaluator() -> void:
	var ev: ObjectiveEvaluator = ObjectiveEvaluator.new()
	ev.configure({"type": "survival"}, 5.0, 1, 0, false)
	_assert(ev.step(2.0) == ObjectiveEvaluator.State.SIMULATING, "Survival still running at 2s")
	_assert(ev.step(3.1) == ObjectiveEvaluator.State.WON, "Survival wins at 5.1s")
	
	ev.configure({"type": "exit"}, 5.0, 1, 0, true)
	ev.robots_at_goal = 1
	_assert(ev.step(0.1) == ObjectiveEvaluator.State.WON, "Exit wins when robot reaches goal")
	
	ev.configure({"type": "switch", "required_switches": 1}, 5.0, 1, 1, true)
	ev.activated_switches = 1
	_assert(ev.step(1.0) == ObjectiveEvaluator.State.SIMULATING, "Switch+charger waits until robot reaches charger")
	ev.robots_at_goal = 1
	_assert(ev.step(0.1) == ObjectiveEvaluator.State.WON, "Switch+charger wins when both satisfied")
	
	ev.configure({"type": "switch", "required_switches": 1}, 5.0, 1, 1, false)
	ev.activated_switches = 1
	_assert(ev.step(5.1) == ObjectiveEvaluator.State.WON, "Switch+survival wins after survival timer")

func _test_save_recovery_and_economy() -> void:
	var test_path: String = "user://test_save_qa.json"
	var ProgressSaveScript: GDScript = load("res://scripts/progress_save.gd") as GDScript
	var ps: Variant = ProgressSaveScript.new()
	ps.data = ps.default_data()
	ps.data["unlocked_level"] = 5
	ps.data["last_selected_level"] = 4
	_assert(ps.save_now(test_path), "Atomic save succeeds")
	
	# Test v1 -> v2 migration
	var v1_data: Dictionary = {
		"schema_version": 1,
		"unlocked_level": 12.0,
		"last_selected_level": 10.0,
		"levels": {"1": {"stars": 3, "best_ink": 100.0, "attempts": 1, "completed": true}},
		"settings": {"sound_enabled": false}
	}
	var migrated: Dictionary = ps._migrate_and_validate(v1_data)
	_assert(migrated["schema_version"] == ps.SCHEMA_VERSION, "Schema migrates v1 to v2")
	_assert(migrated.has("privacy") and migrated["settings"].has("music_enabled"), "Missing v2 fields added on migration")
	
	# Test bolts & skin buying & Level 60 completion guard
	ps.data = ps.default_data()
	ps.add_bolts(100)
	_assert(ps.buy_skin_with_bolts("bot_tier_1"), "Can unlock skin with enough bolts")
	_assert(ps.get_bolts() == 20, "Bolts deducted properly")
	_assert(ps.get_selected_skin() == "bot_tier_1", "Bought skin auto-equipped")
	var win60: Dictionary = ps.record_level_win(60, 3, 50.0)
	_assert(str(win60["unlocked_skin"]) == "", "Level 60 does not emit nonexistent bot_tier_6 skin")
	_assert(int(win60["earned_bolts"]) == 80, "Level 60 grants master completion bonus bolts")
	
	# Reload valid JSON from disk
	ps.data = ps.default_data()
	ps.data["unlocked_level"] = 5
	ps.data["last_selected_level"] = 4
	ps.save_now(test_path)
	var ps_reload: Variant = ProgressSaveScript.new()
	ps_reload.load_save(test_path)
	_assert(int(ps_reload.data["unlocked_level"]) == 5, "Unlocked level persists across JSON reload")
	_assert(int(ps_reload.data["last_selected_level"]) == 4, "Last selected level persists across JSON reload")
	_assert(typeof(ps_reload.data["unlocked_level"]) == TYPE_INT, "Unlocked level normalizes back to int")
	ps_reload.free()
	
	# Corrupt primary file -> falls back cleanly
	var f: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	f.store_string("{corrupt_json")
	f.close()
	ps.load_save(test_path)
	_assert(ps.data["schema_version"] == ps.SCHEMA_VERSION, "Save recovers from corruption")
	ps.free()

func _test_monetization_idempotency() -> void:
	var ProgressSaveScript: GDScript = load("res://scripts/progress_save.gd") as GDScript
	var ps: Variant = ProgressSaveScript.new()
	ps.data = ps.default_data()
	var BillingScript: GDScript = load("res://scripts/billing_adapter.gd") as GDScript
	_assert(BillingScript != null and BillingScript.can_instantiate(), "BillingAdapter compiles and instantiates")
	if BillingScript != null and BillingScript.can_instantiate():
		var ba: Variant = BillingScript.new()
		ba.progress_save_override = ps
		_assert(not ba.verify_and_grant_purchase("remove_interstitial_ads", ""), "Empty token rejected")
		_assert(ba.verify_and_grant_purchase("remove_interstitial_ads", "tok_123"), "Valid token granted once")
		_assert(ps.has_remove_ads(), "Entitlement persisted on ProgressSave")
		_assert(not ba.verify_and_grant_purchase("remove_interstitial_ads", "tok_123"), "Duplicate token rejected")
		ba.free()
	
	var ConsentScript: GDScript = load("res://scripts/consent_manager.gd") as GDScript
	var cm: Variant = ConsentScript.new()
	cm.set_consent(false, false)
	var AdsScript: GDScript = load("res://scripts/ads_adapter.gd") as GDScript
	var aa: Variant = AdsScript.new()
	aa.progress_save_override = ps
	aa.consent_override = cm
	aa.record_level_completed()
	aa.record_level_completed()
	aa.record_level_completed()
	aa.record_level_completed()
	_assert(not aa.is_interstitial_ready(5), "Remove-ads entitlement suppresses interstitials")
	ps.set_remove_ads(false)
	_assert(not aa.is_interstitial_ready(2), "Tutorial levels 1-3 never show interstitials")
	_assert(aa.is_interstitial_ready(5), "Interstitial eligible on level 5 after interval without remove-ads")
	aa.free()
	cm.free()
	ps.free()
