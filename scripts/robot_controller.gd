class_name RobotController
extends RigidBody2D

signal robot_died(reason: String)
signal robot_reached_goal

enum Expression { IDLE, SCARED, HAPPY }

var current_expression: Expression = Expression.IDLE
var is_alive: bool = true
var at_goal: bool = false
var move_toward_goal: bool = false
var goal_x: float = 0.0

func _ready() -> void:
	collision_layer = 2 # robot
	collision_mask = 1 | 4 | 8 | 32 # terrain, line, hazard, goal
	lock_rotation = true
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if not is_alive:
		return
	if position.y > 1360.0 or position.x < -80.0 or position.x > 800.0:
		die("Robot fell out of bounds!")
		return
	if move_toward_goal and not at_goal and not freeze:
		var dir := signf(goal_x - global_position.x)
		if absf(goal_x - global_position.x) > 12.0:
			linear_velocity.x = lerpf(linear_velocity.x, dir * 130.0, 0.08)

func set_expression(expr: Expression) -> void:
	if current_expression != expr:
		current_expression = expr
		queue_redraw()

func die(reason: String) -> void:
	if not is_alive:
		return
	is_alive = false
	set_expression(Expression.SCARED)
	GameManager.play_tone(160.0, 0.22, -6.0)
	robot_died.emit(reason)

func reach_goal() -> void:
	if not is_alive or at_goal:
		return
	at_goal = true
	set_expression(Expression.HAPPY)
	GameManager.play_tone(660.0, 0.15, -8.0)
	robot_reached_goal.emit()

func _on_body_entered(body: Node) -> void:
	if not is_alive:
		return
	if body.is_in_group("hazard"):
		die("Hit by " + body.name + "!")

func _draw() -> void:
	# Antenna
	draw_line(Vector2(0, -24), Vector2(0, -36), Color("#94a3b8"), 4.0)
	draw_circle(Vector2(0, -38), 5.0, Color("#fbbf24"))
	
	# Body
	var body_rect := Rect2(-24, -24, 48, 44)
	draw_rect(body_rect, Color("#f8fafc"), true)
	draw_rect(body_rect, Color("#0f172a"), false, 3.0)
	
	# Wheels / Feet
	draw_circle(Vector2(-12, 22), 6.0, Color("#475569"))
	draw_circle(Vector2(12, 22), 6.0, Color("#475569"))
	
	# Eyes & Mouth based on expression
	match current_expression:
		Expression.IDLE:
			draw_circle(Vector2(-9, -6), 4.5, Color("#0ea5e9"))
			draw_circle(Vector2(9, -6), 4.5, Color("#0ea5e9"))
			draw_arc(Vector2(0, 6), 7.0, 0.2, PI - 0.2, 12, Color("#0f172a"), 2.5)
		Expression.SCARED:
			draw_circle(Vector2(-9, -6), 6.0, Color("#ef4444"))
			draw_circle(Vector2(9, -6), 6.0, Color("#ef4444"))
			draw_circle(Vector2(0, 9), 5.0, Color("#0f172a"))
		Expression.HAPPY:
			draw_arc(Vector2(-9, -5), 5.0, PI, TAU, 10, Color("#10b981"), 3.0)
			draw_arc(Vector2(9, -5), 5.0, PI, TAU, 10, Color("#10b981"), 3.0)
			draw_arc(Vector2(0, 5), 9.0, 0.1, PI - 0.1, 14, Color("#10b981"), 3.0)
