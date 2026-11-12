extends Node2D

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")

@onready var world_root: Node2D = $WorldRoot
@onready var telegraph_layer: Node2D = $TelegraphLayer
@onready var draw_controller: DrawController = $DrawController
@onready var level_title_lbl: Label = $HUD/TopBar/LevelTitle
@onready var timer_lbl: Label = $HUD/TopBar/TimerLabel
@onready var ink_bar: ProgressBar = $HUD/InkRow/InkBar
@onready var hint_hud_btn: Button = $HUD/InkRow/HintHUDButton
@onready var hint_lbl: Label = $HUD/HintLabel
@onready var pause_btn: Button = $HUD/TopBar/PauseButton
@onready var retry_btn: Button = $HUD/TopBar/RetryButton

@onready var result_panel: PanelContainer = $HUD/ResultPanel
@onready var result_title: Label = $HUD/ResultPanel/VBox/ResultTitle
@onready var result_desc: Label = $HUD/ResultPanel/VBox/ResultDesc
@onready var reward_ad_btn: Button = $HUD/ResultPanel/VBox/RewardAdButton
@onready var next_btn: Button = $HUD/ResultPanel/VBox/NextButton
@onready var replay_btn: Button = $HUD/ResultPanel/VBox/ReplayButton
@onready var hint_btn: Button = $HUD/ResultPanel/VBox/HintButton
@onready var home_btn: Button = $HUD/ResultPanel/VBox/HomeButton

var level_data: Dictionary = {}
var evaluator := ObjectiveEvaluator.new()
var state: ObjectiveEvaluator.State = ObjectiveEvaluator.State.READY
var robots: Array[RobotController] = []
var hazards: Array[HazardController] = []
var gates: Array[WorldElements.MechanicalGate] = []
var lasers: Array[WorldElements.LaserBeam] = []
var fans: Array[WorldElements.WindFan] = []
var moving_platforms: Array[WorldElements.MovingPlatform] = []
var drone_vents: Array[WorldElements.DroneVent] = []
var used_ink: float = 0.0
var is_paused: bool = false

var _telegraph_arrows: Array[Dictionary] = []
var _shake_strength: float = 0.0
var _loss_pending: bool = false
var _loss_timer: float = 0.0
var _loss_reason_pending: String = ""
var _loss_hit_pos: Vector2 = Vector2.ZERO
var _hint_unlocked_this_run: bool = false
var _bonus_claimed_this_win: bool = false
var _pending_ad_placement: String = ""

func _ready() -> void:
	_apply_ui_styles()
	pause_btn.pressed.connect(_toggle_pause)
	retry_btn.pressed.connect(_retry_level)
	next_btn.pressed.connect(_next_level)
	replay_btn.pressed.connect(_retry_level)
	hint_btn.pressed.connect(_request_hint)
	hint_hud_btn.pressed.connect(_request_hint)
	reward_ad_btn.pressed.connect(_request_bonus_bolts_ad)
	home_btn.pressed.connect(func(): GameManager.go_home())
	
	draw_controller.stroke_started.connect(_on_stroke_started)
	draw_controller.stroke_updated.connect(_on_stroke_updated)
	draw_controller.stroke_completed.connect(_on_stroke_completed)
	draw_controller.stroke_rejected.connect(_on_stroke_rejected)
	telegraph_layer.draw.connect(_on_draw_telegraphs)
	
	AdsAdapter.rewarded_ad_completed.connect(_on_rewarded_ad_completed)
	AdsAdapter.rewarded_ad_failed.connect(_on_rewarded_ad_failed)
	
	_load_current_level()

func _exit_tree() -> void:
	if AdsAdapter.rewarded_ad_completed.is_connected(_on_rewarded_ad_completed):
		AdsAdapter.rewarded_ad_completed.disconnect(_on_rewarded_ad_completed)
	if AdsAdapter.rewarded_ad_failed.is_connected(_on_rewarded_ad_failed):
		AdsAdapter.rewarded_ad_failed.disconnect(_on_rewarded_ad_failed)

