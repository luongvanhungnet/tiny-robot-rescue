extends RefCounted


const MAX_PLAYERS: = 8
const Daily = preload("res://game/daily_puzzle.gd")
const Session = preload("res://game/run_session.gd")
const Journey = preload("res://game/journey.gd")
var players: Array = []
var settings: = {"sound": true, "vibration": false, "reduced_motion": false, "clear_symbols": false, "move_goals": false, "playtest_feedback": false}
var active_id: = "p1"
var _next_id: = 2

func _init() -> void :
	players = [_new_player("p1", "Player 1")]

func _new_player(id: String, player_name: String) -> Dictionary:
	return {"id": id, "name": player_name, "progress": {"parcel": [], "block": [], "last_parcel": 0, "last_block": 0}, "results": {"parcel": {}, "block": {}}, "daily_results": {}, "sessions": {}, "tutorials": {"parcel": false, "block": false}, "journey": {"daily_dates": [], "avatar": ""}}

func select_avatar(sticker_id: String) -> bool:
	if not sticker_id.is_empty() and not Journey.unlocked(current(), sticker_id):
		return false
	current().journey.avatar = sticker_id
	return true

func current() -> Dictionary:
	for player in players:
		if player.id == active_id:
			return player
	return players[0]

func add_player(player_name: String) -> String:
	player_name = clean_name(player_name)
	if player_name.is_empty() or players.size() >= MAX_PLAYERS:
		return ""
	for player in players:
		if player.name.nocasecmp_to(player_name) == 0:
			return ""
	var id: = "p%d" % _next_id
	_next_id += 1
	players.append(_new_player(id, player_name))
	active_id = id
	return id

func select_player(id: String) -> bool:
	for player in players:
		if player.id == id:
			active_id = id
			return true
	return false

func rename_current(player_name: String) -> bool:
	player_name = clean_name(player_name)
	if player_name.is_empty():
		return false
	for player in players:
		if player.id != active_id and player.name.nocasecmp_to(player_name) == 0:
			return false
	current().name = player_name
	return true

static func clean_name(value: String) -> String:
	var cleaned: = ""
	for character in value.strip_edges():
		if character.unicode_at(0) >= 32:
			cleaned += character
	return cleaned.left(18).strip_edges()

static func score_for(milliseconds: int, moves: int, undos: int) -> int:
	if milliseconds < 0 or moves < 1 or undos < 0:
		return 0
	var speed: = maxi(0, 2000 - int(milliseconds / 100))
	var efficiency: = maxi(0, 3000 - moves * 40 - undos * 120)
	return 1000 + speed + efficiency

func best(game_mode: String, level: int) -> Dictionary:
	return current().results[game_mode].get(str(level), {})

func record(game_mode: String, level: int, milliseconds: int, moves: int, undos: int) -> Dictionary:
	if not game_mode in ["parcel", "block"] or level < 0 or moves < 1 or milliseconds < 0 or undos < 0:
		return {}
	milliseconds = maxi(1, milliseconds)
	var previous: = best(game_mode, level)
	var summary: = _merge_record(previous, milliseconds, moves, undos)
	current().results[game_mode][str(level)] = summary.best
	return summary

func best_daily(day: String, game_mode: String) -> Dictionary:
	return current().daily_results.get(day, {}).get(game_mode, {})

func record_daily(day: String, game_mode: String, milliseconds: int, moves: int, undos: int) -> Dictionary:
	if not Daily.valid_date(day) or not game_mode in ["parcel", "block"] or milliseconds < 0 or moves < 1 or undos < 0:
		return {}
	var summary: = _merge_record(best_daily(day, game_mode), maxi(1, milliseconds), moves, undos)
	var days: Dictionary = current().daily_results
	if not days.has(day):
		days[day] = {}
	days[day][game_mode] = summary.best
	Journey.credit_daily(current(), day)
	var dates: = days.keys()
	dates.sort()
	while dates.size() > 90:
		days.erase(dates.pop_front())
	return summary

func _merge_record(previous: Dictionary, milliseconds: int, moves: int, undos: int) -> Dictionary:
	var score: = score_for(milliseconds, moves, undos)
	var is_high: bool = previous.is_empty() or score > int(previous.high_score)
	var result: = {"high_score": score, "best_time_ms": milliseconds, "fewest_moves": moves, "solves": 1}
	if not previous.is_empty():
		result.high_score = maxi(score, int(previous.high_score))
		result.best_time_ms = mini(milliseconds, int(previous.best_time_ms))
		result.fewest_moves = mini(moves, int(previous.fewest_moves))
		result.solves = int(previous.solves) + 1
	return {"score": score, "new_high": is_high, "best": result.duplicate()}

func ranking(game_mode: String = "all") -> Array:
	var rows: Array = []
	for player in players:
		var row: = {"id": player.id, "name": player.name, "avatar": player.journey.avatar, "score": 0, "completed": 0, "time_ms": 0}
		for key in ["parcel", "block"]:
			if game_mode != "all" and game_mode != key:
				continue
			for result in player.results[key].values():
				row.score += int(result.high_score)
				row.completed += 1
				row.time_ms += int(result.best_time_ms)
		rows.append(row)
	rows.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score:
			return a.score > b.score
		if a.completed != b.completed:
			return a.completed > b.completed
		if a.time_ms != b.time_ms:
			return a.time_ms < b.time_ms
		return a.name.nocasecmp_to(b.name) < 0)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
		if i > 0 and rows[i].score == rows[i - 1].score and rows[i].completed == rows[i - 1].completed and rows[i].time_ms == rows[i - 1].time_ms:
			rows[i].rank = rows[i - 1].rank
	return rows

