extends RefCounted
const Journey = preload("res://game/journey.gd")
const Hint = preload("res://game/puzzle_hint.gd")

static func difficulty(mode: String, level: Dictionary) -> String:

	if mode == "parcel":
		var length: int = level.route.size()
		return "Gentle" if length <= 9 else "Tricky" if length <= 18 else "Challenging"
	var pieces: int = level.pieces.size()
	var steps: int = level.solution.size()
	return "Gentle" if pieces <= 2 and steps <= 16 else "Tricky" if pieces <= 5 and steps <= 38 else "Challenging"

static func reference_goal(mode: String, level: Dictionary) -> int:
	return level.solution.size() if not Hint.verified_route(mode, level).is_empty() else 0

static func next_unfinished(player: Dictionary, mode: String, count: = 150) -> int:
	var completed: = Journey.completed(player, mode)
	for number in range(count):
		if not completed.has(number):
			return number
	return -1
