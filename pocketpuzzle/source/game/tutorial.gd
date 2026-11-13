extends RefCounted
const PARCEL_PATH: = [1, 0, 0, 1, 2, 2]
const PARCEL_TEXT: = ["Tap the glowing middle queue. This parcel matches!", "Tap left. This blue parcel will wait in a little spot.", "Tap left again. Watch the waiting parcel deliver too!", "Now send the blue parcel in the middle queue.", "Send the mint parcel on the right.", "One more parcel on the right. You've got this!"]

static func level_for(game_mode: String) -> int:
	return 1 if game_mode == "parcel" else 0

static func message(game_mode: String, step: int, solution: Array) -> String:
	if game_mode == "parcel":
		return PARCEL_TEXT[mini(step, PARCEL_TEXT.size() - 1)]
	return "Tap the glowing pink pal, then move down." if step < 2 else "Move right toward the pink circle gate. Keep going!"

static func expected(game_mode: String, step: int, solution: Array) -> Array:
	if game_mode == "parcel":
		return [PARCEL_PATH[mini(step, PARCEL_PATH.size() - 1)]]
	return solution[mini(step, solution.size() - 1)]
