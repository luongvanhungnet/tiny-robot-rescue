class_name WorldElements
extends RefCounted

class WorkshopBackground extends Node2D:
	var bg_id: String = "workshop_day"
	var _palette := {
		"bg": Color("#eff6ff"),
		"grid": Color("#cbd5e1", 0.42),
		"accent": Color("#93c5fd", 0.3)
	}
	func setup(id_str: String) -> void:
		bg_id = id_str
		match id_str:
			"drone_factory":
				_palette = {"bg": Color("#f5f3ff"), "grid": Color("#ddd6fe", 0.55), "accent": Color("#c4b5fd", 0.35)}
			"skybridge_yard":
				_palette = {"bg": Color("#ecfeff"), "grid": Color("#bae6fd", 0.5), "accent": Color("#7dd3fc", 0.3)}
			"wind_lab":
				_palette = {"bg": Color("#f0fdf4"), "grid": Color("#bbf7d0", 0.5), "accent": Color("#86efac", 0.3)}
			"volt_chamber":
				_palette = {"bg": Color("#fff7ed"), "grid": Color("#fed7aa", 0.5), "accent": Color("#fdba74", 0.3)}
			"master_core":
				_palette = {"bg": Color("#fef2f2"), "grid": Color("#fecaca", 0.5), "accent": Color("#fca5a5", 0.3)}
			_:
				_palette = {"bg": Color("#f1f5f9"), "grid": Color("#cbd5e1", 0.45), "accent": Color("#94a3b8", 0.25)}
		queue_redraw()
	
	func _draw() -> void:
		draw_rect(Rect2(-120, -120, 960, 1520), _palette["bg"], true)
		for x in range(0, 760, 40):
			draw_line(Vector2(x, 0), Vector2(x, 1280), _palette["grid"], 1.0)
		for y in range(0, 1320, 40):
			draw_line(Vector2(0, y), Vector2(720, y), _palette["grid"], 1.0)
		# Subtle blueprint border frame
		draw_rect(Rect2(40, 200, 640, 900), _palette["accent"], false, 3.0)

class StyledPlatform extends StaticBody2D:
	var box_size: Vector2 = Vector2(200, 40)
	func _ready() -> void:
		collision_layer = 1
		collision_mask = 2 | 8
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = box_size
		col.shape = shape
		add_child(col)
	func _draw() -> void:
		var r := Rect2(-box_size * 0.5, box_size)
		draw_rect(r, Color("#475569"), true)
		draw_rect(Rect2(-box_size.x * 0.5, -box_size.y * 0.5, box_size.x, 8), Color("#64748b"), true)
		draw_rect(r, Color("#1e293b"), false, 3.0)
		# Rivets
		var hw := box_size.x * 0.5 - 12.0
		if hw > 10.0:
			draw_circle(Vector2(-hw, 0), 3.5, Color("#94a3b8"))
			draw_circle(Vector2(hw, 0), 3.5, Color("#94a3b8"))

class MovingPlatform extends AnimatableBody2D:
	var box_size: Vector2 = Vector2(160, 32)
	var patrol_points: Array[Vector2] = []
	var speed: float = 110.0
	var active: bool = false
	var _idx: int = 1
	func _ready() -> void:
		collision_layer = 1
		collision_mask = 2 | 8
		sync_to_physics = true
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = box_size
		col.shape = shape
		add_child(col)
	func _physics_process(delta: float) -> void:
		if not active or patrol_points.size() < 2:
			return
		var target: Vector2 = patrol_points[_idx % patrol_points.size()]
		var to_t: Vector2 = target - global_position
		var step: float = speed * delta
		if to_t.length() <= step:
			global_position = target
			_idx = (_idx + 1) % patrol_points.size()
		else:
			global_position += to_t.normalized() * step
	func _draw() -> void:
		var r: Rect2 = Rect2(-box_size * 0.5, box_size)
		draw_rect(r, Color("#0284c7"), true)
		draw_rect(r, Color("#0c4a6e"), false, 3.0)
		draw_circle(Vector2(-box_size.x * 0.35, 0), 3.5, Color("#bae6fd"))
		draw_circle(Vector2(box_size.x * 0.35, 0), 3.5, Color("#bae6fd"))

