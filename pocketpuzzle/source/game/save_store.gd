extends RefCounted


static func load_data(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var file: = FileAccess.open(candidate, FileAccess.READ)
			if file != null and file.get_length() <= 8388608:
				var parser: = JSON.new()
				if parser.parse(file.get_as_text()) == OK and parser.data is Dictionary:
					return parser.data
	return {}

static func save_data(path: String, data: Dictionary) -> bool:
	var file: = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error: = file.get_error()
	file.close()
	if error != OK:
		return false
	if FileAccess.file_exists(path):
		var parser: = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary and DirAccess.copy_absolute(path, path + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK
