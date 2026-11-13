extends RefCounted

static func valid_date(value: String) -> bool:
	var parts: = value.split("-")
	if parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return false
	for part in parts:
		for character in part:
			if not character in "0123456789":
				return false
	var year: = int(parts[0])
	var month: = int(parts[1])
	var day: = int(parts[2])
	if year < 1970 or year > 9999 or month < 1 or month > 12:
		return false
	var lengths: = [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day >= 1 and day <= lengths[month - 1]

static func level_for(day: String, game_mode: String, count: int) -> int:
	if not valid_date(day) or not game_mode in ["parcel", "block"] or count <= 0:
		return -1
	var seed_value: = 17
	for character in day + ":" + game_mode + ":daily-v1":
		seed_value = (seed_value * 31 + character.unicode_at(0)) & 2147483647

	return seed_value % mini(count, 150)
