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
var tutorial_guide_points: PackedVector2Array = PackedVector2Array()
var hint_guide_points: PackedVector2Array = PackedVector2Array()
var show_tutorial_guide: bool = false:
	set(v):
		show_tutorial_guide = v
		queue_redraw()
var show_hint_guide: bool = false:
	set(v):
		show_hint_guide = v
		queue_redraw()
var drawing_enabled: bool = false:
	set(v):
		drawing_enabled = v
		queue_redraw()

var _is_drawing: bool = false
var _points: PackedVector2Array = PackedVector2Array()
var _current_length: float = 0.0
var _preview_outline: Line2D
var _preview_line: Line2D
var _anim_time: float = 0.0
var _warning_pos: Vector2 = Vector2(-999, -999)
var _warning_timer: float = 0.0

func _ready() -> void:
	_preview_outline = Line2D.new()
	_preview_outline.width = StrokePhysicsBuilder.LINE_RADIUS * 2.0 + 4.0
	_preview_outline.default_color = Color("#0f172a", 0.8)
	_preview_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_preview_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_preview_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	_preview_outline.antialiased = true
	add_child(_preview_outline)
	
	_preview_line = Line2D.new()
	_preview_line.width = StrokePhysicsBuilder.LINE_RADIUS * 2.0
	_preview_line.default_color = Color("#38bdf8", 0.9)
	_preview_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_preview_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_preview_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_preview_line.antialiased = true
	add_child(_preview_line)

func _process(delta: float) -> void:
	var needs_redraw := false
	if (show_tutorial_guide or show_hint_guide) and drawing_enabled and not _is_drawing:
		_anim_time += delta
		needs_redraw = true
	if _warning_timer > 0.0:
		_warning_timer = maxf(0.0, _warning_timer - delta)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()

func reset_stroke() -> void:
	_is_drawing = false
	_points = PackedVector2Array()
	_current_length = 0.0
	if _preview_outline != null:
		_preview_outline.points = PackedVector2Array()
	if _preview_line != null:
		_preview_line.points = PackedVector2Array()
		_preview_line.default_color = Color("#38bdf8", 0.9)
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
		_warning_pos = pos
		_warning_timer = 0.5
		queue_redraw()
		stroke_rejected.emit(reason)
		return
	_is_drawing = true
	show_tutorial_guide = false
	_points = PackedVector2Array([pos])
	_current_length = 0.0
	_update_preview_visuals()
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
		_warning_pos = pos
		_warning_timer = 0.25
		return
	if _current_length + dist > max_stroke_length:
		var remaining := max_stroke_length - _current_length
		if remaining >= 2.0:
			var clamped_pos := last + (pos - last).normalized() * remaining
			if is_segment_valid(last, clamped_pos):
				_points.append(clamped_pos)
				_current_length = max_stroke_length
				_update_preview_visuals()
				stroke_updated.emit(_current_length, max_stroke_length)
		return
	_points.append(pos)
	_current_length += dist
	_update_preview_visuals()
	stroke_updated.emit(_current_length, max_stroke_length)

func _update_preview_visuals() -> void:
	if _preview_outline != null:
		_preview_outline.points = _points
	if _preview_line != null:
		_preview_line.points = _points
		var ratio := 1.0 - (_current_length / maxf(1.0, max_stroke_length))
		if ratio < 0.2:
			_preview_line.default_color = Color("#f97316", 0.95)
		else:
			_preview_line.default_color = Color("#38bdf8", 0.9)

func _end_stroke() -> void:
	_is_drawing = false
	queue_redraw()
	if _current_length < MIN_STROKE_LENGTH or _points.size() < 2:
		reset_stroke()
		stroke_rejected.emit("too_short")
		return
	var final_points := _points.duplicate()
	var final_len := _current_length
	_preview_outline.points = PackedVector2Array()
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
		draw_rect(rect, Color("#94a3b8", 0.35), false, 2.0)
	for rect in forbidden_rects:
		draw_rect(rect, Color("#ef4444", 0.16), true)
		draw_rect(rect, Color("#ef4444", 0.65), false, 2.5)
	if _is_drawing:
		for r_pos in robot_positions:
			draw_arc(r_pos, robot_exclusion_radius, 0.0, TAU, 28, Color("#ef4444", 0.55), 2.5)
	
	var guide: PackedVector2Array = PackedVector2Array()
	if show_hint_guide and hint_guide_points.size() >= 2:
		guide = hint_guide_points
	elif show_tutorial_guide and tutorial_guide_points.size() >= 2:
		guide = tutorial_guide_points
	if guide.size() >= 2 and not _is_drawing:
		for i in range(guide.size() - 1):
			draw_dashed_line(guide[i], guide[i + 1], Color("#0284c7", 0.55), 6.0, 12.0)
		var total_segs: int = guide.size() - 1
		var t: float = fmod(_anim_time * 0.75, 1.0)
		var fidx: float = t * float(total_segs)
		var seg_idx: int = mini(int(fidx), total_segs - 1)
		var local_t: float = fidx - float(seg_idx)
		var hand_pos: Vector2 = guide[seg_idx].lerp(guide[seg_idx + 1], local_t)
		draw_circle(hand_pos, 14.0, Color("#0284c7", 0.25))
		draw_circle(hand_pos, 7.0, Color("#0ea5e9", 0.9))
	
	if _warning_timer > 0.0:
		var alpha: float = clampf(_warning_timer * 2.0, 0.0, 1.0)
		draw_circle(_warning_pos, 18.0 * (1.2 - alpha * 0.2), Color("#ef4444", alpha * 0.35))
		draw_arc(_warning_pos, 18.0, 0.0, TAU, 24, Color("#ef4444", alpha), 3.0)
