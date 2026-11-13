extends RefCounted



var size: int = 5
var pieces: Array = []
var gates: Array = []
var history: Array = []
var moves: int = 0

func setup(level: Dictionary) -> void :
	size = int(level.size)
	pieces = level.pieces.duplicate(true)
	for piece in pieces:
		piece["out"] = false
	gates = level.gates.duplicate(true)
	moves = 0
	history.clear()

func piece_at(cell: Vector2i) -> int:
	for i in range(pieces.size()):
		var piece: Dictionary = pieces[i]
		if not piece.out and Rect2i(int(piece.x), int(piece.y), int(piece.w), int(piece.h)).has_point(cell):
			return i
	return -1

func can_move(index: int, direction: Vector2i) -> bool:
	if index < 0 or index >= pieces.size() or pieces[index].out or absi(direction.x) + absi(direction.y) != 1:
		return false
	var piece: Dictionary = pieces[index]
	var next: = Rect2i(int(piece.x) + direction.x, int(piece.y) + direction.y, int(piece.w), int(piece.h))
	if next.position.x < 0 or next.position.y < 0 or next.end.x > size or next.end.y > size:
		var gate: Dictionary = gates[int(piece.color)]
		var vertical: bool = gate.side == "up" or gate.side == "down"
		var across: int = int(piece.x) if vertical else int(piece.y)
		var breadth: int = int(piece.w) if vertical else int(piece.h)
		if across < int(gate.start) or across + breadth > int(gate.start) + int(gate.span):
			return false
		return (gate.side == "right" and direction == Vector2i.RIGHT and next.end.x > size
			or gate.side == "left" and direction == Vector2i.LEFT and next.position.x < 0
			or gate.side == "down" and direction == Vector2i.DOWN and next.end.y > size
			or gate.side == "up" and direction == Vector2i.UP and next.position.y < 0)
	for other_index in range(pieces.size()):
		var other: Dictionary = pieces[other_index]
		if other_index != index and not other.out and next.intersects(Rect2i(int(other.x), int(other.y), int(other.w), int(other.h))):
			return false
	return true

func move_piece(index: int, direction: Vector2i) -> bool:
	if not can_move(index, direction):
		return false
	history.append({"pieces": pieces.duplicate(true), "moves": moves})
	var piece: Dictionary = pieces[index]
	piece.x = int(piece.x) + direction.x
	piece.y = int(piece.y) + direction.y
	piece.out = int(piece.x) < 0 or int(piece.y) < 0 or int(piece.x) + int(piece.w) > size or int(piece.y) + int(piece.h) > size
	moves += 1
	return true

func undo() -> bool:
	if history.is_empty():
		return false
	var previous: Dictionary = history.pop_back()
	pieces = previous.pieces
	moves = previous.moves
	return true

func won() -> bool:
	if pieces.is_empty():
		return false
	for piece in pieces:
		if not piece.out:
			return false
	return true

func remaining() -> int:
	var count: = 0
	for piece in pieces:
		if not piece.out:
			count += 1
	return count