func _apply_ui_styles() -> void:
	UIThemeHelper.style_button(pause_btn, Color("#334155"), Color("#0f172a"))
	UIThemeHelper.style_button(retry_btn, Color("#0284c7"), Color("#0c4a6e"))
	UIThemeHelper.style_button(hint_hud_btn, Color("#d97706"), Color("#78350f"))
	UIThemeHelper.style_button(next_btn, Color("#16a34a"), Color("#14532d"))
	UIThemeHelper.style_button(replay_btn, Color("#0284c7"), Color("#0c4a6e"))
	UIThemeHelper.style_button(hint_btn, Color("#d97706"), Color("#78350f"))
	UIThemeHelper.style_button(reward_ad_btn, Color("#9333ea"), Color("#581c87"))
	UIThemeHelper.style_button(home_btn, Color("#475569"), Color("#1e293b"))

func _load_current_level() -> void:
	for child in world_root.get_children():
		child.queue_free()
	robots.clear()
	hazards.clear()
	gates.clear()
	lasers.clear()
	fans.clear()
	moving_platforms.clear()
	drone_vents.clear()
	_telegraph_arrows.clear()
	
	result_panel.visible = false
	reward_ad_btn.visible = false
	is_paused = false
	_loss_pending = false
	_loss_timer = 0.0
	_loss_hit_pos = Vector2.ZERO
	_shake_strength = 0.0
	_hint_unlocked_this_run = false
	_bonus_claimed_this_win = false
	world_root.position = Vector2.ZERO
	get_tree().paused = false
	
	level_data = LevelLoader.load_level(GameManager.current_level_id)
	if level_data.is_empty():
		hint_lbl.text = "Error loading level %d" % GameManager.current_level_id
		return
	
	# Background themed per chapter
	var bg: WorldElements.WorkshopBackground = WorldElements.WorkshopBackground.new()
	bg.z_index = -10
	bg.setup(str(level_data.get("background_id", "workshop_day")))
	world_root.add_child(bg)
	
	level_title_lbl.text = str(level_data["title"])
	var max_ink: float = float(level_data["max_stroke_length"])
	draw_controller.max_stroke_length = max_ink
	draw_controller.draw_zones.clear()
	for dz in level_data.get("draw_zones", []):
		draw_controller.draw_zones.append(Rect2(float(dz["x"]), float(dz["y"]), float(dz["w"]), float(dz["h"])))
	draw_controller.forbidden_rects.clear()
	for fz in level_data["forbidden_zones"]:
		draw_controller.forbidden_rects.append(Rect2(float(fz["x"]), float(fz["y"]), float(fz["w"]), float(fz["h"])))
	
	# Load optional guide points
	var guide_pts: PackedVector2Array = PackedVector2Array()
	for gp in level_data.get("expected_solution_guide", []):
		guide_pts.append(Vector2(float(gp[0]), float(gp[1])))
	draw_controller.hint_guide_points = guide_pts
	draw_controller.show_hint_guide = false
	if GameManager.current_level_id == 1:
		draw_controller.tutorial_guide_points = PackedVector2Array([Vector2(240, 740), Vector2(360, 680), Vector2(480, 740)])
		draw_controller.show_tutorial_guide = true
	else:
		draw_controller.tutorial_guide_points = PackedVector2Array()
		draw_controller.show_tutorial_guide = false
	
	pause_btn.disabled = false
	pause_btn.text = "PAUSE"
	
	var switch_count: int = 0
	var charger_present: bool = false
	var r_positions: Array[Vector2] = []
	
	for obj in level_data["spawn_objects"]:
		var otype: String = str(obj["object_type"])
		var pos: Vector2 = Vector2(float(obj["position"][0]), float(obj["position"][1]))
		var props: Dictionary = obj.get("physics_properties", {})
		
		match otype:
			"platform":
				var scale_arr: Array = obj.get("scale", [200, 40])
				_spawn_platform(pos, Vector2(float(scale_arr[0]), float(scale_arr[1])))
			"moving_platform":
				var scale_arr: Array = obj.get("scale", [160, 32])
				_spawn_moving_platform(pos, Vector2(float(scale_arr[0]), float(scale_arr[1])), obj.get("patrol_path", []), props)
			"robot":
				var r: RobotController = _spawn_robot(pos, props)
				robots.append(r)
				r_positions.append(pos)
			"gear", "block", "rock", "ball", "spring_ball", "conveyor_gear":
				var h: HazardController = _spawn_hazard(otype, pos, props, obj.get("patrol_path", []))
				hazards.append(h)
			"charger":
				charger_present = true
				_spawn_charger(pos)
			"switch":
				switch_count += 1
				_spawn_switch(pos)
			"gate":
				var scale_arr: Array = obj.get("scale", [28, 130])
				_spawn_gate(pos, Vector2(float(scale_arr[0]), float(scale_arr[1])))
			"spikes":
				var scale_arr: Array = obj.get("scale", [120, 22])
				_spawn_spikes(pos, float(scale_arr[0]))
			"spring_pad":
				_spawn_spring_pad(pos, props)
			"fan":
				_spawn_fan(pos, props)
			"laser":
				_spawn_laser(pos, props)
			"drone_vent":
				_spawn_drone_vent(pos, props)
	
	draw_controller.robot_positions = r_positions
	draw_controller.reset_stroke()
	draw_controller.drawing_enabled = true
	
	var sim_dur: float = float(level_data["simulation_duration"])
	evaluator.configure(level_data["objective"], sim_dur, robots.size(), switch_count, charger_present)
	timer_lbl.text = "%.1fs" % sim_dur
	ink_bar.max_value = max_ink
	ink_bar.value = max_ink
	
	var clean_mode: bool = GameManager.is_clean_capture_mode()
	hint_hud_btn.visible = not clean_mode
	hint_lbl.visible = not clean_mode
	
	var tut: Array = level_data.get("tutorial_steps", [])
	if not tut.is_empty():
		hint_lbl.text = str(tut[0])
	elif evaluator.objective_type == "exit":
		hint_lbl.text = "Guide the robot safely to the green charger!"
	elif evaluator.objective_type == "switch":
		hint_lbl.text = "Activate the blue switch and protect the robot!"
	else:
		hint_lbl.text = "Draw one line to protect the robot!"
	
	state = ObjectiveEvaluator.State.READY
	ProgressSave.record_level_attempt(GameManager.current_level_id)
	_update_hint_button_labels()
	telegraph_layer.queue_redraw()

