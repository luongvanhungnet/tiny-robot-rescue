class_name RobotController
extends RigidBody2D

signal robot_died(reason: String, hit_pos: Vector2)
signal robot_reached_goal

enum RobotExpression { IDLE, SCARED, HAPPY }

var current_expression: RobotExpression = RobotExpression.IDLE
var is_alive: bool = true
var at_goal: bool = false
var move_toward_goal: bool = false
var goal_x: float = 0.0
var skin_id: String = "default"

var _blink_timer: float = 2.0
var _is_blinking: bool = false
var _danger_near: bool = false
var _stuck_frames: int = 0

func _ready() -> void:
	add_to_group("robot")
	collision_layer = 2 # robot
	collision_mask = 1 | 4 | 8 | 32 # terrain, line, hazard, goal
	lock_rotation = true
	contact_monitor = true
	max_contacts_reported = 6
	
	var ps := get_node_or_null("/root/ProgressSave") if is_inside_tree() else null
	if ps != null and ps.has_method("get_selected_skin"):
		skin_id = ps.get_selected_skin()
	
	if move_toward_goal:
		can_sleep = false
		var mat := PhysicsMaterial.new()
		mat.friction = 0.05
		mat.bounce = 0.0
		physics_material_override = mat
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if position.y > 1360.0 or position.x < -80.0 or position.x > 800.0:
		die("Robot fell out of bounds!")
		return
	
	if move_toward_goal and not at_goal and not freeze:
		var dx := goal_x - global_position.x
		var dir := signf(dx)
		if absf(dx) > 12.0:
			linear_velocity.x = lerpf(linear_velocity.x, dir * 155.0, 0.25)
			# Small step-up assist when climbing onto drawn bridges
			if absf(linear_velocity.x) < 28.0 and get_contact_count() > 0:
				_stuck_frames += 1
				if _stuck_frames >= 6:
					linear_velocity.y = minf(linear_velocity.y, -110.0)
					linear_velocity.x = dir * 140.0
					_stuck_frames = 0
			else:
				_stuck_frames = 0
		else:
			linear_velocity.x = lerpf(linear_velocity.x, 0.0, 0.3)
	
	# Dynamic expression reaction to nearby moving hazards during simulation
	if not freeze and not at_goal:
		var danger := false
		for h in get_tree().get_nodes_in_group("hazard"):
			if h is Node2D and not h.is_in_group("stationary_hazard"):
				if global_position.distance_to(h.global_position) < 165.0:
					danger = true
					break
		if danger != _danger_near:
			_danger_near = danger
			set_expression(RobotExpression.SCARED if danger else RobotExpression.IDLE)
	
	# Subtle idle blink
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(2.2, 4.0)
		else:
			_is_blinking = true
			_blink_timer = 0.12
		queue_redraw()

func set_expression(expr: RobotExpression) -> void:
	if current_expression != expr:
		current_expression = expr
		queue_redraw()

func _play_tone(freq_hz: float, duration_sec: float, volume_db: float) -> void:
	if not is_inside_tree():
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.play_tone(freq_hz, duration_sec, volume_db)

func die(reason: String) -> void:
	if not is_alive:
		return
	is_alive = false
	_danger_near = false
	set_expression(RobotExpression.SCARED)
	if is_inside_tree():
		var gm := get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("play_fail_zap"):
			gm.play_fail_zap()
			gm.vibrate(45)
		else:
			_play_tone(160.0, 0.22, -6.0)
	robot_died.emit(reason, global_position)

func reach_goal() -> void:
	if not is_alive or at_goal:
		return
	at_goal = true
	_danger_near = false
	set_expression(RobotExpression.HAPPY)
	_play_tone(660.0, 0.15, -8.0)
	robot_reached_goal.emit()

func _on_body_entered(body: Node) -> void:
	if not is_alive:
		return
	if body.is_in_group("hazard"):
		var label := str(body.call("get_display_name")) if body.has_method("get_display_name") else "Hazard"
		die("Hit by " + label + "!")

