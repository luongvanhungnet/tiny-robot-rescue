extends RefCounted
const Records = preload("res://game/player_records.gd")
const Session = preload("res://game/run_session.gd")
const Journey = preload("res://game/journey.gd")
const Store = preload("res://game/save_store.gd")
const MAX_BYTES: = 8388608

static func document(data: Dictionary) -> Dictionary:
	var payload: = JSON.stringify(data)
	return {"format": "PocketPuzzleBackup", "version": 1, "game_version": "0.9.0", "created_utc": Time.get_datetime_string_from_system(true), "payload": payload, "sha256": payload.sha256_text()}

static func encode(data: Dictionary) -> String:
	return JSON.stringify(document(data), "  ")

static func same_data(a: Variant, b: Variant) -> bool:

	if (a is int or a is float) and (b is int or b is float):
		return is_finite(float(a)) and is_finite(float(b)) and float(a) == float(b)
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not same_data(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for index in range(a.size()):
			if not same_data(a[index], b[index]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b

static func decode(text: String, catalogue: Dictionary) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return {"error": "This file is too large. Choose a PocketPuzzle backup under 8 MB."}
	var parser: = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {"error": "This is not a valid JSON backup."}
	var envelope: Dictionary = parser.data
	if envelope.get("format") != "PocketPuzzleBackup" or envelope.get("version") != 1 or not envelope.get("payload") is String or not envelope.get("sha256") is String:
		return {"error": "Choose a supported PocketPuzzle backup file."}
	if envelope.payload.sha256_text() != envelope.sha256:
		return {"error": "The backup is incomplete or has changed. Your current save is untouched."}
	if parser.parse(envelope.payload) != OK or not parser.data is Dictionary:
		return {"error": "The backup's save data is invalid."}
	var data: Dictionary = parser.data
	if data.get("version") != 4 or not data.get("players") is Array or data.players.is_empty() or data.players.size() > Records.MAX_PLAYERS:
		return {"error": "This backup uses an unsupported save format."}
	var copy = Records.new()
	copy.restore(data, {"parcel": catalogue.parcel.size(), "block": catalogue.block.size()})
	var normalized: Dictionary = copy.to_data()
	if not same_data(normalized, data):
		return {"error": "Some player data or records are invalid. Restore was canceled."}
	var sessions: = 0
	var completed: = 0
	for player in copy.players:
		completed += int(Journey.metrics(player).total)
		for key in player.sessions:
			if Session.restore(player.sessions[key], catalogue).is_empty():
				return {"error": "An unfinished puzzle no longer matches this game. Restore was canceled."}
			sessions += 1
	return {"data": normalized, "players": copy.players.size(), "completed": completed, "sessions": sessions}

static func read(path: String, catalogue: Dictionary) -> Dictionary:
	var file: = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"error": "This file could not be opened or is larger than 8 MB."}
	return decode(file.get_buffer(MAX_BYTES + 1).get_string_from_utf8(), catalogue)

static func write_text(path: String, text: String) -> bool:
	var file: = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	return file.get_error() == OK

static func restore(path: String, current: Dictionary, incoming: Dictionary, catalogue: Dictionary) -> bool:
	var verified: = decode(encode(incoming), catalogue)
	if verified.has("error"):
		return false

	if not Store.save_data(path + ".before-restore", document(current)):
		return false
	return Store.save_data(path, verified.data)
