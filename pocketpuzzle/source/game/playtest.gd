extends RefCounted

const Daily = preload("res://game/daily_puzzle.gd")
const Session = preload("res://game/run_session.gd")
const Progress = preload("res://game/puzzle_progress.gd")
const MAX_REPORTS: = 200
const RATINGS: = {"easy": "Too easy", "hard": "Too hard", "confusing": "Confusing", "right": "Feels right"}
var entries: Array = []

static func clean_note(value: String) -> String:
	var text: = ""
	for character in value:
		if character == "\n" or character.unicode_at(0) >= 32:
			text += character
	return text.strip_edges().left(240)

func submit(mode: String, number: int, catalogue: Dictionary, kind: String, day: String, rating: String, note: String) -> bool:
	if not mode in ["parcel", "block"] or number < 0 or number >= catalogue[mode].size() or not RATINGS.has(rating) or not kind in ["normal", "daily"] or (kind == "daily" and not Daily.valid_date(day)):
		return false
	var entry: = {"mode": mode, "level": number, "seed": int(catalogue[mode][number].seed), "kind": kind, "day": day if kind == "daily" else "", "rating": rating, "note": clean_note(note), "difficulty_estimate": Progress.difficulty(mode, catalogue[mode][number]), "game_version": "0.9.0"}

	entries = entries.filter( func(previous): return not (previous.mode == mode and previous.level == number and previous.kind == kind and previous.day == entry.day))
	entries.append(entry)
	while entries.size() > MAX_REPORTS:
		entries.pop_front()
	return true

func to_data() -> Dictionary:
	return {"format": "PocketPuzzlePlaytest", "version": 1, "game_version": "0.9.0", "entries": entries.duplicate(true)}

func restore(data: Dictionary, catalogue: Dictionary) -> void :
	entries = []
	if data.get("format") != "PocketPuzzlePlaytest" or data.get("version") != 1 or not data.get("entries") is Array:
		return
	for entry in data.entries.slice(maxi(0, data.entries.size() - MAX_REPORTS)):
		if not entry is Dictionary or not entry.get("mode") in ["parcel", "block"] or not entry.get("level") is float and not entry.get("level") is int:
			continue
		var number: = Session.integer(entry.level, 0, catalogue[entry.mode].size() - 1)
		if number < 0 or entry.get("seed") != catalogue[entry.mode][number].seed or not entry.get("note") is String or not entry.get("rating") is String or not entry.get("kind") is String or not entry.get("day") is String:
			continue
		submit(entry.mode, number, catalogue, entry.kind, entry.day, entry.rating, entry.note)

func summary() -> Dictionary:
	var counts: = {"easy": 0, "hard": 0, "confusing": 0, "right": 0}
	for entry in entries:
		counts[entry.rating] += 1
	return counts