func _spawn_platform(pos: Vector2, sz: Vector2) -> void:
	var plat: WorldElements.StyledPlatform = WorldElements.StyledPlatform.new()
	plat.position = pos
	plat.box_size = sz
	world_root.add_child(plat)

func _spawn_moving_platform(pos: Vector2, sz: Vector2, patrol_arr: Array, props: Dictionary) -> void:
	var mp: WorldElements.MovingPlatform = WorldElements.MovingPlatform.new()
	mp.position = pos
	mp.box_size = sz
	mp.speed = float(props.get("speed", 110.0))
	for pt in patrol_arr:
		mp.patrol_points.append(Vector2(float(pt[0]), float(pt[1])))
	world_root.add_child(mp)
	moving_platforms.append(mp)

func _spawn_robot(pos: Vector2, props: Dictionary) -> RobotController:
	var r: RobotController = ROBOT_SCENE.instantiate() as RobotController
	r.position = pos
	r.freeze = true
	r.move_toward_goal = bool(props.get("move_toward_goal", false))
	r.goal_x = float(props.get("goal_x", pos.x))
	r.robot_died.connect(_on_robot_died)
	r.robot_reached_goal.connect(_on_robot_reached_goal)
	world_root.add_child(r)
	return r

func _spawn_hazard(otype: String, pos: Vector2, props: Dictionary, patrol_arr: Array) -> HazardController:
	var h: HazardController = HazardController.new()
	h.hazard_type = otype
	h.position = pos
	h.freeze = true
	h.radius = float(props.get("radius", 26.0))
	h.box_size = Vector2(float(props.get("w", 56.0)), float(props.get("h", 56.0)))
	if props.has("initial_velocity"):
		var iv: Array = props["initial_velocity"]
		h.initial_velocity = Vector2(float(iv[0]), float(iv[1]))
	h.patrol_speed = float(props.get("patrol_speed", 120.0))
	for pt in patrol_arr:
		h.patrol_points.append(Vector2(float(pt[0]), float(pt[1])))
	h.hit_stroke.connect(_on_hazard_hit_stroke)
	
	var col: CollisionShape2D = CollisionShape2D.new()
	if otype == "block":
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = h.box_size
		col.shape = shape
	else:
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = h.radius
		col.shape = shape
	h.add_child(col)
	world_root.add_child(h)
	
	# Danger telegraph arrow
	if h.initial_velocity != Vector2.ZERO:
		_telegraph_arrows.append({"from": pos, "dir": h.initial_velocity.normalized(), "len": 64.0})
	elif not h.patrol_points.is_empty():
		var pdir: Vector2 = h.patrol_points[0] - pos
		if pdir.length() < 4.0 and h.patrol_points.size() > 1:
			pdir = h.patrol_points[1] - pos
		if pdir.length() > 1.0:
			_telegraph_arrows.append({"from": pos, "dir": pdir.normalized(), "len": 72.0})
	elif otype in ["gear", "block", "rock", "ball"]:
		_telegraph_arrows.append({"from": pos, "dir": Vector2.DOWN, "len": 52.0})
	
	return h

