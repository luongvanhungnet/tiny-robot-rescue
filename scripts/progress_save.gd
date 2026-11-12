extends Node

const SAVE_PATH := "user://save_data.json"
const SAVE_TMP_PATH := "user://save_data.tmp.json"
const SAVE_BAK_PATH := "user://save_data.bak.json"
const SCHEMA_VERSION := 1

var data: Dictionary = {}

func _ready() -> void:
	load_save()

func default_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unlocked_level": 1,
		"last_selected_level": 1,
		"levels": {}, # "1": {"stars": 3, "best_ink": 120.5, "attempts": 2, "completed": true}
		"settings": {
			"sound_enabled": true,
			"music_enabled": true,
			"vibration_enabled": true,
			"reduced_motion": false
		},
		"cosmetics": {
			"unlocked": ["default"],
			"selected": "default",
			"bolts": 0
		},
		"entitlements": {
			"remove_interstitial_ads": false
		},
		"analytics_local": {
			"total_attempts": 0,
			"total_completions": 0,
			"ads_watched": 0
		}
	}

func load_save(custom_path: String = "") -> void:
	var path := custom_path if custom_path != "" else SAVE_PATH
	var bak_path := (custom_path + ".bak") if custom_path != "" else SAVE_BAK_PATH
	
	var loaded := _try_read_json(path)
	if loaded.is_empty():
		loaded = _try_read_json(bak_path)
	
	if loaded.is_empty():
		data = default_data()
		save_now(custom_path)
	else:
		data = _migrate_and_validate(loaded)

func _try_read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _migrate_and_validate(loaded: Dictionary) -> Dictionary:
	var base := default_data()
	for key in base.keys():
		if not loaded.has(key) or typeof(loaded[key]) != typeof(base[key]):
			loaded[key] = base[key]
	
	for s_key in base["settings"].keys():
		if not loaded["settings"].has(s_key):
			loaded["settings"][s_key] = base["settings"][s_key]
	
	for c_key in base["cosmetics"].keys():
		if not loaded["cosmetics"].has(c_key):
			loaded["cosmetics"][c_key] = base["cosmetics"][c_key]
			
	for e_key in base["entitlements"].keys():
		if not loaded["entitlements"].has(e_key):
			loaded["entitlements"][e_key] = base["entitlements"][e_key]
			
	loaded["schema_version"] = SCHEMA_VERSION
	loaded["unlocked_level"] = max(1, int(loaded["unlocked_level"]))
	loaded["last_selected_level"] = clampi(int(loaded["last_selected_level"]), 1, loaded["unlocked_level"])
	return loaded

func save_now(custom_path: String = "") -> bool:
	var path := custom_path if custom_path != "" else SAVE_PATH
	var tmp_path := (custom_path + ".tmp") if custom_path != "" else SAVE_TMP_PATH
	var bak_path := (custom_path + ".bak") if custom_path != "" else SAVE_BAK_PATH
	
	var json_str := JSON.stringify(data, "\t")
	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		return false
	tmp_file.store_string(json_str)
	tmp_file.flush()
	tmp_file.close()
	
	# Backup existing good save before replacing
	if FileAccess.file_exists(path):
		var dir := DirAccess.open(path.get_base_dir())
		if dir != null:
			if FileAccess.file_exists(bak_path):
				dir.remove(bak_path.get_file())
			dir.rename(path.get_file(), bak_path.get_file())
	
	var dir2 := DirAccess.open(path.get_base_dir())
	if dir2 != null:
		var err := dir2.rename(tmp_path.get_file(), path.get_file())
		return err == OK
	return false

func record_level_attempt(level_id: int) -> void:
	var key := str(level_id)
	if not data["levels"].has(key):
		data["levels"][key] = {"stars": 0, "best_ink": -1.0, "attempts": 0, "completed": false}
	data["levels"][key]["attempts"] = int(data["levels"][key]["attempts"]) + 1
	data["analytics_local"]["total_attempts"] = int(data["analytics_local"]["total_attempts"]) + 1
	save_now()

func record_level_win(level_id: int, stars: int, used_ink: float) -> void:
	var key := str(level_id)
	if not data["levels"].has(key):
		data["levels"][key] = {"stars": 0, "best_ink": -1.0, "attempts": 1, "completed": false}
	var entry: Dictionary = data["levels"][key]
	entry["completed"] = true
	entry["stars"] = max(int(entry["stars"]), stars)
	if float(entry["best_ink"]) < 0.0 or used_ink < float(entry["best_ink"]):
		entry["best_ink"] = snappedf(used_ink, 0.1)
	
	if level_id >= int(data["unlocked_level"]):
		data["unlocked_level"] = level_id + 1
	data["last_selected_level"] = level_id + 1
	data["analytics_local"]["total_completions"] = int(data["analytics_local"]["total_completions"]) + 1
	
	# Cosmetic unlock every 10 levels
	if level_id % 10 == 0:
		var skin_id := "bot_tier_%d" % (level_id / 10)
		if not (skin_id in data["cosmetics"]["unlocked"]):
			data["cosmetics"]["unlocked"].append(skin_id)
	
	save_now()

func get_level_stats(level_id: int) -> Dictionary:
	var key := str(level_id)
	if data["levels"].has(key):
		return data["levels"][key]
	return {"stars": 0, "best_ink": -1.0, "attempts": 0, "completed": false}

func has_remove_ads() -> bool:
	return bool(data["entitlements"].get("remove_interstitial_ads", false))

func set_remove_ads(enabled: bool) -> void:
	data["entitlements"]["remove_interstitial_ads"] = enabled
	save_now()