class StyledCharger extends Area2D:
	var _t: float = 0.0
	func _ready() -> void:
		collision_layer = 32
		collision_mask = 2
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(64, 64)
		col.shape = shape
		add_child(col)
	func _process(delta: float) -> void:
		_t += delta * 3.0
		queue_redraw()
	func _draw() -> void:
		var pulse: float = 0.72 + 0.18 * sin(_t)
		draw_rect(Rect2(-32, -32, 64, 64), Color("#10b981", pulse), true)
		draw_rect(Rect2(-32, -32, 64, 64), Color("#065f46"), false, 3.0)
		# Lightning bolt symbol
		var bolt: PackedVector2Array = PackedVector2Array([
			Vector2(4, -20), Vector2(-12, 2), Vector2(0, 2),
			Vector2(-4, 20), Vector2(12, -2), Vector2(0, -2)
		])
		draw_colored_polygon(bolt, Color("#ecfdf5"))

class StyledSwitch extends Area2D:
	signal triggered
	var activated: bool = false
	func _ready() -> void:
		collision_layer = 16
		collision_mask = 2 | 8
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(58, 30)
		col.shape = shape
		add_child(col)
	func activate() -> void:
		if activated:
			return
		activated = true
		queue_redraw()
		triggered.emit()
	func _draw() -> void:
		draw_rect(Rect2(-29, 2, 58, 13), Color("#334155"), true)
		var cap_y: float = -4.0 if activated else -14.0
		var cap_col: Color = Color("#22c55e") if activated else Color("#3b82f6")
		draw_rect(Rect2(-24, cap_y, 48, 16), cap_col, true)
		draw_rect(Rect2(-24, cap_y, 48, 16), Color("#0f172a"), false, 2.5)

class MechanicalGate extends StaticBody2D:
	var box_size: Vector2 = Vector2(28, 130)
	var is_open: bool = false
	var _open_offset: float = 0.0
	var _base_pos: Vector2
	func _ready() -> void:
		_base_pos = position
		collision_layer = 1
		collision_mask = 2 | 8
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = box_size
		col.shape = shape
		add_child(col)
	func open_gate() -> void:
		if is_open:
			return
		is_open = true
		collision_layer = 0
		collision_mask = 0
	func _process(delta: float) -> void:
		if is_open and _open_offset < box_size.y:
			_open_offset = minf(box_size.y, _open_offset + 280.0 * delta)
			position = _base_pos - Vector2(0, _open_offset)
			queue_redraw()
	func _draw() -> void:
		var alpha: float = clampf(1.0 - (_open_offset / maxf(1.0, box_size.y)), 0.0, 1.0)
		if alpha <= 0.02:
			return
		var r: Rect2 = Rect2(-box_size * 0.5, box_size)
		draw_rect(r, Color("#eab308", alpha), true)
		draw_rect(r, Color("#713f12", alpha), false, 3.0)
		draw_circle(Vector2.ZERO, 6.0, Color("#0f172a", alpha))

class SpikesHazard extends StaticBody2D:
	var width: float = 120.0
	func get_display_name() -> String:
		return "Spikes"
	func _ready() -> void:
		add_to_group("hazard")
		add_to_group("stationary_hazard")
		collision_layer = 8
		collision_mask = 2 | 8
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(width, 22)
		col.shape = shape
		add_child(col)
	func _draw() -> void:
		var hw: float = width * 0.5
		draw_rect(Rect2(-hw, 4, width, 7), Color("#334155"), true)
		var count: int = maxi(2, int(width / 20.0))
		var step: float = width / float(count)
		for i in range(count):
			var x0: float = -hw + float(i) * step
			var tri: PackedVector2Array = PackedVector2Array([
				Vector2(x0, 5),
				Vector2(x0 + step * 0.5, -13),
				Vector2(x0 + step, 5)
			])
			draw_colored_polygon(tri, Color("#ef4444"))
			draw_polyline(tri, Color("#7f1d1d"), 2.0)

