extends Control

signal played(index: int, direction: Vector2i)
signal selection_changed
const Look = preload("res://ui/friendly_theme.gd")
const Art = preload("res://ui/playful_art.gd")
const COLORS: = Look.PASTELS
const INK: = Look.INK
const MUTED: = Look.MUTED
const PAPER: = Look.PAPER
const LANE: = Color("f0e9f8")
var mode: = "parcel"
var rules
var selected: = -1
var guide_lane: = -1
var guide_piece: = -1
var press_position: = Vector2.ZERO
var flash: = 0.0
var reduced_motion: = false
var clear_symbols: = false
var _font: Font

func _ready() -> void :
	_font = Look.bold_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

func celebrate_move() -> void :
	if reduced_motion:
		flash = 0.0
		set_process(false)
		queue_redraw()
		return
	flash = 1.0
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void :
	flash = maxf(0.0, flash - delta * 3.0)
	queue_redraw()
	if flash <= 0.0:
		set_process(false)

func _box(rect: Rect2, color: Color, radius: int = 18, border: = Color.TRANSPARENT) -> void :
	var style: = Look.box(color, radius, border)
	if border == Look.PURPLE:
		style.set_border_width_all(3)
	draw_style_box(style, rect)

func _text(value: String, point: Vector2, font_size: int, color: Color = INK, centered: = false) -> void :
	if centered:
		point.x -= _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string(_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _symbol(center: Vector2, index: int, extent: float, tint: = Color.WHITE) -> void :
	if clear_symbols:
		var radius: = maxf(10, extent + 2)
		draw_circle(center, radius, PAPER)
		draw_arc(center, radius, 0, TAU, 24, INK, 1.5, true)
		var font_size: = int(radius * 1.65)
		_text(str(index + 1), center + Vector2(0, font_size * 0.34), font_size, INK, true)
		return
	match index:
		0:
			draw_circle(center, extent * 0.63, tint)
		1:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, - extent), center + Vector2(extent, extent * 0.7), center + Vector2( - extent, extent * 0.7)]), tint)
		2:
			draw_rect(Rect2(center - Vector2.ONE * extent * 0.65, Vector2.ONE * extent * 1.3), tint)
		3:
			draw_line(center - Vector2(extent, 0), center + Vector2(extent, 0), tint, extent * 0.45, true)
			draw_line(center - Vector2(0, extent), center + Vector2(0, extent), tint, extent * 0.45, true)

func _parcel(rect: Rect2, index: int, active: = false) -> void :
	if active:
		rect.position.y -= sin(flash * PI) * 3.0
	_box(Rect2(rect.position + Vector2(0, 4), rect.size), COLORS[index].darkened(0.12), 11)
	_box(rect, COLORS[index].lightened(flash * 0.1 if active else 0.0), 11)
	draw_rect(Rect2(rect.get_center().x - 5, rect.position.y, 10, rect.size.y * 0.29), Color(1, 0.96, 0.86, 0.7))
	var symbol_size: = minf(rect.size.y * 0.24, 11.0)
	var badge: = Vector2(rect.position.x + symbol_size + 8, rect.get_center().y)
	draw_circle(badge, symbol_size + 3, Color(1, 1, 1, 0.7))
	_symbol(badge, index, symbol_size * 0.72, Look.MARKS[index])
	Art.face(self, rect.get_center() + Vector2(rect.size.x * 0.17, 0), minf(rect.size.y * 0.31, 12.0), active and flash > 0.5)

func _grid_rect() -> Rect2:
	var side: = minf(size.x - 48.0, size.y - 60.0)
	return Rect2(Vector2((size.x - side) / 2.0, 30.0), Vector2.ONE * side)

func _draw() -> void :
	if rules == null:
		return
	if _font == null:
		_font = Look.bold_font()
	if mode == "parcel":
		_draw_parcel()
	else:
		_draw_block()

func _draw_parcel() -> void :
	var width: = size.x
	_box(Rect2(0, 4, width, 112), Color("e9deef"), 24)
	_box(Rect2(0, 0, width, 112), PAPER, 24)
	_text("Next happy deliveries", Vector2(22, 28), 18, MUTED)
	if not rules.won():
		_parcel(Rect2(22, 43, 78, 48), int(rules.route[rules.delivered]), true)
		_text("Send me!", Vector2(61, 106), 13, MUTED, true)
		var upcoming: int = mini(rules.route.size() - rules.delivered - 1, 8)
		for i in range(upcoming):
			var index: int = int(rules.route[rules.delivered + i + 1])
			var point: = Vector2(135.0 + i * (width - 165.0) / 8.0, 70.0)
			draw_circle(point, 19, COLORS[index].lightened(0.82))
			_symbol(point, index, 10, Look.MARKS[index])
		var extra: int = rules.route.size() - rules.delivered - 1 - upcoming
		if extra > 0:
			_text("+%d" % extra, Vector2(width - 36, 106), 16, MUTED, true)
	_text("Little waiting spots", Vector2(18, 151), 18, MUTED)
	_text("%d / %d" % [rules.waiting.size(), rules.capacity], Vector2(width - 65, 151), 18, MUTED)
	var slot_width: = (width - 48.0) / 3.0
	for i in range(rules.capacity):
		var slot: = Rect2(12 + i * (slot_width + 12), 169, slot_width, 68)
		_box(slot, LANE, 20, Color("ddd0ec"))
		if i < rules.waiting.size():
			_parcel(slot.grow(-7), int(rules.waiting[i]))
		else:
			for dot in range(3):
				draw_circle(slot.get_center() + Vector2((dot - 1) * 13, 0), 3, Color("c8b7da"))
	_text("Tap a queue to send its top parcel", Vector2(width / 2.0, 277), 18, MUTED, true)
	var lane_width: = (width - 32.0) / 3.0
	for lane in range(3):
		var rect: = Rect2(lane * (lane_width + 16), 296, lane_width, size.y - 300)
		_box(rect, [Color("fbecef"), Color("edf2fc"), Color("eaf5ee")][lane], 24, Look.PURPLE if lane == guide_lane else Color("e4dcec"))
		if lane == guide_lane:
			Art.star(self, rect.position + Vector2(rect.size.x - 14, -10), 10, Look.PURPLE)
		var queue: Array = rules.queues[lane]
		var gap: = minf(44.0, (rect.size.y - 52.0) / maxf(1.0, queue.size()))
		if queue.is_empty():
			Art.face(self, Vector2(rect.get_center().x, rect.position.y + 60), 22, true)
			_text("All sent!", Vector2(rect.get_center().x, rect.position.y + 108), 19, MUTED, true)
		for i in range(queue.size()):
			_parcel(Rect2(rect.position.x + 13, rect.position.y + 13 + i * gap, lane_width - 26, gap - 7), int(queue[i]), i == 0)
		_text("%d to go" % queue.size(), Vector2(rect.get_center().x, rect.end.y - 12), 17, MUTED, true)

