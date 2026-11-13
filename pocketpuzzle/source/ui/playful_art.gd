extends Control

const Look = preload("res://ui/friendly_theme.gd")
var kind: = "parcel"
var variant: = 0
var reduced_motion: = false
var _time: = 0.0

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind != "victory" or reduced_motion:
		set_process(false)
	resized.connect(queue_redraw)

func _process(delta: float) -> void :
	_time += delta
	queue_redraw()
	if _time > 1.3:
		set_process(false)

static func face(canvas: CanvasItem, center: Vector2, extent: float, happy: = false) -> void :
	var eye: = maxf(1.5, extent * 0.13)
	for side in [-1, 1]:
		var point: = center + Vector2(side * extent * 0.42, - extent * 0.12)
		if happy:
			canvas.draw_arc(point + Vector2(0, eye), eye * 1.4, PI * 1.12, PI * 1.88, 8, Look.INK, maxf(1.5, eye * 0.7), true)
		else:
			canvas.draw_circle(point, eye, Look.INK)
		canvas.draw_circle(center + Vector2(side * extent * 0.76, extent * 0.23), eye * 1.6, Color(0.93, 0.42, 0.55, 0.32))
	canvas.draw_arc(center + Vector2(0, extent * 0.15), extent * 0.24, 0.15, PI - 0.15, 10, Look.INK, maxf(1.6, extent * 0.09), true)

static func star(canvas: CanvasItem, center: Vector2, extent: float, color: Color) -> void :
	var points: = PackedVector2Array()
	for i in range(10):
		var angle: = - PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * extent * (1.0 if i % 2 == 0 else 0.46))
	canvas.draw_colored_polygon(points, color)

func _box(rect: Rect2, color: Color, radius: = 22) -> void :
	draw_style_box(Look.box(color, radius), rect)

func _parcel(center: Vector2, extent: float, happy: = false) -> void :
	var rect: = Rect2(center - Vector2(extent, extent * 0.8), Vector2(extent * 2, extent * 1.6))
	_box(Rect2(rect.position + Vector2(0, extent * 0.1), rect.size), Color("d5849c"), int(extent * 0.28))
	_box(rect, Look.PASTELS[0], int(extent * 0.28))
	draw_rect(Rect2(center.x - extent * 0.16, rect.position.y, extent * 0.32, extent * 0.52), Color("ffe5c3"))
	draw_line(Vector2(rect.position.x + extent * 0.18, rect.position.y + 6), Vector2(rect.end.x - extent * 0.18, rect.position.y + 6), Color(1, 1, 1, 0.35), 4, true)
	face(self, center + Vector2(0, extent * 0.12), extent * 0.67, happy)

func _block(center: Vector2, extent: float, color: Color, happy: = false) -> void :
	var rect: = Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2)
	_box(Rect2(rect.position + Vector2(0, extent * 0.1), rect.size), color.darkened(0.12), int(extent * 0.4))
	_box(rect, color, int(extent * 0.4))
	face(self, center + Vector2(0, extent * 0.14), extent * 0.66, happy)
	draw_arc(center + Vector2( - extent * 0.44, - extent * 0.48), extent * 0.14, PI * 0.9, PI * 1.7, 8, Color(1, 1, 1, 0.65), 4, true)

func _draw() -> void :
	var center: = size / 2.0
	var scale_factor: = minf(size.x / 180.0, size.y / 150.0)
	match kind:
		"trail":
			for i in range(5):
				draw_circle(Vector2(size.x * 0.5 + (i - 2) * 9, size.y * 0.5), 3, Color("c5afd9"))
		"background":
			draw_circle(Vector2(size.x + 15, 70), 155, Color("eee5fb"))
			draw_circle(Vector2(-65, size.y * 0.7), 150, Color("fff0ed"))
			for i in range(8):
				var point: = Vector2(10 if i % 2 == 0 else size.x - 10, 150 + i * 171)
				draw_circle(point, 3, Color("dbcce9"))
		"mark":
			star(self, center, minf(size.x, size.y) * 0.44, Color("f3d38b"))
			face(self, center, 9)
		"parcel", "welcome":
			draw_circle(center, 65 * scale_factor, Color("ffe6e9"))
			_parcel(center, 48 * scale_factor)
			star(self, center + Vector2(62, -42) * scale_factor, 12 * scale_factor, Color("e8ba61"))
			star(self, center + Vector2(-64, 29) * scale_factor, 8 * scale_factor, Color("c3abd9"))
		"block":
			draw_circle(center, 65 * scale_factor, Color("dbf0e6"))
			_block(center + Vector2(-25, 13) * scale_factor, 36 * scale_factor, Look.PASTELS[2])
			_block(center + Vector2(34, -17) * scale_factor, 29 * scale_factor, Look.PASTELS[1], true)
			star(self, center + Vector2(-43, -49) * scale_factor, 10 * scale_factor, Color("e8ba61"))
		"victory":
			var bounce: = sin(minf(_time / 1.3, 1.0) * TAU * 2) * 5 * maxf(0, 1 - _time / 1.3)
			center.y += bounce
			draw_ellipse_shadow(center + Vector2(0, 63 * scale_factor), 110 * scale_factor)
			_parcel(center + Vector2(-45, 2) * scale_factor, 41 * scale_factor, true)
			_block(center + Vector2(48, 10) * scale_factor, 37 * scale_factor, Look.PASTELS[2], true)
			for i in range(7):
				var angle: = PI * (1.1 + i * 0.13)
				var point: = center + Vector2(cos(angle) * 140, sin(angle) * 65 - 7) * scale_factor
				star(self, point, (9 + i % 3 * 3) * scale_factor, Look.PASTELS[i % 4])
		"avatar":
			draw_circle(center, minf(size.x, size.y) * 0.48, Look.PASTELS[posmod(variant, 4)].lightened(0.5))
			_block(center, minf(size.x, size.y) * 0.32, Look.PASTELS[posmod(variant, 4)], variant == 0)

func draw_ellipse_shadow(center: Vector2, extent: float) -> void :
	draw_set_transform(center, 0, Vector2(1, 0.1))
	draw_circle(Vector2.ZERO, extent, Color(0.47, 0.33, 0.64, 0.1))
	draw_set_transform(Vector2.ZERO)
