class_name DrawController
extends Node2D

signal stroke_started
signal stroke_updated(used_length: float, max_length: float)
signal stroke_completed(points: PackedVector2Array, used_length: float)
signal stroke_rejected(reason: String)

const MIN_STROKE_LENGTH := 20.0
const SAMPLE_DISTANCE := 8.0

var max_stroke_length: float = 400.0
var draw_zones: Array[Rect2] = []
var forbidden_rects: Array[Rect2] = []
var robot_positions: Array[Vector2] = []
var robot_exclusion_radius: float = 34.0
var drawing_enabled: bool = false:
	set(v):
		drawing_enabled = v
		queue_redraw()

var _is_drawing: bool = false
var _points: PackedVector2Array = PackedVector2Array()
var _current_length: float = 0.0
var _preview_line: Line2D

func _ready() -> void:
	_preview_line = Line2D.new()
	_preview_line.width = StrokePhysicsBuilder.LINE_RADIUS * 2.0
	_preview_line.default_color = Color("#38bdf8", 0.85)
	_preview_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_preview_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_preview_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_preview_line.antialiased = true
	add_child(_preview_line)

func reset_stroke() -> void:
	_is_drawing = false
	_points = PackedVector2Array()
	_current_length = 0.0
	if _preview_line != null:
		_preview_line.points = PackedVector2Array()
	stroke_updated.emit(0.0, max_stroke_length)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not drawing_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_stroke(event.position)
		elif _is_drawing:
			_end_stroke()
	elif event is InputEventScreenDrag and _is_drawing:
		_extend_stroke(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_stroke(event.position)
		elif _is_drawing:
			_end_stroke()
	elif event is InputEventMouseMotion and _is_drawing:
		_extend_stroke(event.position)

func _begin_stroke(pos: Vector2) -> void:
	var reason := get_invalid_reason(pos)
	if reason != "":
		stroke_rejected.emit(reason)
		return
	_is_drawing = true
	_points = PackedVector2Array([pos])
	_current_length = 0.0
	_preview_line.points = _points
	stroke_started.emit()
	stroke_updated.emit(0.0, max_stroke_length)
	queue_redraw()

func _extend_stroke(pos: Vector2) -> void:
	if _points.is_empty():
		return
	var last := _points[_points.size() - 1]
	var dist := last.distance_to(pos)
	if dist < SAMPLE_DISTANCE:
		return
	if not is_segment_valid(last, pos):
		return
	if _current_length + dist > max_stroke_length:
		var remaining := max_stroke_length - _current_length
		if remaining >= 2.0:
			var clamped_pos := last + (pos - last).normalized() * remaining
			if is_segment_valid(last, clamped_pos):
				_points.append(clamped_pos)
				_current_length = max_stroke_length
				_preview_line.points = _points
				stroke_updated.emit(_current_length, max_stroke_length)
		return
	_points.append(pos)
	_current_length += dist
	_preview_line.points = _points
	stroke_updated.emit(_current_length, max_stroke_length)

func _end_stroke() -> void:
	_is_drawing = false
	queue_redraw()
	if _current_length < MIN_STROKE_LENGTH or _points.size() < 2:
		reset_stroke()
		stroke_rejected.emit("too_short")
		return
	var final_points := _points.duplicate()
	var final_len := _current_length
	_preview_line.points = PackedVector2Array()
	stroke_completed.emit(final_points, final_len)

func _is_in_draw_zones(pos: Vector2) -> bool:
	if draw_zones.is_empty():
		return true
	for rect in draw_zones:
		if rect.has_point(pos):
			return true
	return false

func get_invalid_reason(pos: Vector2) -> String:
	if not pos.is_finite():
		return "outside_draw_zone"
	if not _is_in_draw_zones(pos):
		return "outside_draw_zone"
	for rect in forbidden_rects:
		if rect.has_point(pos):
			return "forbidden_zone"
	for r_pos in robot_positions:
		if pos.distance_to(r_pos) < robot_exclusion_radius:
			return "forbidden_zone"
	return ""

func is_point_valid(pos: Vector2) -> bool:
	return get_invalid_reason(pos) == ""

func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var tl := rect.position
	var tr := Vector2(rect.end.x, rect.position.y)
	var br := rect.end
	var bl := Vector2(rect.position.x, rect.end.y)
	return (
		Geometry2D.segment_intersects_segment(a, b, tl, tr) != null
		or Geometry2D.segment_intersects_segment(a, b, tr, br) != null
		or Geometry2D.segment_intersects_segment(a, b, br, bl) != null
		or Geometry2D.segment_intersects_segment(a, b, bl, tl) != null
	)

func is_segment_valid(a: Vector2, b: Vector2) -> bool:
	if not is_point_valid(b):
		return false
	for r_pos in robot_positions:
		if Geometry2D.segment_intersects_circle(a, b, r_pos, robot_exclusion_radius) >= 0.0:
			return false
	for rect in forbidden_rects:
		if _segment_intersects_rect(a, b, rect):
			return false
	return true

func _draw() -> void:
	if not drawing_enabled:
		return
	for rect in draw_zones:
		draw_rect(rect, Color("#cbd5e1", 0.55), false, 2.0)
	for rect in forbidden_rects:
		draw_rect(rect, Color("#ef4444", 0.18), true)
		draw_rect(rect, Color("#ef4444", 0.55), false, 2.0)
	if _is_drawing:
		for r_pos in robot_positions:
			draw_arc(r_pos, robot_exclusion_radius, 0.0, TAU, 28, Color("#ef4444", 0.45), 2.0)