class SpringPad extends Area2D:
	var launch_velocity: Vector2 = Vector2(180, -680)
	var _bounce_anim: float = 0.0
	var _cooldown: float = 0.0
	func _ready() -> void:
		collision_layer = 16
		collision_mask = 2 | 8
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(64, 24)
		col.shape = shape
		add_child(col)
		body_entered.connect(_on_body_entered)
	func _process(delta: float) -> void:
		if _cooldown > 0.0:
			_cooldown -= delta
		if _bounce_anim > 0.0:
			_bounce_anim = maxf(0.0, _bounce_anim - delta * 4.0)
			queue_redraw()
	func _on_body_entered(body: Node) -> void:
		if _cooldown > 0.0:
			return
		if body is RigidBody2D and not body.freeze:
			_cooldown = 0.2
			_bounce_anim = 1.0
			body.linear_velocity = launch_velocity
			var gm: Variant = get_node_or_null("/root/GameManager") if is_inside_tree() else null
			if gm != null and gm.has_method("play_spring_boing"):
				gm.play_spring_boing()
			queue_redraw()
	func _draw() -> void:
		var lift: float = _bounce_anim * 10.0
		draw_rect(Rect2(-32, 4, 64, 8), Color("#334155"), true)
		draw_line(Vector2(-16, 4), Vector2(16, -6 - lift), Color("#94a3b8"), 4.0)
		draw_line(Vector2(16, 4), Vector2(-16, -6 - lift), Color("#94a3b8"), 4.0)
		draw_rect(Rect2(-32, -12 - lift, 64, 10), Color("#f97316"), true)
		draw_rect(Rect2(-32, -12 - lift, 64, 10), Color("#7c2d12"), false, 2.5)

class WindFan extends Node2D:
	var blow_dir: Vector2 = Vector2.RIGHT
	var wind_range: float = 380.0
	var wind_width: float = 96.0
	var strength: float = 780.0
	var active: bool = false
	var _anim: float = 0.0
	var _blocked_dist: float = 380.0
	func _ready() -> void:
		_blocked_dist = wind_range
	func _process(delta: float) -> void:
		_anim += delta
		queue_redraw()
	func _physics_process(_delta: float) -> void:
		var dir: Vector2 = blow_dir.normalized()
		if is_inside_tree() and get_world_2d() != null:
			var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
			var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + dir * 26.0, global_position + dir * wind_range, 1 | 4)
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				var hit_pos: Vector2 = hit["position"]
				_blocked_dist = clampf(global_position.distance_to(hit_pos), 28.0, wind_range)
			else:
				_blocked_dist = wind_range
		if not active:
			return
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var half_w: float = wind_width * 0.5
		var targets: Array[Node] = []
		targets.append_array(get_tree().get_nodes_in_group("robot"))
		targets.append_array(get_tree().get_nodes_in_group("hazard"))
		for t in targets:
			if t is RigidBody2D and not t.freeze and not t.is_in_group("stationary_hazard"):
				var rel: Vector2 = t.global_position - global_position
				var along: float = rel.dot(dir)
				var across: float = rel.dot(perp)
				if along >= 10.0 and along <= wind_range and absf(across) <= half_w:
					var blocked: bool = false
					if is_inside_tree() and get_world_2d() != null:
						var origin: Vector2 = global_position + dir * 24.0 + perp * across
						var q2: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, t.global_position, 1 | 4)
						var h2: Dictionary = get_world_2d().direct_space_state.intersect_ray(q2)
						if not h2.is_empty():
							blocked = true
					if not blocked:
						t.apply_central_force(dir * strength)
	func _draw() -> void:
		var dir: Vector2 = blow_dir.normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		# Fan housing
		draw_circle(Vector2.ZERO, 24.0, Color("#0f172a"))
		draw_circle(Vector2.ZERO, 19.0, Color("#06b6d4"))
		for i in range(3):
			var ang: float = _anim * 8.0 + float(i) * TAU / 3.0
			draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * 15.0, Color("#ecfeff"), 3.5)
		# Animated wind streaks stopped at _blocked_dist
		for lane in [-26.0, 0.0, 26.0]:
			var lane_f: float = float(lane)
			var offset: float = fmod(_anim * 220.0 + absf(lane_f) * 3.0, _blocked_dist)
			var seg_len: float = minf(48.0, _blocked_dist - offset)
			if seg_len > 6.0:
				var p1: Vector2 = perp * lane_f + dir * (28.0 + offset)
				var p2: Vector2 = perp * lane_f + dir * (28.0 + offset + seg_len)
				draw_line(p1, p2, Color("#38bdf8", 0.55), 3.0)

