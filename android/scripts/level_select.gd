extends Control

@onready var grid: GridContainer = $ScrollContainer/GridContainer
@onready var back_btn: Button = $TopBar/BackButton

func _ready() -> void:
	back_btn.pressed.connect(func(): GameManager.go_home())
	_populate_levels()

func _populate_levels() -> void:
	var unlocked := int(ProgressSave.data.get("unlocked_level", 1))
	for i in range(1, GameManager.TOTAL_VERTICAL_SLICE_LEVELS + 1):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 120)
		var stats := ProgressSave.get_level_stats(i)
		var stars := int(stats.get("stars", 0))
		var star_str := "*".repeat(stars) if stars > 0 else "-"
		if i <= unlocked:
			btn.text = "Level %d\n[%s]" % [i, star_str]
			btn.pressed.connect(func(): GameManager.start_level(i))
		else:
			btn.text = "Level %d\n(Locked)" % i
			btn.disabled = true
		grid.add_child(btn)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.go_home()
