class_name StrokePhysicsBuilder
extends RefCounted

const MIN_SEGMENT_LENGTH := 4.0
const LINE_RADIUS := 7.0
const MAX_VERTICES := 120

static func build_stroke_body(points: PackedVector2Array, core_color: Color = Color("#0ea5e9")) -> StaticBody2D:
	var cleaned := simplify_points(points, MIN_SEGMENT_LENGTH, MAX_VERTICES)
	if cleaned.size() < 2:
		return null
	
	var body := StaticBody2D.new()
	body.name = "DrawnStroke"
	body.add_to_group("drawn_stroke")
	body.collision_layer = 4 # Layer 3: line
	body.collision_mask = 2 | 8 # Collides with robot (2) and hazard (8)
	
	var mat := PhysicsMaterial.new()
	mat.friction = 0.55
	mat.bounce = 0.0
	body.physics_material_override = mat
	
	for i in range(cleaned.size() - 1):
		var a := cleaned[i]
		var b := cleaned[i + 1]
		var dist := a.distance_to(b)
		if dist < 1.0 or not a.is_finite() or not b.is_finite():
			continue
		var shape := CapsuleShape2D.new()
		shape.radius = LINE_RADIUS
		shape.height = dist + LINE_RADIUS * 2.0
		
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = (a + b) * 0.5
		col.rotation = (b - a).angle() + PI * 0.5
		body.add_child(col)
	
	# Crisp dark cartoon outline
	var outline := Line2D.new()
	outline.points = cleaned
	outline.width = LINE_RADIUS * 2.0 + 4.0
	outline.default_color = Color("#0f172a")
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.antialiased = true
	body.add_child(outline)
	
	# Vibrant inner core
	var line := Line2D.new()
	line.points = cleaned
	line.width = LINE_RADIUS * 2.0
	line.default_color = core_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	body.add_child(line)
	
	return body

static func simplify_points(points: PackedVector2Array, min_dist: float, max_verts: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.is_empty():
		return out
	for p in points:
		if not p.is_finite():
			continue
		if out.is_empty() or out[out.size() - 1].distance_to(p) >= min_dist:
			out.append(p)
			if out.size() >= max_verts:
				break
	return out

static func compute_polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total