func _spawn_charger(pos: Vector2) -> void:
	var area := WorldElements.StyledCharger.new()
	area.position = pos
	area.body_entered.connect(func(body: Node):
		if body is RobotController:
			body.reach_goal()
	)
	world_root.add_child(area)

func _spawn_switch(pos: Vector2) -> void:
	var sw := WorldElements.StyledSwitch.new()
	sw.position = pos
	sw.body_entered.connect(func(_body: Node):
		if not sw.activated and state == ObjectiveEvaluator.State.SIMULATING:
			sw.activate()
			evaluator.activated_switches += 1
			GameManager.play_switch_click()
			GameManager.vibrate(20)
			if evaluator.activated_switches >= evaluator.required_switches:
				for g in gates:
					g.open_gate()
				for l in lasers:
					l.disable_laser()
	)
	world_root.add_child(sw)

func _spawn_gate(pos: Vector2, sz: Vector2) -> void:
	var g := WorldElements.MechanicalGate.new()
	g.position = pos
	g.box_size = sz
	world_root.add_child(g)
	gates.append(g)

func _spawn_spikes(pos: Vector2, width: float) -> void:
	var sp := WorldElements.SpikesHazard.new()
	sp.position = pos
	sp.width = width
	world_root.add_child(sp)

func _spawn_spring_pad(pos: Vector2, props: Dictionary) -> void:
	var pad: WorldElements.SpringPad = WorldElements.SpringPad.new()
	pad.position = pos
	var lv: Array = props.get("launch_velocity", [180, -680])
	pad.launch_velocity = Vector2(float(lv[0]), float(lv[1]))
	world_root.add_child(pad)

func _spawn_fan(pos: Vector2, props: Dictionary) -> void:
	var fan: WorldElements.WindFan = WorldElements.WindFan.new()
	fan.position = pos
	var d_arr: Array = props.get("direction", [1, 0])
	fan.blow_dir = Vector2(float(d_arr[0]), float(d_arr[1])).normalized()
	fan.wind_range = float(props.get("range", 380.0))
	fan.wind_width = float(props.get("width", 96.0))
	fan.strength = float(props.get("strength", 820.0))
	world_root.add_child(fan)
	fans.append(fan)

