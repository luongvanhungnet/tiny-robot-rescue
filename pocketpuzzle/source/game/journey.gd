extends RefCounted

const Daily = preload("res://game/daily_puzzle.gd")
const CHAPTER_SIZE: = 30
const LEVEL_COUNT: = 150
const DAILY_CAP: = 30
const CHAPTERS: = {
	"parcel": ["Bunny Post", "Peach Orchard", "Cloud Station", "Moon Mail", "Star Parade"],
	"block": ["Meadow Pals", "Bubble Bay", "Honey Garden", "Moon Blocks", "Rainbow Ridge"]
}
const STICKERS: = [
	{"id": "happy_mail", "name": "Happy Mail", "metric": "total", "target": 1, "art": "mail"},
	{"id": "peach_cat", "name": "Peach Cat", "metric": "total", "target": 3, "art": "cat"},
	{"id": "bunny_mail", "name": "Bunny Mail", "metric": "total", "target": 5, "art": "bunny"},
	{"id": "honey_bear", "name": "Honey Bear", "metric": "total", "target": 10, "art": "bear"},
	{"id": "pond_frog", "name": "Pond Frog", "metric": "total", "target": 20, "art": "frog"},
	{"id": "cloud_pup", "name": "Cloud Pup", "metric": "total", "target": 40, "art": "dog"},
	{"id": "cozy_fox", "name": "Cozy Fox", "metric": "total", "target": 75, "art": "fox"},
	{"id": "moon_owl", "name": "Moon Owl", "metric": "total", "target": 100, "art": "owl"},
	{"id": "star_panda", "name": "Star Panda", "metric": "total", "target": 200, "art": "panda"},
	{"id": "rainbow_unicorn", "name": "Rainbow Unicorn", "metric": "total", "target": 300, "art": "unicorn"},
	{"id": "post_duck", "name": "Post Duck", "metric": "parcel", "target": 10, "art": "duck"},
	{"id": "peach_bird", "name": "Peach Bird", "metric": "parcel", "target": 30, "art": "bird"},
	{"id": "cloud_koala", "name": "Cloud Koala", "metric": "parcel", "target": 75, "art": "koala"},
	{"id": "mail_penguin", "name": "Mail Penguin", "metric": "parcel", "target": 150, "art": "penguin"},
	{"id": "meadow_turtle", "name": "Meadow Turtle", "metric": "block", "target": 10, "art": "turtle"},
	{"id": "bubble_fish", "name": "Bubble Fish", "metric": "block", "target": 30, "art": "fish"},
	{"id": "honey_bee", "name": "Honey Bee", "metric": "block", "target": 75, "art": "bee"},
	{"id": "rainbow_butterfly", "name": "Rainbow Butterfly", "metric": "block", "target": 150, "art": "butterfly"},
	{"id": "sun_chick", "name": "Sun Chick", "metric": "daily", "target": 1, "art": "chick"},
	{"id": "night_bat", "name": "Night Bat", "metric": "daily", "target": 7, "art": "bat"}
]
const ACHIEVEMENTS: = [
	{"id": "first_win", "name": "A Happy Start", "metric": "total", "target": 1},
	{"id": "ten_unique", "name": "Ten Little Adventures", "metric": "total", "target": 10},
	{"id": "both_games", "name": "Two Kinds of Happy", "metric": "both", "target": 1},
	{"id": "parcel_chapter", "name": "Bunny Post Complete", "metric": "parcel_first", "target": 30},
	{"id": "block_chapter", "name": "Meadow Pals Complete", "metric": "block_first", "target": 30},
	{"id": "daily_first", "name": "Today's Little Win", "metric": "daily", "target": 1},
	{"id": "daily_three", "name": "Three Happy Days", "metric": "daily", "target": 3},
	{"id": "daily_seven", "name": "A Week of Wonder", "metric": "daily", "target": 7},
	{"id": "daily_thirty", "name": "Thirty Days of Joy", "metric": "daily", "target": 30},
	{"id": "all_puzzles", "name": "The Whole Happy Journey", "metric": "total", "target": 300}
]

