extends RefCounted


const Parcel = preload("res://game/parcel_rules.gd")
const Block = preload("res://game/block_rules.gd")
const Daily = preload("res://game/daily_puzzle.gd")
const MAX_ACTIONS: = 2000

static func key(kind: String, game_mode: String) -> String:
	return ("daily_" if kind == "daily" else "") + game_mode

static func snapshot(game_mode: String, level: int, kind: String, day: String, seed_value: int, actions: Array, milliseconds: int, moves: int, undos: int, selected: int) -> Dictionary:
	return {"version": 1, "mode": game_mode, "level": level, "kind": kind, "day": day, "seed": seed_value, "actions": actions.duplicate(true), "elapsed_ms": milliseconds, "moves": moves, "undos": undos, "selected": selected}

static func integer(value: Variant, low: int, high: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)):
		return low - 1
	return int(value) if value >= low and value <= high else low - 1

static func restore(data: Variant, catalogue: Dictionary) -> Dictionary:
	if not data is Dictionary or data.get("version") != 1 or not data.get("mode") in ["parcel", "block"] or not data.get("kind") in ["normal", "daily"]:
		return {}
	var game_mode: String = data.mode
	var level: = integer(data.get("level"), 0, catalogue[game_mode].size() - 1)
	var milliseconds: = integer(data.get("elapsed_ms"), 0, 604800000)
	var moves: = integer(data.get("moves"), 0, 1000000)
	var undos: = integer(data.get("undos"), 0, 1000000)
	var actions: Variant = data.get("actions")
	if level < 0 or milliseconds < 0 or moves < 0 or undos < 0 or not actions is Array or actions.size() > MAX_ACTIONS or moves != actions.size() + undos:
		return {}
	if data.get("seed") != catalogue[game_mode][level].seed:
		return {}
	if data.kind == "daily" and ( not data.get("day") is String or Daily.level_for(data.day, game_mode, catalogue[game_mode].size()) != level):
		return {}
	var game = Parcel.new() if game_mode == "parcel" else Block.new()
	game.setup(catalogue[game_mode][level])
	var normalized: Array = []
	for action in actions:
		if not action is Array or action.size() != (1 if game_mode == "parcel" else 3):
			return {}
		var index: = integer(action[0], 0, 2 if game_mode == "parcel" else game.pieces.size() - 1)
		if index < 0:
			return {}
		if game_mode == "parcel":
			if not game.send(index):
				return {}
			normalized.append([index])
		else:
			var dx: = integer(action[1], -1, 1)
			var dy: = integer(action[2], -1, 1)
			if dx < -1 or dy < -1 or not game.move_piece(index, Vector2i(dx, dy)):
				return {}
			normalized.append([index, dx, dy])
	if game.won():
		return {}
	var selected: = integer(data.get("selected", -1), -1, -1 if game_mode == "parcel" else game.pieces.size() - 1)
	if selected < -1:
		selected = -1
	return {"rules": game, "mode": game_mode, "level": level, "kind": data.kind, "day": str(data.get("day", "")), "actions": normalized, "elapsed_ms": milliseconds, "moves": moves, "undos": undos, "selected": selected}