func _get_palette() -> Dictionary:
	match skin_id:
		"bot_tier_1":
			return {"body": Color("#ef4444"), "trim": Color("#7f1d1d"), "eye": Color("#fef08a"), "bulb": Color("#facc15")}
		"bot_tier_2":
			return {"body": Color("#e0f2fe"), "trim": Color("#0369a1"), "eye": Color("#f59e0b"), "bulb": Color("#38bdf8")}
		"bot_tier_3":
			return {"body": Color("#1e293b"), "trim": Color("#06b6d4"), "eye": Color("#22d3ee"), "bulb": Color("#e879f9")}
		"bot_tier_4":
			return {"body": Color("#d97706"), "trim": Color("#78350f"), "eye": Color("#fef3c7"), "bulb": Color("#fb923c")}
		"bot_tier_5":
			return {"body": Color("#facc15"), "trim": Color("#854d0e"), "eye": Color("#0f172a"), "bulb": Color("#38bdf8")}
		_:
			return {"body": Color("#f8fafc"), "trim": Color("#0f172a"), "eye": Color("#0ea5e9"), "bulb": Color("#fbbf24")}

func _draw() -> void:
	var pal := _get_palette()
	
	# Antenna (Crown for Golden Champion!)
	if skin_id == "bot_tier_5":
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -24), Vector2(-14, -38), Vector2(-5, -30), Vector2(0, -40), Vector2(5, -30), Vector2(14, -38), Vector2(12, -24)]), Color("#eab308"))
		draw_polyline(PackedVector2Array([Vector2(-12, -24), Vector2(-14, -38), Vector2(-5, -30), Vector2(0, -40), Vector2(5, -30), Vector2(14, -38), Vector2(12, -24)]), pal["trim"], 2.5)
	else:
		draw_line(Vector2(0, -24), Vector2(0, -36), Color("#94a3b8"), 4.0)
		draw_circle(Vector2(0, -38), 5.5, pal["bulb"])
		draw_arc(Vector2(0, -38), 5.5, 0, TAU, 16, pal["trim"], 2.0)
	
	# Main Chassis
	var body_rect := Rect2(-24, -24, 48, 44)
	draw_rect(body_rect, pal["body"], true)
	draw_rect(body_rect, pal["trim"], false, 3.0)
	
	# Skin visor/helmet detail
	if skin_id == "bot_tier_2": # Astro dome
		draw_arc(Vector2(0, -10), 22.0, PI, TAU, 20, Color("#38bdf8", 0.55), 3.0)
	elif skin_id == "bot_tier_3": # Cyber neon visor strip
		draw_rect(Rect2(-19, -13, 38, 14), Color("#0f172a"), true)
	elif skin_id == "bot_tier_1": # Knight crest
		draw_rect(Rect2(-24, -24, 48, 8), Color("#b91c1c"), true)
	
	# Wheels / Feet
	draw_circle(Vector2(-12, 22), 6.5, Color("#334155"))
	draw_circle(Vector2(12, 22), 6.5, Color("#334155"))
	draw_circle(Vector2(-12, 22), 2.5, Color("#cbd5e1"))
	draw_circle(Vector2(12, 22), 2.5, Color("#cbd5e1"))
	
	# Eyes & Mouth based on expression
	match current_expression:
		RobotExpression.IDLE:
			if _is_blinking:
				draw_line(Vector2(-14, -6), Vector2(-4, -6), pal["eye"], 3.0)
				draw_line(Vector2(4, -6), Vector2(14, -6), pal["eye"], 3.0)
			else:
				draw_circle(Vector2(-9, -6), 4.5, pal["eye"])
				draw_circle(Vector2(9, -6), 4.5, pal["eye"])
			draw_arc(Vector2(0, 6), 7.0, 0.2, PI - 0.2, 12, pal["trim"], 2.5)
		RobotExpression.SCARED:
			draw_circle(Vector2(-9, -6), 6.0, Color("#ef4444"))
			draw_circle(Vector2(9, -6), 6.0, Color("#ef4444"))
			draw_circle(Vector2(0, 9), 5.0, pal["trim"])
			if is_alive:
				# Cute panic exclamation mark above head
				draw_line(Vector2(24, -36), Vector2(24, -24), Color("#ef4444"), 4.0)
				draw_circle(Vector2(24, -18), 2.5, Color("#ef4444"))
		RobotExpression.HAPPY:
			draw_arc(Vector2(-9, -5), 5.0, PI, TAU, 10, Color("#10b981"), 3.0)
			draw_arc(Vector2(9, -5), 5.0, PI, TAU, 10, Color("#10b981"), 3.0)
			draw_arc(Vector2(0, 5), 9.0, 0.1, PI - 0.1, 14, Color("#10b981"), 3.0)