func _draw_block() -> void :
	var grid: = _grid_rect()
	var cell: float = grid.size.x / rules.size
	_box(Rect2(grid.grow(17).position + Vector2(0, 6), grid.grow(17).size), Color("d9cbe8"), 30)
	_box(grid.grow(16), Color("eae0f4"), 30)
	_box(grid, Color("f6f0fb"), 22)
	for x in range(rules.size):
		for y in range(rules.size):
			_box(Rect2(grid.position + Vector2(x, y) * cell + Vector2.ONE * 5, Vector2.ONE * (cell - 10)), Color(1, 1, 1, 0.72), 14)
	for i in range(rules.gates.size()):
		var gate: Dictionary = rules.gates[i]
		var gate_rect: Rect2
		var arrow: = Vector2.ZERO
		match gate.side:
			"right":
				gate_rect = Rect2(grid.end.x - 5, grid.position.y + gate.start * cell, 22, gate.span * cell)
				arrow = Vector2.RIGHT
			"left":
				gate_rect = Rect2(grid.position.x - 17, grid.position.y + gate.start * cell, 22, gate.span * cell)
				arrow = Vector2.LEFT
			"down":
				gate_rect = Rect2(grid.position.x + gate.start * cell, grid.end.y - 5, gate.span * cell, 22)
				arrow = Vector2.DOWN
			"up":
				gate_rect = Rect2(grid.position.x + gate.start * cell, grid.position.y - 17, gate.span * cell, 22)
				arrow = Vector2.UP
		_box(gate_rect, COLORS[i], 8)
		var center: = gate_rect.get_center()
		var along: = Vector2.DOWN if gate.side == "right" or gate.side == "left" else Vector2.RIGHT
		_symbol(center - along * 22, i, 7, Look.MARKS[i])
		center += along * 18
		draw_polyline(PackedVector2Array([center - arrow * 5 + arrow.orthogonal() * 5, center + arrow * 3, center - arrow * 5 - arrow.orthogonal() * 5]), Look.MARKS[i], 3, true)
	for i in range(rules.pieces.size()):
		var piece: Dictionary = rules.pieces[i]
		if piece.out:
			continue
		var rect: = Rect2(grid.position + Vector2(piece.x, piece.y) * cell + Vector2.ONE * 6, Vector2(piece.w, piece.h) * cell - Vector2.ONE * 12)
		_box(Rect2(rect.position + Vector2(0, 6), rect.size), COLORS[int(piece.color)].darkened(0.12), 22)
		_box(rect, COLORS[int(piece.color)].lightened(flash * 0.12 if selected == i else 0), 22, Look.PURPLE if selected == i or guide_piece == i else Color.TRANSPARENT)
		var badge: = Vector2(rect.get_center().x, rect.position.y + 21)
		draw_circle(badge, 13, Color(1, 1, 1, 0.66))
		_symbol(badge, int(piece.color), 8, Look.MARKS[int(piece.color)])
		Art.face(self, rect.get_center() + Vector2(0, 13), minf(rect.size.x * 0.25, 23.0), selected == i and flash > 0.5)
		if selected == i:
			draw_circle(rect.position + Vector2(14, 14), 4, PAPER)

func _gui_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_position = event.position
			if mode == "block":
				var grid: = _grid_rect()
				if grid.has_point(press_position):
					var cell: float = grid.size.x / rules.size
					selected = rules.piece_at(Vector2i((press_position - grid.position) / cell))
					queue_redraw()
					selection_changed.emit()
		else:
			if mode == "parcel" and event.position.y >= 296:
				var lane_width: = (size.x - 32.0) / 3.0
				var lane: = int(event.position.x / (lane_width + 16))
				if lane >= 0 and lane < 3 and event.position.x - lane * (lane_width + 16) <= lane_width:
					played.emit(lane, Vector2i.ZERO)
			elif mode == "block" and selected >= 0:
				var swipe: Vector2 = event.position - press_position
				if swipe.length() > 24:
					var direction: = Vector2i(signf(swipe.x), 0) if absf(swipe.x) > absf(swipe.y) else Vector2i(0, signf(swipe.y))
					played.emit(selected, direction)
		accept_event()
