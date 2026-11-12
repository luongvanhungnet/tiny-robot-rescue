extends Node2D

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")

@onready var world_root: Node2D = $WorldRoot
@onready var draw_controller: DrawController = $DrawController
@onready var level_title_lbl: Label = $HUD/TopBar/LevelTitle
@onready var timer_lbl: Label = $HUD/TopBar/TimerLabel
@onready var ink_bar: ProgressBar = $HUD/InkBar
@onready var hint_lbl: Label = $HUD/HintLabel
@onready var pause_btn: Button = $HUD/TopBar/PauseButton
@onready var retry_btn: Button = $HUD/TopBar/RetryButton

@onready var result_panel: PanelContainer = $HUD/ResultPanel
@onready var result_title: Label = $HUD/ResultPanel/VBox/ResultTitle
@onready var result_desc: Label = $HUD/ResultPanel/VBox/ResultDesc
@onready var next_btn: Button = $HUD/ResultPanel/VBox/NextButton
@onready var replay_btn: Button = $HUD/ResultPanel/VBox/ReplayButton
@onready var hint_btn: Button = $HUD/ResultPanel/VBox/HintButton
@onready var home_btn: Button = $HUD/ResultPanel/VBox/HomeButton

var level_data: Dictionary = {}
var evaluator := ObjectiveEvaluator.new()
var state: ObjectiveEvaluator.State = ObjectiveEvaluator.State.READY
var robots: Array[RobotController] = []
var hazards: Array[HazardController] = []
var used_ink: float = 0.0
var is_paused: bool = false

func _ready() -> void:
	pause_btn.pressed.connect(_toggle_pause)
	retry_btn.pressed.connect(_retry_level)
	next_btn.pressed.connect(_next_level)
	replay_btn.pressed.connect(_retry_level)
	hint_btn.pressed.connect(_show_hint)
	home_btn.pressed.connect(func(): GameManager.go_home())
	
	draw_controller.stroke_started.connect(_on_stroke_started)
	draw_controller.stroke_updated.connect(_on_stroke_updated)
	draw_controller.stroke_completed.connect(_on_stroke_completed)
	draw_controller.stroke_rejected.connect(_on_stroke_rejected)
	
	_load_current_level()

func _load_current_level() -> void:
	for child in world_root.get_children():
		child.queue_free()
	robots.clear()
	hazards.clear()
	result_panel.visible = false
	is_paused = false
	get_tree().paused = false
	
	level_data = LevelLoader.load_level(GameManager.current_level_id)
	if level_data.is_empty():
		hint_lbl.text = "Error loading level %d" % GameManager.current_level_id
		return
	
	level_title_lbl.text = str(level_data["title"])
	var max_ink := float(level_data["max_stroke_length"])
	draw_controller.max_stroke_length = max_ink
	draw_controller.draw_zones.clear()
	for dz in level_data.get("draw_zones", []):
		draw_controller.draw_zones.append(Rect2(dz["x"], dz["y"], dz["w"], dz["h"]))
	draw_controller.forbidden_rects.clear()
	for fz in level_data["forbidden_zones"]:
		draw_controller.forbidden_rects.append(Rect2(fz["x"], fz["y"], fz["w"], fz["h"]))
	pause_btn.disabled = false
	pause_btn.text = "PAUSE"
	
	var switch_count := 0
	var r_positions: Array[Vector2] = []
	
	for obj in level_data["spawn_objects"]:
		var otype := str(obj["object_type"])
		var pos := Vector2(obj["position"][0], obj["position"][1])
		var props: Dictionary = obj.get("physics_properties", {})
		
		match otype:
			"platform":
				var scale_arr: Array = obj.get("scale", [200, 40])
				_spawn_platform(pos, Vector2(scale_arr[0], scale_arr[1]))
			"robot":
				var r := _spawn_robot(pos, props)
				robots.append(r)
				r_positions.append(pos)
			"gear", "block", "ball", "spring_ball", "conveyor_gear":
				var h := _spawn_hazard(otype, pos, props, obj.get("patrol_path", []))
				hazards.append(h)
			"charger":
				_spawn_charger(pos)
			"switch":
				switch_count += 1
				_spawn_switch(pos)
	
	draw_controller.robot_positions = r_positions
	draw_controller.reset_stroke()
	draw_controller.drawing_enabled = true
	
	var sim_dur := float(level_data["simulation_duration"])
	evaluator.configure(level_data["objective"], sim_dur, robots.size(), switch_count)
	timer_lbl.text = "%.1fs" % sim_dur
	ink_bar.max_value = max_ink
	ink_bar.value = max_ink
	
	var tut: Array = level_data.get("tutorial_steps", [])
	if not tut.is_empty():
		hint_lbl.text = str(tut[0])
	else:
		hint_lbl.text = "Draw one line to protect the robot!"
	
	state = ObjectiveEvaluator.State.READY
	ProgressSave.record_level_attempt(GameManager.current_level_id)

