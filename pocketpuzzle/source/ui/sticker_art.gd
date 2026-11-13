extends Control

const Look = preload("res://ui/friendly_theme.gd")
const Art = preload("res://ui/playful_art.gd")
var kind: = "mail"
var variant: = 0
var locked: = false

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _pill(rect: Rect2, color: Color, radius: = 18) -> void :
	draw_style_box(Look.box(color, radius), rect)

func _triangle(points: Array, color: Color) -> void :
	draw_colored_polygon(PackedVector2Array(points), color)

func _draw() -> void :
	var scale_factor: = minf(size.x, size.y) / 150.0
	draw_set_transform(size / 2.0, 0, Vector2.ONE * scale_factor)
	var pastel: Color = Look.PASTELS[posmod(variant, 4)]
	draw_circle(Vector2(0, 4), 68, Color("ded1ed"))
	draw_circle(Vector2.ZERO, 68, Look.PAPER)
	draw_circle(Vector2.ZERO, 61, pastel.lightened(0.72) if not locked else Color("eee9f3"))
	if locked:
		draw_arc(Vector2(0, -8), 14, PI, TAU, 20, Look.MUTED, 5, true)
		_pill(Rect2(-23, -7, 46, 38), Color("cbbddc"), 10)
		draw_circle(Vector2(0, 9), 4, Look.INK)
		draw_line(Vector2(0, 11), Vector2(0, 18), Look.INK, 3, true)
		draw_set_transform(Vector2.ZERO)
		return
	var body: = pastel
	match kind:
		"frog", "turtle": body = Color("a7d7a9")
		"fox": body = Color("efb28c")
		"bear", "owl": body = Color("dcbd9c")
		"koala": body = Color("c5c9df")
		"penguin", "bat": body = Color("b6b1db")
		"duck", "chick", "bee": body = Color("f3d38b")
		"panda", "unicorn": body = Color("eee8fa")

	match kind:
		"bunny":
			for x in [-18, 18]:
				_pill(Rect2(x - 10, -57, 20, 52), body, 10)
				_pill(Rect2(x - 5, -50, 10, 34), Color("edb5c9"), 5)
		"cat", "fox", "unicorn":
			for side in [-1, 1]:
				_triangle([Vector2(side * 12, -23), Vector2(side * 36, -48), Vector2(side * 43, -10)], body)
				_triangle([Vector2(side * 22, -23), Vector2(side * 34, -37), Vector2(side * 37, -17)], Color("d996b4"))
			if kind == "unicorn":
				_triangle([Vector2(-8, -28), Vector2(0, -61), Vector2(9, -28)], Color("e4b85f"))
		"bear", "panda", "koala":
			for side in [-1, 1]:
				draw_circle(Vector2(side * 32, -23), 19, Color("72688b") if kind == "panda" else body.darkened(0.08))
				draw_circle(Vector2(side * 32, -23), 11, Color("e9cfdb"))
		"dog":
			for side in [-1, 1]:
				_pill(Rect2(side * 32 - 12, -28, 24, 57), body.darkened(0.12), 12)
		"frog":
			for side in [-1, 1]:
				draw_circle(Vector2(side * 24, -25), 19, body)
		"owl", "bird", "duck", "penguin", "chick":
			for side in [-1, 1]:
				_pill(Rect2(side * 35 - 12, 0, 24, 36), body.darkened(0.1), 12)
				_pill(Rect2(side * 18 - 9, 36, 18, 12), Color("dfac66"), 6)
		"turtle":
			for x in [-1, 1]:
				for y in [-1, 1]:
					draw_circle(Vector2(x * 32, y * 25), 15, body.darkened(0.12))
		"fish":
			_triangle([Vector2(28, 0), Vector2(58, -25), Vector2(58, 28)], body.darkened(0.12))
		"bee":
			for side in [-1, 1]:
				draw_circle(Vector2(side * 28, -30), 21, Color("d6e9fa"))
				draw_line(Vector2(side * 12, -24), Vector2(side * 20, -48), Look.INK, 3, true)
				draw_circle(Vector2(side * 20, -48), 4, Look.INK)
		"butterfly":
			for side in [-1, 1]:
				draw_circle(Vector2(side * 29, -17), 28, Look.PASTELS[0])
				draw_circle(Vector2(side * 28, 23), 24, Look.PASTELS[1])
				Art.star(self, Vector2(side * 32, -18), 10, Look.PAPER)
		"bat":
			for side in [-1, 1]:
				_triangle([Vector2(side * 15, -5), Vector2(side * 60, -31), Vector2(side * 49, 25), Vector2(side * 25, 15)], body.darkened(0.08))
				_triangle([Vector2(side * 12, -20), Vector2(side * 25, -44), Vector2(side * 33, -8)], body)
	if kind == "mail":
		_pill(Rect2(-45, -29, 90, 70), Color("d58fa7"), 16)
		_pill(Rect2(-45, -34, 90, 70), Look.PASTELS[0], 16)
		draw_polyline(PackedVector2Array([Vector2(-38, -27), Vector2(0, -4), Vector2(38, -27)]), Color("b35a78"), 3, true)
	elif kind == "medal":
		Art.star(self, Vector2.ZERO, 46, Color("f3d38b"))
	elif kind == "butterfly":
		_pill(Rect2(-14, -34, 28, 78), Color("c1aedc"), 14)
	else:
		draw_circle(Vector2(0, 3), 40, body.darkened(0.12))
		draw_circle(Vector2(0, -1), 39, body)
		if kind in ["fox", "penguin", "owl", "unicorn"]:
			draw_circle(Vector2(0, 10), 28, Color("fff4e8"))
		if kind == "panda":
			for side in [-1, 1]:
				draw_circle(Vector2(side * 10, 5), 10, Color("c2b8d4"))
		if kind == "bee":
			for side in [-1, 1]:
				_pill(Rect2(side * 24 - 4, -24, 8, 48), Color("d1a657"), 4)
		if kind == "turtle":
			draw_arc(Vector2.ZERO, 30, 0, TAU, 24, Color("4f9472"), 3, true)
	Art.face(self, Vector2(0, 12 if kind == "mail" else 7), 24)
	if kind in ["bird", "duck", "owl", "penguin", "chick"]:
		_triangle([Vector2(-7, 13), Vector2(7, 13), Vector2(0, 22)], Color("d59a46"))
	if kind == "koala":
		_pill(Rect2(-7, 1, 14, 16), Look.INK, 6)
	Art.star(self, Vector2(48, -44), 9, Color("e8ba61"))
	draw_circle(Vector2(-48, 40), 4, Color("c5afd9"))
	draw_set_transform(Vector2.ZERO)
