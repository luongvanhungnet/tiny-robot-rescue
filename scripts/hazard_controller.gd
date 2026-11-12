class_name HazardController
extends RigidBody2D

var hazard_type: String = "gear"
var radius: float = 26.0
var box_size: Vector2 = Vector2(56, 56)
var initial_velocity: Vector2 = Vector2.ZERO
var patrol_points: Array[Vector2] = []
var patrol_speed: float = 120.0
var _patrol_idx: int = 0

func get_display_name() -> String:
	match hazard_type:
		"gear":
			return "Spinning Gear"
		"conveyor_gear":
			return "Patrol Gear"
		"block":
			return "Heavy Block"
		"ball":
			return "Bouncing Ball"
		"spring_ball":
			return "Spring Ball"
		_:
			return "Hazard"

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 8 # hazard
	collision_mask = 1 | 2 | 4 | 8 | 16 # terrain, robot, line, hazard, trigger
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
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
	elif hazard_type == "conveyor_gear":
		gravity_scale = 0.0
		lock_rotation = false

func start_simulation() -> void:
	freeze = false
	if initial_velocity != Vector2.ZERO:
		linear_velocity = initial_velocity

func _physics_process(delta: float) -> void:
	if freeze:
		return
	if hazard_type == "gear" or hazard_type == "conveyor_gear":
		rotation += 4.0 * delta
	if not patrol_points.is_empty():
		var target := patrol_points[_patrol_idx]
		var to_target := target - global_position
		if to_target.length() < 10.0:
			_patrol_idx = (_patrol_idx + 1) % patrol_points.size()
		else:
			linear_velocity = to_target.normalized() * patrol_speed
	# Cap excessively fast motion
	if linear_velocity.length() > 950.0:
		linear_velocity = linear_velocity.normalized() * 950.0

func _draw() -> void:
	match hazard_type:
		"gear", "conveyor_gear":
			draw_circle(Vector2.ZERO, radius, Color("#ef4444"))
			for i in range(8):
				var ang := i * TAU / 8.0
				var p1 := Vector2(cos(ang), sin(ang)) * (radius - 2.0)
				var p2 := Vector2(cos(ang), sin(ang)) * (radius + 8.0)
				draw_line(p1, p2, Color("#dc2626"), 6.0)
			draw_circle(Vector2.ZERO, radius * 0.35, Color("#1e293b"))
		"block":
			var r := Rect2(-box_size * 0.5, box_size)
			draw_rect(r, Color("#f97316"), true)
			draw_rect(r, Color("#7c2d12"), false, 3.0)
		"ball", "spring_ball":
			draw_circle(Vector2.ZERO, radius, Color("#eab308"))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color("#713f12"), 3.0)
