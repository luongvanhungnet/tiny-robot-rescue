extends Node

const SAVE_PATH := "user://save_data.json"
const SAVE_TMP_PATH := "user://save_data.tmp.json"
const SAVE_BAK_PATH := "user://save_data.bak.json"
const SCHEMA_VERSION := 2

const SKIN_CATALOG := [
	{"id": "default", "name": "Unit-01 Classic", "cost": 0, "unlock_level": 1, "desc": "Friendly factory helper"},
	{"id": "bot_tier_1", "name": "Crimson Knight", "cost": 80, "unlock_level": 10, "desc": "Armored visor & crimson plating"},
	{"id": "bot_tier_2", "name": "Astro Explorer", "cost": 120, "unlock_level": 20, "desc": "Space dome & gold scanner"},
	{"id": "bot_tier_3", "name": "Neon Cyber", "cost": 180, "unlock_level": 30, "desc": "Sleek dark chassis & cyan glow"},
	{"id": "bot_tier_4", "name": "Steampunk Mk-II", "cost": 240, "unlock_level": 40, "desc": "Brass gears & vintage monocle"},
	{"id": "bot_tier_5", "name": "Golden Champion", "cost": 320, "unlock_level": 50, "desc": "Crown antenna & solid gold alloy"}
]

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
			"reduced_motion": false,
			"clean_capture_mode": false
		},
		"privacy": {
			"prompt_completed": false,
			"personalized_ads": false,
			"analytics_allowed": false
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
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

func _is_compatible_type(loaded_val: Variant, base_val: Variant) -> bool:
	var lt := typeof(loaded_val)
	var bt := typeof(base_val)
	if lt == bt:
		return true
	if (bt == TYPE_INT or bt == TYPE_FLOAT) and (lt == TYPE_INT or lt == TYPE_FLOAT):
		return true
	return false

func _migrate_and_validate(loaded: Dictionary) -> Dictionary:
	var base := default_data()
	for key in base.keys():
		if not loaded.has(key) or not _is_compatible_type(loaded[key], base[key]):
			loaded[key] = base[key]
		elif typeof(base[key]) == TYPE_INT:
			loaded[key] = int(loaded[key])
	
	for s_key in base["settings"].keys():
		if not loaded["settings"].has(s_key):
			loaded["settings"][s_key] = base["settings"][s_key]
	
	for p_key in base["privacy"].keys():
		if not loaded["privacy"].has(p_key):
			loaded["privacy"][p_key] = base["privacy"][p_key]
	
	for c_key in base["cosmetics"].keys():
		if not loaded["cosmetics"].has(c_key):
			loaded["cosmetics"][c_key] = base["cosmetics"][c_key]
	loaded["cosmetics"]["bolts"] = max(0, int(loaded["cosmetics"].get("bolts", 0)))
	if typeof(loaded["cosmetics"].get("unlocked")) != TYPE_ARRAY:
		loaded["cosmetics"]["unlocked"] = ["default"]
	if not ("default" in loaded["cosmetics"]["unlocked"]):
		loaded["cosmetics"]["unlocked"].append("default")
			
	for e_key in base["entitlements"].keys():
		if not loaded["entitlements"].has(e_key):
			loaded["entitlements"][e_key] = base["entitlements"][e_key]

	for a_key in base["analytics_local"].keys():
		if not loaded["analytics_local"].has(a_key):
			loaded["analytics_local"][a_key] = base["analytics_local"][a_key]
		else:
			loaded["analytics_local"][a_key] = int(loaded["analytics_local"][a_key])

	var min_unlocked := 1
	var levels_dict: Dictionary = loaded["levels"]
	for lvl_key in levels_dict.keys():
		var entry = levels_dict[lvl_key]
		if typeof(entry) == TYPE_DICTIONARY and bool(entry.get("completed", false)):
			min_unlocked = max(min_unlocked, int(lvl_key) + 1)

	loaded["schema_version"] = SCHEMA_VERSION
	loaded["unlocked_level"] = max(min_unlocked, max(1, int(loaded["unlocked_level"])))
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

func record_level_win(level_id: int, stars: int, used_ink: float) -> Dictionary:
	var key := str(level_id)
	if not data["levels"].has(key):
		data["levels"][key] = {"stars": 0, "best_ink": -1.0, "attempts": 1, "completed": false}
	var entry: Dictionary = data["levels"][key]
	var was_completed := bool(entry.get("completed", false))
	var prev_stars := int(entry.get("stars", 0))
	entry["completed"] = true
	entry["stars"] = max(prev_stars, stars)
	if float(entry["best_ink"]) < 0.0 or used_ink < float(entry["best_ink"]):
		entry["best_ink"] = snappedf(used_ink, 0.1)
	
	if level_id >= int(data["unlocked_level"]):
		data["unlocked_level"] = min(61, level_id + 1)
	data["last_selected_level"] = clampi(level_id + 1, 1, 60)
	data["analytics_local"]["total_completions"] = int(data["analytics_local"]["total_completions"]) + 1
	
	var earned_bolts := 0
	if not was_completed:
		earned_bolts = 15 + stars * 5
	elif stars > prev_stars:
		earned_bolts = (stars - prev_stars) * 5
	else:
		earned_bolts = 3
	data["cosmetics"]["bolts"] = int(data["cosmetics"]["bolts"]) + earned_bolts
	
	var unlocked_skin := ""
	if level_id % 10 == 0:
		var skin_id := "bot_tier_%d" % (level_id / 10)
		if not (skin_id in data["cosmetics"]["unlocked"]):
			data["cosmetics"]["unlocked"].append(skin_id)
			unlocked_skin = skin_id
	
	save_now()
	return {"earned_bolts": earned_bolts, "unlocked_skin": unlocked_skin}

func get_level_stats(level_id: int) -> Dictionary:
	var key := str(level_id)
	if data["levels"].has(key):
		return data["levels"][key]
	return {"stars": 0, "best_ink": -1.0, "attempts": 0, "completed": false}

func get_total_stars() -> int:
	var total := 0
	for entry in data.get("levels", {}).values():
		if typeof(entry) == TYPE_DICTIONARY:
			total += int(entry.get("stars", 0))
	return total

func get_bolts() -> int:
	return int(data.get("cosmetics", {}).get("bolts", 0))

func add_bolts(amount: int) -> void:
	if amount <= 0:
		return
	data["cosmetics"]["bolts"] = get_bolts() + amount
	save_now()

func get_selected_skin() -> String:
	return str(data.get("cosmetics", {}).get("selected", "default"))

func is_skin_unlocked(skin_id: String) -> bool:
	return skin_id in data.get("cosmetics", {}).get("unlocked", ["default"])

func select_skin(skin_id: String) -> bool:
	if not is_skin_unlocked(skin_id):
		return false
	data["cosmetics"]["selected"] = skin_id
	save_now()
	return true

func buy_skin_with_bolts(skin_id: String) -> bool:
	if is_skin_unlocked(skin_id):
		return select_skin(skin_id)
	for skin in SKIN_CATALOG:
		if skin["id"] == skin_id:
			var cost := int(skin["cost"])
			if get_bolts() >= cost:
				data["cosmetics"]["bolts"] = get_bolts() - cost
				data["cosmetics"]["unlocked"].append(skin_id)
				data["cosmetics"]["selected"] = skin_id
				save_now()
				return true
			return false
	return false

func has_remove_ads() -> bool:
	return bool(data["entitlements"].get("remove_interstitial_ads", false))

func set_remove_ads(enabled: bool) -> void:
	data["entitlements"]["remove_interstitial_ads"] = enabled
	save_now()