func _spawn_laser(pos: Vector2, props: Dictionary) -> void:
	var las: WorldElements.LaserBeam = WorldElements.LaserBeam.new()
	las.position = pos
	var d_arr: Array = props.get("direction", [1, 0])
	las.beam_dir = Vector2(float(d_arr[0]), float(d_arr[1])).normalized()
	las.max_len = float(props.get("max_length", 700.0))
	world_root.add_child(las)
	lasers.append(las)

func _spawn_drone_vent(pos: Vector2, props: Dictionary) -> void:
	var vent: WorldElements.DroneVent = WorldElements.DroneVent.new()
	vent.position = pos
	vent.drone_count = int(props.get("drone_count", 4))
	vent.spawn_drone_requested.connect(_on_spawn_drone)
	world_root.add_child(vent)
	drone_vents.append(vent)

func _on_spawn_drone(spawn_pos: Vector2) -> void:
	if state != ObjectiveEvaluator.State.SIMULATING:
		return
	var d: HazardController = _spawn_hazard("spark_drone", spawn_pos, {"radius": 15.0}, [])
	d.freeze = false
	hazards.append(d)
	_spawn_burst(spawn_pos, Color("#a855f7"), 8)

func _on_hazard_hit_stroke(pos: Vector2) -> void:
	_spawn_burst(pos, Color("#38bdf8"), 10)
	GameManager.play_impact_spark()
	GameManager.vibrate(10)

func _spawn_burst(pos: Vector2, col: Color, count: int) -> void:
	if GameManager.is_reduced_motion():
		return
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = count
	p.lifetime = 0.38
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = col
	world_root.add_child(p)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)

func _on_stroke_started() -> void:
	state = ObjectiveEvaluator.State.DRAWING
	GameManager.vibrate(8)
	telegraph_layer.queue_redraw()

func _on_stroke_updated(used: float, max_len: float) -> void:
	ink_bar.value = maxf(0.0, max_len - used)

func _on_stroke_rejected(reason: String) -> void:
	GameManager.vibrate(18)
	if reason == "too_short":
		hint_lbl.text = "Line too short! Draw a longer line."
	elif reason == "forbidden_zone":
		hint_lbl.text = "Cannot draw inside robots or forbidden zones!"
	elif reason == "outside_draw_zone":
		hint_lbl.text = "Draw inside the play area!"
	state = ObjectiveEvaluator.State.READY

func _on_stroke_completed(points: PackedVector2Array, used_len: float) -> void:
	var stroke_body: StaticBody2D = StrokePhysicsBuilder.build_stroke_body(points)
	if stroke_body == null:
		_on_stroke_rejected("too_short")
		return
	used_ink = used_len
	world_root.add_child(stroke_body)
	draw_controller.drawing_enabled = false
	state = ObjectiveEvaluator.State.SIMULATING
	hint_lbl.text = "Hold on! Simulating..."
	GameManager.play_tone(360.0, 0.08, -10.0, 480.0)
	GameManager.vibrate(14)
	telegraph_layer.queue_redraw()
	
	for r in robots:
		r.freeze = false
	for h in hazards:
		h.start_simulation()
	for f in fans:
		f.active = true
	for l in lasers:
		l.active = true
	for mp in moving_platforms:
		mp.active = true
	for dv in drone_vents:
		dv.active = true

func _process(delta: float) -> void:
	if _shake_strength > 0.0 and not GameManager.is_reduced_motion():
		_shake_strength = maxf(0.0, _shake_strength - delta * 28.0)
		world_root.position = Vector2(randf_range(-_shake_strength, _shake_strength), randf_range(-_shake_strength, _shake_strength))
	else:
		world_root.position = Vector2.ZERO
	
	if _loss_pending:
		_loss_timer -= delta
		telegraph_layer.queue_redraw()
		if _loss_timer <= 0.0:
			_loss_pending = false
			_show_loss_panel(_loss_reason_pending)

