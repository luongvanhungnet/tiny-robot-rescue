class_name DrawController
extends Node2D

signal stroke_started
signal stroke_updated(used_length: float, max_length: float)
signal stroke_completed(points: PackedVector2Array, used_length: float)
signal stroke_rejected(reason: String)

const MIN_STROKE_LENGTH := 20.0
const SAMPLE_DISTANCE := 8.0

var max_stroke_length: float = 400.0
var forbidden_rects: Array[Rect2] = []
var robot_positions: Array[Vector2] = []
var robot_exclusion_radius: float = 34.0
var drawing_enabled: bool = false

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
	_preview_line.points = PackedVector2Array()
	stroke_updated.emit(0.0, max_stroke_length)

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
	if not is_point_valid(pos):
		stroke_rejected.emit("forbidden_zone")
		return
	_is_drawing = true
	_points = PackedVector2Array([pos])
	_current_length = 0.0
	_preview_line.points = _points
	stroke_started.emit()
	stroke_updated.emit(0.0, max_stroke_length)

func _extend_stroke(pos: Vector2) -> void:
	if _points.is_empty():
		return
	var last := _points[_points.size() - 1]
	var dist := last.distance_to(pos)
	if dist < SAMPLE_DISTANCE:
		return
	if not is_point_valid(pos):
		return
	if _current_length + dist > max_stroke_length:
		var remaining := max_stroke_length - _current_length
		if remaining >= 2.0:
			var clamped_pos := last + (pos - last).normalized() * remaining
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
	if _current_length < MIN_STROKE_LENGTH or _points.size() < 2:
		reset_stroke()
		stroke_rejected.emit("too_short")
		return
	var final_points := _points.duplicate()
	var final_len := _current_length
	_preview_line.points = PackedVector2Array()
	stroke_completed.emit(final_points, final_len)

func is_point_valid(pos: Vector2) -> bool:
	if not pos.is_finite():
		return false
	for rect in forbidden_rects:
		if rect.has_point(pos):
			return false
	for r_pos in robot_positions:
		if pos.distance_to(r_pos) < robot_exclusion_radius:
			return false
	return true