func to_data() -> Dictionary:
	return {"version": 4, "settings": settings.duplicate(), "active_player": active_id, "next_player_id": _next_id, "players": players.duplicate(true)}

func restore(saved: Dictionary, counts: Dictionary) -> void :
	players = []
	active_id = "p1"
	_next_id = 2
	settings = {"sound": true, "vibration": false, "reduced_motion": false, "clear_symbols": false, "move_goals": false, "playtest_feedback": false}
	if saved.get("settings") is Dictionary:
		for key in settings:
			if saved.settings.get(key) is bool:
				settings[key] = saved.settings[key]
	if not saved.get("players") is Array:
		var legacy: = _new_player("p1", "Player 1")
		legacy.progress = _read_progress(saved, counts)
		Journey.sync(legacy)
		players.append(legacy)
		return
	var ids: = {}
	var names: = {}
	for item in saved.players:
		if players.size() >= MAX_PLAYERS:
			break
		if not item is Dictionary or not item.get("name") is String or not item.get("id") is String:
			continue
		var player_name: = clean_name(item.name)
		var id: String = item.id
		if player_name.is_empty() or not id.begins_with("p") or not id.substr(1).is_valid_int() or ids.has(id) or names.has(player_name.to_lower()):
			continue
		var number: = _integer(int(id.substr(1)), 1, 1000000)
		if number < 1:
			continue
		_next_id = maxi(_next_id, number + 1)
		ids[id] = true
		names[player_name.to_lower()] = true
		var player: = _new_player(id, player_name)
		player.progress = _read_progress(item.get("progress", {}), counts)
		_read_extras(item, player)
		var results: Variant = item.get("results", {})
		if results is Dictionary:
			for game_mode in ["parcel", "block"]:
				var mode_results: Variant = results.get(game_mode, {})
				if not mode_results is Dictionary:
					continue
				for key in mode_results:
					if not key is String or not key.is_valid_int() or int(key) < 0 or int(key) >= int(counts[game_mode]):
						continue
					var entry: Variant = mode_results[key]
					if not entry is Dictionary:
						continue
					var high: = _integer(entry.get("high_score"), 1000, 6000)
					var time: = _integer(entry.get("best_time_ms"), 1, 604800000)
					var moves: = _integer(entry.get("fewest_moves"), 1, 1000000)
					var solves: = _integer(entry.get("solves"), 1, 1000000)
					if high < 0 or time < 0 or moves < 0 or solves < 0:
						continue
					player.results[game_mode][str(int(key))] = {"high_score": high, "best_time_ms": time, "fewest_moves": moves, "solves": solves}
		Journey.sync(player)
		players.append(player)
	if players.is_empty():
		players.append(_new_player("p1", "Player 1"))
	active_id = str(saved.get("active_player", "p1"))
	if not select_player(active_id):
		active_id = players[0].id

func _read_extras(item: Dictionary, player: Dictionary) -> void :
	if item.get("journey") is Dictionary:
		player.journey = item.journey.duplicate(true)
	var tutorials: Variant = item.get("tutorials", {})
	for game_mode in ["parcel", "block"]:
		player.tutorials[game_mode] = tutorials.get(game_mode, not player.progress[game_mode].is_empty()) if tutorials is Dictionary else not player.progress[game_mode].is_empty()
		if not player.tutorials[game_mode] is bool:
			player.tutorials[game_mode] = false
	var sessions: Variant = item.get("sessions", {})
	if sessions is Dictionary:
		for key in ["parcel", "block", "daily_parcel", "daily_block"]:
			var session: Variant = sessions.get(key)
			if session is Dictionary and session.get("actions") is Array and session.actions.size() <= Session.MAX_ACTIONS and session.get("kind") in ["normal", "daily"] and session.get("mode") in ["parcel", "block"] and key == Session.key(session.kind, session.mode):
				player.sessions[key] = session.duplicate(true)
	var days: Variant = item.get("daily_results", {})
	if not days is Dictionary:
		return
	var dates: Array = []
	for day in days:
		if day is String and Daily.valid_date(day) and days[day] is Dictionary:
			dates.append(day)
	dates.sort()
	for day in dates.slice(maxi(0, dates.size() - 90)):
		var results: = {}
		for game_mode in ["parcel", "block"]:
			var entry: Variant = days[day].get(game_mode)
			if not entry is Dictionary:
				continue
			var score: = _integer(entry.get("high_score"), 1000, 6000)
			var time: = _integer(entry.get("best_time_ms"), 1, 604800000)
			var moves: = _integer(entry.get("fewest_moves"), 1, 1000000)
			var solves: = _integer(entry.get("solves"), 1, 1000000)
			if score >= 0 and time >= 0 and moves >= 0 and solves >= 0:
				results[game_mode] = {"high_score": score, "best_time_ms": time, "fewest_moves": moves, "solves": solves}
		if not results.is_empty():
			player.daily_results[day] = results

func _read_progress(value: Variant, counts: Dictionary) -> Dictionary:
	var result: Dictionary = _new_player("", "").progress
	if not value is Dictionary:
		return result
	for game_mode in ["parcel", "block"]:
		if value.get(game_mode) is Array:
			for level in value[game_mode]:
				var number: = _integer(level, 0, int(counts[game_mode]) - 1)
				if number >= 0 and not result[game_mode].has(number):
					result[game_mode].append(number)
		var last: = _integer(value.get("last_" + game_mode), 0, int(counts[game_mode]) - 1)
		if last >= 0:
			result["last_" + game_mode] = last
	return result

func _integer(value: Variant, minimum: int, maximum: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)):
		return -1
	if value < minimum or value > maximum:
		return -1
	return int(value)