func _add_world_rect(parent: Node, sz: Vector2, col_val: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = sz
	rect.position = -sz * 0.5
	rect.color = col_val
	parent.add_child(rect)
	return rect

func _spawn_platform(pos: Vector2, sz: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 2 | 8
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = sz
	col.shape = shape
	body.add_child(col)
	_add_world_rect(body, sz, Color("#475569"))
	world_root.add_child(body)

func _spawn_robot(pos: Vector2, props: Dictionary) -> RobotController:
	var r: RobotController = ROBOT_SCENE.instantiate()
	r.position = pos
	r.freeze = true
	r.move_toward_goal = bool(props.get("move_toward_goal", false))
	r.goal_x = float(props.get("goal_x", pos.x))
	r.robot_died.connect(_on_robot_died)
	r.robot_reached_goal.connect(_on_robot_reached_goal)
	world_root.add_child(r)
	return r

func _spawn_hazard(otype: String, pos: Vector2, props: Dictionary, patrol_arr: Array) -> HazardController:
	var h := HazardController.new()
	h.hazard_type = otype
	h.position = pos
	h.freeze = true
	h.radius = float(props.get("radius", 26.0))
	h.box_size = Vector2(float(props.get("w", 56.0)), float(props.get("h", 56.0)))
	if props.has("initial_velocity"):
		var iv: Array = props["initial_velocity"]
		h.initial_velocity = Vector2(iv[0], iv[1])
	h.patrol_speed = float(props.get("patrol_speed", 120.0))
	for pt in patrol_arr:
		h.patrol_points.append(Vector2(pt[0], pt[1]))
	
	var col := CollisionShape2D.new()
	if otype == "block":
		var shape := RectangleShape2D.new()
		shape.size = h.box_size
		col.shape = shape
	else:
		var shape := CircleShape2D.new()
		shape.radius = h.radius
		col.shape = shape
	h.add_child(col)
	world_root.add_child(h)
	return h

func _spawn_charger(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 32
	area.collision_mask = 2
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	col.shape = shape
	area.add_child(col)
	_add_world_rect(area, Vector2(64, 64), Color("#10b981", 0.75))
	
	area.body_entered.connect(func(body: Node):
		if body is RobotController:
			body.reach_goal()
	)
	world_root.add_child(area)

func _spawn_switch(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 16
	area.collision_mask = 2 | 8
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(56, 30)
	col.shape = shape
	area.add_child(col)
	var rect := _add_world_rect(area, Vector2(56, 30), Color("#3b82f6"))
	
	var activated := false
	area.body_entered.connect(func(_body: Node):
		if not activated and state == ObjectiveEvaluator.State.SIMULATING:
			activated = true
			rect.color = Color("#22c55e")
			evaluator.activated_switches += 1
			GameManager.play_tone(520.0, 0.12, -8.0)
	)
	world_root.add_child(area)

func _on_stroke_started() -> void:
	state = ObjectiveEvaluator.State.DRAWING

func _on_stroke_updated(used: float, max_len: float) -> void:
	ink_bar.value = maxf(0.0, max_len - used)

func _on_stroke_rejected(reason: String) -> void:
	if reason == "too_short":
		hint_lbl.text = "Line too short! Draw a longer line."
	elif reason == "forbidden_zone":
		hint_lbl.text = "Cannot draw inside robots or forbidden zones!"
	elif reason == "outside_draw_zone":
		hint_lbl.text = "Draw inside the play area!"
	state = ObjectiveEvaluator.State.READY

func _on_stroke_completed(points: PackedVector2Array, used_len: float) -> void:
	var stroke_body := StrokePhysicsBuilder.build_stroke_body(points)
	if stroke_body == null:
		_on_stroke_rejected("too_short")
		return
	used_ink = used_len
	world_root.add_child(stroke_body)
	draw_controller.drawing_enabled = false
	state = ObjectiveEvaluator.State.SIMULATING
	hint_lbl.text = "Simulating..."
	for r in robots:
		r.freeze = false
	for h in hazards:
		h.start_simulation()

func _physics_process(delta: float) -> void:
	if state != ObjectiveEvaluator.State.SIMULATING or is_paused:
		return
	var next_state := evaluator.step(delta)
	var remaining := maxf(0.0, evaluator.simulation_duration - evaluator.elapsed_time)
	timer_lbl.text = "%.1fs" % remaining
	
	if next_state == ObjectiveEvaluator.State.WON:
		_on_win()
	elif next_state == ObjectiveEvaluator.State.LOST:
		_on_loss(evaluator.loss_reason)

func _on_robot_died(reason: String) -> void:
	evaluator.alive_robots -= 1
	evaluator.loss_reason = reason

func _on_robot_reached_goal() -> void:
	evaluator.robots_at_goal += 1

func _on_win() -> void:
	state = ObjectiveEvaluator.State.WON
	for r in robots:
		r.set_expression(RobotController.RobotExpression.HAPPY)
	GameManager.play_tone(880.0, 0.25, -8.0)
	
	var max_ink := float(level_data["max_stroke_length"])
	var stars := 3 if used_ink <= max_ink * 0.65 else (2 if used_ink <= max_ink * 0.9 else 1)
	ProgressSave.record_level_win(GameManager.current_level_id, stars, used_ink)
	AdsAdapter.record_level_completed()
	AdsAdapter.show_interstitial_if_ready(GameManager.current_level_id)
	
	hint_lbl.text = "Level Complete!"
	pause_btn.disabled = true
	result_title.text = "RESCUED! (%d/3 Stars)" % stars
	result_desc.text = "Ink used: %.0f / %.0f" % [used_ink, max_ink]
	next_btn.visible = GameManager.current_level_id < GameManager.TOTAL_VERTICAL_SLICE_LEVELS
	hint_btn.visible = false
	result_panel.visible = true

func _on_loss(reason: String) -> void:
	state = ObjectiveEvaluator.State.LOST
	hint_lbl.text = "Try again!"
	pause_btn.disabled = true
	result_title.text = "OOPS!"
	result_desc.text = reason
	next_btn.visible = false
	hint_btn.visible = true
	result_panel.visible = true

func _show_hint() -> void:
	result_desc.text = "HINT: " + str(level_data.get("hint", "Try a different angle!"))

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