class LaserBeam extends Node2D:
	var beam_dir: Vector2 = Vector2.RIGHT
	var max_len: float = 700.0
	var disabled_by_switch: bool = false
	var active: bool = false
	var _end_point: Vector2 = Vector2.RIGHT * 700.0
	var _pulse: float = 0.0
	func _ready() -> void:
		_end_point = beam_dir.normalized() * max_len
	func disable_laser() -> void:
		disabled_by_switch = true
		queue_redraw()
	func _process(delta: float) -> void:
		_pulse += delta * 10.0
		queue_redraw()
	func _physics_process(_delta: float) -> void:
		if disabled_by_switch:
			return
		var dir: Vector2 = beam_dir.normalized()
		_end_point = dir * max_len
		if is_inside_tree() and get_world_2d() != null:
			var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
			var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + dir * 20.0, global_position + dir * max_len, 1 | 2 | 4 | 8)
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				var hit_pos: Vector2 = hit["position"]
				_end_point = to_local(hit_pos)
				var col_obj: Variant = hit["collider"]
				if active and col_obj is RobotController:
					(col_obj as RobotController).die("Zapped by Laser!")
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 18.0, Color("#1e293b"))
		draw_circle(Vector2.ZERO, 9.0, Color("#64748b") if disabled_by_switch else Color("#ef4444"))
		if disabled_by_switch:
			return
		var dir: Vector2 = beam_dir.normalized()
		var w: float = 6.0 + sin(_pulse) * 1.5
		draw_line(dir * 18.0, _end_point, Color("#ef4444", 0.35), w + 6.0)
		draw_line(dir * 18.0, _end_point, Color("#fca5a5"), w * 0.55)
		draw_circle(_end_point, 7.0, Color("#ef4444"))

class DroneVent extends Node2D:
	signal spawn_drone_requested(spawn_pos: Vector2)
	var drone_count: int = 4
	var active: bool = false
	var _spawned: int = 0
	var _timer: float = 0.0
	var _pulse: float = 0.0
	func _process(delta: float) -> void:
		_pulse += delta * 4.0
		if active and _spawned < drone_count:
			_timer -= delta
			if _timer <= 0.0:
				_spawned += 1
				_timer = 0.28
				var offset: Vector2 = Vector2(randf_range(-12.0, 12.0), 26.0)
				spawn_drone_requested.emit(global_position + offset)
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(-28, -24, 56, 48), Color("#4c1d95"), true)
		draw_rect(Rect2(-28, -24, 56, 48), Color("#1e1b4b"), false, 3.0)
		for y_off in [-8.0, 2.0, 12.0]:
			draw_line(Vector2(-18, float(y_off)), Vector2(18, float(y_off)), Color("#a78bfa"), 3.0)
		var glow: float = 0.6 + 0.4 * sin(_pulse)
		draw_circle(Vector2(0, -16), 5.0, Color("#facc15", glow))