func _physics_process(delta: float) -> void:
	if state != ObjectiveEvaluator.State.SIMULATING or is_paused or _loss_pending:
		return
	var next_state: ObjectiveEvaluator.State = evaluator.step(delta)
	var remaining: float = maxf(0.0, evaluator.simulation_duration - evaluator.elapsed_time)
	timer_lbl.text = "%.1fs" % remaining
	
	if next_state == ObjectiveEvaluator.State.WON:
		_on_win()
	elif next_state == ObjectiveEvaluator.State.LOST:
		_begin_loss_sequence(evaluator.loss_reason)

func _on_robot_died(reason: String, hit_pos: Vector2) -> void:
	if state != ObjectiveEvaluator.State.SIMULATING:
		return
	evaluator.alive_robots -= 1
	evaluator.loss_reason = reason
	_loss_hit_pos = hit_pos
	_shake_strength = 9.0
	_spawn_burst(hit_pos, Color("#ef4444"), 18)

func _on_robot_reached_goal() -> void:
	if state != ObjectiveEvaluator.State.SIMULATING:
		return
	evaluator.robots_at_goal += 1

func _begin_loss_sequence(reason: String) -> void:
	state = ObjectiveEvaluator.State.LOST
	_loss_pending = true
	_loss_timer = 0.25 if GameManager.is_reduced_motion() else 0.65
	_loss_reason_pending = reason
	hint_lbl.text = reason
	pause_btn.disabled = true
	for dv in drone_vents:
		dv.active = false
	for l in lasers:
		l.active = false
	for f in fans:
		f.active = false

func _show_loss_panel(reason: String) -> void:
	result_title.text = "OOPS!"
	result_desc.text = reason
	reward_ad_btn.visible = false
	next_btn.visible = false
	hint_btn.visible = true
	_update_hint_button_labels()
	result_panel.visible = true

func _on_win() -> void:
	state = ObjectiveEvaluator.State.WON
	for r in robots:
		r.mark_rescued()
		_spawn_burst(r.global_position, Color("#22c55e"), 20)
		_spawn_burst(r.global_position, Color("#facc15"), 14)
	for h in hazards:
		if is_instance_valid(h):
			h.freeze = true
	for dv in drone_vents:
		dv.active = false
	for l in lasers:
		l.active = false
	for f in fans:
		f.active = false
	for mp in moving_platforms:
		mp.active = false
	
	GameManager.play_win_fanfare()
	GameManager.vibrate(25)
	
	var max_ink: float = float(level_data["max_stroke_length"])
	var stars: int = 3 if used_ink <= max_ink * 0.65 else (2 if used_ink <= max_ink * 0.9 else 1)
	var win_res: Dictionary = ProgressSave.record_level_win(GameManager.current_level_id, stars, used_ink)
	AdsAdapter.record_level_completed()
	AdsAdapter.show_interstitial_if_ready(GameManager.current_level_id)
	
	hint_lbl.text = "Level Complete!"
	pause_btn.disabled = true
	result_title.text = "RESCUED! (%d/3 Stars)" % stars
	var desc: String = "Ink used: %.0f / %.0f\n+%d Bolts earned!" % [used_ink, max_ink, int(win_res["earned_bolts"])]
	if str(win_res["unlocked_skin"]) != "":
		desc += "\nNEW ROBOT SKIN UNLOCKED!"
	result_desc.text = desc
	
	reward_ad_btn.visible = AdsAdapter.is_rewarded_sdk_available() and not _bonus_claimed_this_win
	reward_ad_btn.disabled = false
	next_btn.visible = GameManager.current_level_id < GameManager.TOTAL_LEVELS
	hint_btn.visible = false
	result_panel.visible = true

func _is_free_hint_unlocked() -> bool:
	var stats: Dictionary = ProgressSave.get_level_stats(GameManager.current_level_id)
	return _hint_unlocked_this_run or int(stats.get("attempts", 0)) >= 3 or bool(stats.get("completed", false))

