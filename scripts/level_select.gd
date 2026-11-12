extends Control

const CHAPTER_NAMES := [
	"Ch 1: Basic Training (01-10)",
	"Ch 2: Drone Swarm & Bouncers (11-20)",
	"Ch 3: Skybridges & Spikes (21-30)",
	"Ch 4: Wind & Lasers (31-40)",
	"Ch 5: Team Rescue & Gates (41-50)",
	"Ch 6: Master Factory (51-60)"
]

@onready var back_btn: Button = $TopBar/BackButton
@onready var stars_lbl: Label = $TopBar/StarsLabel
@onready var chapter_tabs: HBoxContainer = $ChapterTabs
@onready var chapter_name_lbl: Label = $ChapterNameLabel
@onready var grid: GridContainer = $ScrollContainer/GridContainer

var _selected_chapter: int = 0
var _tab_buttons: Array[Button] = []

func _ready() -> void:
	UIThemeHelper.style_button(back_btn, Color("#334155"), Color("#0f172a"))
	back_btn.pressed.connect(func(): GameManager.go_home())
	stars_lbl.text = "%d / 180 ★" % ProgressSave.get_total_stars()
	
	var unlocked: int = clampi(int(ProgressSave.data.get("unlocked_level", 1)), 1, GameManager.TOTAL_LEVELS)
	_selected_chapter = clampi(floori(float(unlocked - 1) / 10.0), 0, 5)
	_build_chapter_tabs()
	_populate_levels()

func _on_chapter_tab_pressed(chapter_idx: int) -> void:
	_selected_chapter = chapter_idx
	_update_tab_styles()
	_populate_levels()

func _build_chapter_tabs() -> void:
	for i in range(6):
		var tb: Button = Button.new()
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 46)
		tb.text = "Ch %d" % (i + 1)
		tb.add_theme_font_size_override("font_size", 18)
		tb.pressed.connect(_on_chapter_tab_pressed.bind(i))
		chapter_tabs.add_child(tb)
		_tab_buttons.append(tb)
	_update_tab_styles()

func _update_tab_styles() -> void:
	for i in range(_tab_buttons.size()):
		if i == _selected_chapter:
			UIThemeHelper.style_button(_tab_buttons[i], Color("#0284c7"), Color("#0c4a6e"))
		else:
			UIThemeHelper.style_button(_tab_buttons[i], Color("#1e293b"), Color("#0f172a"))
	chapter_name_lbl.text = CHAPTER_NAMES[_selected_chapter]

func _populate_levels() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	var unlocked: int = int(ProgressSave.data.get("unlocked_level", 1))
	var start_id: int = _selected_chapter * 10 + 1
	var end_id: int = start_id + 9
	
	for i in range(start_id, end_id + 1):
		var btn: Button = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(180, 128)
		btn.add_theme_font_size_override("font_size", 22)
		var stats: Dictionary = ProgressSave.get_level_stats(i)
		var stars: int = int(stats.get("stars", 0))
		var completed: bool = bool(stats.get("completed", false))
		var star_str: String = ("★".repeat(stars) + "☆".repeat(3 - stars)) if completed else "NEW"
		
		if i <= unlocked:
			btn.text = "Level %02d\n%s" % [i, star_str]
			if completed:
				UIThemeHelper.style_button(btn, Color("#15803d"), Color("#14532d"))
			else:
				UIThemeHelper.style_button(btn, Color("#0284c7"), Color("#0c4a6e"))
			btn.pressed.connect(GameManager.start_level.bind(i))
		else:
			btn.text = "Level %02d\nLOCKED" % i
			btn.disabled = true
			UIThemeHelper.style_button(btn, Color("#334155"), Color("#1e293b"))
		grid.add_child(btn)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.go_home()
