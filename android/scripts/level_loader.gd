class_name LevelLoader
extends RefCounted

const REQUIRED_FIELDS := [
	"id", "title", "hint", "background_id", "world_bounds",
	"spawn_objects", "draw_zones", "forbidden_zones",
	"max_stroke_length", "simulation_duration", "objective",
	"tutorial_steps", "difficulty_tag", "expected_solution_tags"
]

static func load_level(level_id: int) -> Dictionary:
	var path := "res://data/levels/level_%03d.json" % level_id
	if not FileAccess.file_exists(path):
		push_error("Level file not found: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open level file: " + path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in level file: " + path)
		return {}
	if not validate_level_dict(parsed):
		push_error("Level schema validation failed: " + path)
		return {}
	return parsed

static func validate_level_dict(data: Dictionary) -> bool:
	for field in REQUIRED_FIELDS:
		if not data.has(field):
			return false
	if typeof(data["spawn_objects"]) != TYPE_ARRAY:
		return false
	if float(data["max_stroke_length"]) <= 0.0:
		return false
	if float(data["simulation_duration"]) <= 0.0:
		return false
	if typeof(data["objective"]) != TYPE_DICTIONARY:
		return false
	if not data["objective"].has("type"):
		return false
	return true