func _update_hint_button_labels() -> void:
	var free_ok: bool = _is_free_hint_unlocked()
	var txt: String = "FREE HINT" if free_ok else ("HINT (AD)" if AdsAdapter.is_rewarded_sdk_available() else "HINT")
	hint_btn.text = txt
	hint_hud_btn.text = "HINT"

func _request_hint() -> void:
	if _is_free_hint_unlocked():
		_apply_hint_reveal()
		return
	if AdsAdapter.is_rewarded_sdk_available():
		_pending_ad_placement = "level_hint"
		AdsAdapter.show_rewarded_ad("level_hint", "hint_%d_%d" % [GameManager.current_level_id, Time.get_ticks_msec()])
	else:
		# Offline fallback (Spec 7.2): free hint after 3 attempts
		var attempts: int = int(ProgressSave.get_level_stats(GameManager.current_level_id).get("attempts", 0))
		var msg: String = "Offline: Free hint unlocks after 3 attempts (%d/3)." % attempts
		hint_lbl.text = msg
		if result_panel.visible:
			result_desc.text = msg

func _request_bonus_bolts_ad() -> void:
	if _bonus_claimed_this_win:
		return
	_pending_ad_placement = "bonus_bolts"
	AdsAdapter.show_rewarded_ad("bonus_bolts", "win_bolts_%d_%d" % [GameManager.current_level_id, Time.get_ticks_msec()])

func _on_rewarded_ad_completed(placement_id: String) -> void:
	if placement_id == "level_hint":
		_hint_unlocked_this_run = true
		_apply_hint_reveal()
	elif placement_id == "bonus_bolts" and not _bonus_claimed_this_win:
		_bonus_claimed_this_win = true
		ProgressSave.add_bolts(25)
		reward_ad_btn.visible = false
		result_desc.text += "\n+25 Bonus Bolts Claimed!"

func _on_rewarded_ad_failed(placement_id: String, _reason: String) -> void:
	if placement_id == _pending_ad_placement:
		_pending_ad_placement = ""
		if result_panel.visible:
			result_desc.text += "\nAd unavailable offline."

func _apply_hint_reveal() -> void:
	_hint_unlocked_this_run = true
	var h_text: String = "HINT: " + str(level_data.get("hint", "Try a different angle!"))
	hint_lbl.text = h_text
	if result_panel.visible:
		result_desc.text = h_text
	if not draw_controller.hint_guide_points.is_empty():
		draw_controller.show_hint_guide = true

func _on_draw_telegraphs() -> void:
	if state == ObjectiveEvaluator.State.READY or state == ObjectiveEvaluator.State.DRAWING:
		for arr in _telegraph_arrows:
			var from: Vector2 = arr["from"]
			var dir: Vector2 = arr["dir"]
			var length: float = arr["len"]
			var to: Vector2 = from + dir * length
			telegraph_layer.draw_dashed_line(from, to, Color("#ef4444", 0.6), 4.0, 8.0)
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			var tip: Vector2 = to + dir * 10.0
			telegraph_layer.draw_colored_polygon(PackedVector2Array([tip, to + perp * 7.0, to - perp * 7.0]), Color("#ef4444", 0.75))
	elif _loss_pending and _loss_hit_pos != Vector2.ZERO:
		var r: float = 36.0 + sin(float(Time.get_ticks_msec()) * 0.025) * 6.0
		telegraph_layer.draw_arc(_loss_hit_pos, r, 0.0, TAU, 28, Color("#ef4444", 0.9), 4.0)

func _toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_btn.text = "RESUME" if is_paused else "PAUSE"

func _retry_level() -> void:
	get_tree().paused = false
	_load_current_level()

func _next_level() -> void:
	get_tree().paused = false
	GameManager.start_level(GameManager.current_level_id + 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().paused = false
		GameManager.go_level_select()