static func completed(player: Dictionary, mode: String) -> Array:
	var unique: = {}
	for value in player.progress[mode]:
		if (value is int or value is float) and value == floorf(float(value)) and value >= 0 and value < LEVEL_COUNT:
			unique[int(value)] = true
	for key in player.results[mode]:
		if str(key).is_valid_int() and int(key) >= 0 and int(key) < LEVEL_COUNT:
			unique[int(key)] = true
	var numbers: = unique.keys()
	numbers.sort()
	return numbers

static func chapter_count(player: Dictionary, mode: String, chapter: int) -> int:
	var count: = 0
	for number in completed(player, mode):
		if number >= chapter * CHAPTER_SIZE and number < (chapter + 1) * CHAPTER_SIZE:
			count += 1
	return count

static func sync(player: Dictionary) -> void :
	var raw: Variant = player.get("journey", {})
	var dates: = {}
	if raw is Dictionary and raw.get("daily_dates") is Array:
		for day in raw.daily_dates:
			if day is String and Daily.valid_date(day):
				dates[day] = true
	for day in player.daily_results:
		if not player.daily_results[day].is_empty():
			dates[day] = true
	var ordered: = dates.keys()
	ordered.sort()
	var avatar: String = raw.get("avatar", "") if raw is Dictionary and raw.get("avatar", "") is String else ""
	player.journey = {"daily_dates": ordered.slice(0, DAILY_CAP), "avatar": avatar}
	if not avatar.is_empty() and not unlocked(player, avatar):
		player.journey.avatar = ""

static func credit_daily(player: Dictionary, day: String) -> void :
	if Daily.valid_date(day) and player.journey.daily_dates.size() < DAILY_CAP and not player.journey.daily_dates.has(day):
		player.journey.daily_dates.append(day)
		player.journey.daily_dates.sort()

static func metrics(player: Dictionary) -> Dictionary:
	var parcel: = completed(player, "parcel").size()
	var block: = completed(player, "block").size()
	return {"parcel": parcel, "block": block, "total": parcel + block,
		"daily": player.journey.daily_dates.size(), "both": 1 if parcel > 0 and block > 0 else 0,
		"parcel_first": chapter_count(player, "parcel", 0), "block_first": chapter_count(player, "block", 0)}

static func rows(player: Dictionary, achievements: = false) -> Array:
	var values: = metrics(player)
	var result: Array = []
	for definition in ACHIEVEMENTS if achievements else STICKERS:
		var row: Dictionary = definition.duplicate()
		row.current = mini(int(values[row.metric]), int(row.target))
		row.earned = row.current >= row.target
		row.goal = requirement(row.metric, row.target)
		result.append(row)
	return result

static func requirement(metric: String, target: int) -> String:
	match metric:
		"parcel": return "Solve %d unique Parcel puzzles" % target
		"block": return "Solve %d unique Block puzzles" % target
		"daily": return "Finish your first daily puzzle" if target == 1 else "Finish daily puzzles on %d different days" % target
		"both": return "Solve a regular puzzle in both games"
		"parcel_first": return "Complete all 30 Bunny Post puzzles"
		"block_first": return "Complete all 30 Meadow Pals puzzles"
	return "Solve %d unique regular puzzle%s" % [target, "" if target == 1 else "s"]

static func earned_ids(player: Dictionary, achievements: = false) -> Array:
	return rows(player, achievements).filter( func(row): return row.earned).map( func(row): return row.id)

static func unlocked(player: Dictionary, id: String) -> bool:
	return earned_ids(player).has(id)

static func definition(id: String) -> Dictionary:
	for sticker in STICKERS:
		if sticker.id == id:
			return sticker.duplicate()
	return {}

static func next_goal(player: Dictionary) -> String:
	for row in rows(player):
		if row.earned:
			continue
		var remaining: int = row.target - row.current
		var unit: = "daily day" if row.metric == "daily" else "unique Parcel puzzle" if row.metric == "parcel" else "unique Block puzzle" if row.metric == "block" else "unique puzzle"
		return "%d more %s%s to unlock %s!" % [remaining, unit, "" if remaining == 1 else "s", row.name]
	return "All 20 stickers are yours. What a happy journey!"
