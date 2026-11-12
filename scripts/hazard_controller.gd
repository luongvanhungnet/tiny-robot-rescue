class_name HazardController
extends RigidBody2D

signal hit_stroke(contact_pos: Vector2)

var hazard_type: String = "gear"
var radius: float = 26.0
var box_size: Vector2 = Vector2(56, 56)
var initial_velocity: Vector2 = Vector2.ZERO
var patrol_points: Array[Vector2] = []
var patrol_speed: float = 120.0
var _patrol_idx: int = 0
var _deflected: bool = false
var _spark_cooldown: float = 0.0
var _buzz_phase: float = 0.0

func get_display_name() -> String:
	match hazard_type:
		"gear":
			return "Spinning Gear"
		"conveyor_gear":
			return "Patrol Gear"
		"block":
			return "Heavy Block"
		"rock":
			return "Heavy Boulder"
		"ball":
			return "Bouncing Ball"
		"spring_ball":
			return "Spring Ball"
		"spark_drone":
			return "Spark-Drone"
		_:
			return "Hazard"

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 8 # hazard
	collision_mask = 1 | 2 | 4 | 8 | 16 # terrain, robot, line, hazard, trigger
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	
	if hazard_type == "ball":
		var mat := PhysicsMaterial.new()
		mat.bounce = 0.48
		mat.friction = 0.1
		physics_material_override = mat
	elif hazard_type == "spring_ball":
		var mat := PhysicsMaterial.new()
		mat.bounce = 0.72
		mat.friction = 0.1
		physics_material_override = mat
	elif hazard_type == "rock":
		mass = 3.5
		var mat := PhysicsMaterial.new()
		mat.bounce = 0.22
		mat.friction = 0.35
		physics_material_override = mat
	elif hazard_type == "conveyor_gear":
		gravity_scale = 0.0
		lock_rotation = false
		var mat := PhysicsMaterial.new()
		mat.bounce = 0.45
		mat.friction = 0.05
		physics_material_override = mat
	elif hazard_type == "spark_drone":
		gravity_scale = 0.0
		lock_rotation = true
		can_sleep = false
		var mat := PhysicsMaterial.new()
		mat.bounce = 0.88
		mat.friction = 0.0
		physics_material_override = mat
		_buzz_phase = randf() * TAU

func start_simulation() -> void:
	freeze = false
	if initial_velocity != Vector2.ZERO:
		linear_velocity = initial_velocity

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("drawn_stroke"):
		if _spark_cooldown <= 0.0 and linear_velocity.length() > 45.0:
			_spark_cooldown = 0.18
			hit_stroke.emit(global_position)
		if hazard_type == "conveyor_gear" and not _deflected:
			# Deflect naturally onto gravity physics once it hits a drawn ramp/wall
			_deflected = true
			gravity_scale = 1.0
			linear_velocity.y = minf(linear_velocity.y, -260.0)

func _physics_process(delta: float) -> void:
	if freeze:
		return
	if _spark_cooldown > 0.0:
		_spark_cooldown -= delta
	
	if hazard_type == "gear" or hazard_type == "conveyor_gear":
		rotation += 4.5 * delta
	elif hazard_type == "spark_drone":
		_buzz_phase += delta * 12.0
		var target_robot := _find_nearest_alive_robot()
		if target_robot != null:
			var to_r := (target_robot.global_position - global_position)
			if to_r.length() > 1.0:
				var desired := to_r.normalized() * 235.0
				# Slight playful buzz perpendicular oscillation
				var perp := Vector2(-to_r.y, to_r.x).normalized() * sin(_buzz_phase) * 45.0
				linear_velocity = linear_velocity.lerp(desired + perp, clampf(delta * 3.8, 0.0, 1.0))
		queue_redraw()
	
	if not patrol_points.is_empty() and not _deflected:
		var target := patrol_points[_patrol_idx]
		var to_target := target - global_position
		if to_target.length() < 10.0:
			_patrol_idx = (_patrol_idx + 1) % patrol_points.size()
		else:
			linear_velocity = to_target.normalized() * patrol_speed
	
	if linear_velocity.length() > 950.0:
		linear_velocity = linear_velocity.normalized() * 950.0

func _find_nearest_alive_robot() -> RobotController:
	if not is_inside_tree():
		return null
	var best: RobotController = null
	var best_dist := INF
	for n in get_tree().get_nodes_in_group("robot"):
		if n is RobotController and n.is_alive:
			var d := global_position.distance_squared_to(n.global_position)
			if d < best_dist:
				best_dist = d
				best = n
	return best

func _draw() -> void:
	match hazard_type:
		"gear", "conveyor_gear":
			draw_circle(Vector2.ZERO, radius, Color("#ef4444"))
			for i in range(8):
				var ang := i * TAU / 8.0
				var p1 := Vector2(cos(ang), sin(ang)) * (radius - 2.0)
				var p2 := Vector2(cos(ang), sin(ang)) * (radius + 8.0)
				draw_line(p1, p2, Color("#dc2626"), 6.0)
			draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color("#7f1d1d"), 2.5)
			draw_circle(Vector2.ZERO, radius * 0.35, Color("#1e293b"))
		"block":
			var r := Rect2(-box_size * 0.5, box_size)
			draw_rect(r, Color("#f97316"), true)
			draw_rect(r, Color("#7c2d12"), false, 3.0)
			draw_line(Vector2(-box_size.x * 0.3, -box_size.y * 0.3), Vector2(box_size.x * 0.3, box_size.y * 0.3), Color("#9a3412"), 3.0)
			draw_line(Vector2(box_size.x * 0.3, -box_size.y * 0.3), Vector2(-box_size.x * 0.3, box_size.y * 0.3), Color("#9a3412"), 3.0)
		"rock":
			draw_circle(Vector2.ZERO, radius, Color("#64748b"))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 16, Color("#1e293b"), 3.0)
			draw_circle(Vector2(-radius * 0.3, -radius * 0.2), radius * 0.2, Color("#94a3b8"))
			draw_circle(Vector2(radius * 0.25, radius * 0.25), radius * 0.15, Color("#475569"))
		"ball", "spring_ball":
			var fill_c := Color("#eab308") if hazard_type == "ball" else Color("#ec4899")
			var rim_c := Color("#713f12") if hazard_type == "ball" else Color("#831843")
			draw_circle(Vector2.ZERO, radius, fill_c)
			draw_arc(Vector2.ZERO, radius, 0, TAU, 24, rim_c, 3.0)
			draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.2, Color(1, 1, 1, 0.45))
		"spark_drone":
			var wing_y := sin(_buzz_phase * 2.0) * 4.0
			draw_line(Vector2(-10, -8), Vector2(-18, -14 + wing_y), Color("#cbd5e1"), 3.0)
			draw_line(Vector2(10, -8), Vector2(18, -14 - wing_y), Color("#cbd5e1"), 3.0)
			draw_circle(Vector2.ZERO, radius, Color("#7c3aed"))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 18, Color("#2e1065"), 2.5)
			draw_circle(Vector2(-5, -2), 3.2, Color("#fde047"))
			draw_circle(Vector2(5, -2), 3.2, Color("#fde047"))
			draw_line(Vector2(0, radius - 2), Vector2(0, radius + 6), Color("#fde047"), 3.0)
