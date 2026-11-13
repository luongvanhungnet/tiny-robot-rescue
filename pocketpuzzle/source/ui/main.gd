extends Control

const ParcelRules = preload("res://game/parcel_rules.gd")
const BlockRules = preload("res://game/block_rules.gd")
const PuzzleBoard = preload("res://ui/puzzle_board.gd")
const PlayerRecords = preload("res://game/player_records.gd")
const SolveClock = preload("res://game/solve_clock.gd")
const Look = preload("res://ui/friendly_theme.gd")
const Art = preload("res://ui/playful_art.gd")
const STAR = preload("res://assets/ui/star.svg")
const Daily = preload("res://game/daily_puzzle.gd")
const Session = preload("res://game/run_session.gd")
const Store = preload("res://game/save_store.gd")
const Lesson = preload("res://game/tutorial.gd")
const Feedback = preload("res://ui/feedback.gd")
const Hint = preload("res://game/puzzle_hint.gd")
const Journey = preload("res://game/journey.gd")
const StickerArt = preload("res://ui/sticker_art.gd")
const HintSearch = preload("res://game/hint_search.gd")
const PuzzleProgress = preload("res://game/puzzle_progress.gd")
const DataTools = preload("res://ui/data_tools.gd")
const SafeLayout = preload("res://ui/safe_layout.gd")
const BackGuard = preload("res://ui/back_guard.gd")
const INK: = Look.INK
const MUTED: = Look.MUTED
const CREAM: = Look.BACKGROUND
const PAPER: = Look.PAPER
const CORAL: = Look.ROSE
const TEAL: = Look.MINT
var save_path: = "user://progress.json"
var levels: Dictionary = {}
var progress: Dictionary = {"parcel": [], "block": [], "last_parcel": 0, "last_block": 0}
var records = PlayerRecords.new()
var solve_clock = SolveClock.new()
var attempt_moves: = 0
var undo_count: = 0
var _run_recorded: = false
var _timer_tenth: = -1
var _app_suspended: = false
var _app_unfocused: = false
var stats_label: Label
var mode: = "parcel"
var level_index: = 0
var rules
var board
var page: VBoxContainer
var status_label: Label
var delivery_label: Label
var meter: ProgressBar
var undo_button: Button
var hint_button: Button
var arrow_buttons: Array[Button] = []
var screen_name: = "home"
var completion_pending: = false
var _scroll: ScrollContainer
var run_kind: = "normal"
var run_date: = ""
var date_override: = ""
var active_actions: Array = []
var tutorial_step: = 0
var instructions_label: Label
var feedback
var _latest_result: Dictionary = {}
var _settings_return: = ""
var _settings_lesson: = ""
var _last_autosave: = 0
var _last_date_check: = 0
var _home_day: = ""
var _new_stickers: Array = []
var _new_achievements: Array = []
var _hint_job
var _restart_dialog: ConfirmationDialog
var challenge_label: Label
var _reference_goal: = 0
var data_tools
var _content_margin: MarginContainer
var _back_guard = BackGuard.new()

func _ready() -> void :
	theme = Theme.new()
	theme.default_font = Look.regular_font()
	var file: = FileAccess.open("res://assets/data/levels.json", FileAccess.READ)
	if file == null:
		push_error("Missing level data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("parcel") or not parsed.has("block"):
		push_error("Invalid level data")
		return
	levels = parsed
	_load_progress()
	feedback = Feedback.new()
	add_child(feedback)
	feedback.configure(records.settings)
	data_tools = DataTools.new()
	add_child(data_tools)
	var background: = ColorRect.new()
	background.name = "Background"
	background.color = CREAM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var decorations = Art.new()
	decorations.kind = "background"
	decorations.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(decorations)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var margin: = MarginContainer.new()
	_content_margin = margin
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_scroll.add_child(margin)
	page = VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	resized.connect(_update_safe_area)
	_update_safe_area()
	show_home()

func _update_safe_area() -> void :
	if OS.has_feature("android") and is_instance_valid(_content_margin):
		apply_safe_area(DisplayServer.get_display_safe_area(), DisplayServer.window_get_size())

func apply_safe_area(safe: Rect2i, physical: Vector2i) -> void :
	var edges: = SafeLayout.insets(safe, physical, get_viewport_rect().size)
	for item in [["left", 30 + edges.x], ["top", 24 + edges.y], ["right", 30 + edges.z], ["bottom", 24 + edges.w]]:
		_content_margin.add_theme_constant_override("margin_" + item[0], item[1])

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_stash_session()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if OS.has_feature("android") and not _back_guard.accept(Time.get_ticks_msec()):
			return
		if is_instance_valid(data_tools) and data_tools.handle_back():
			return
		elif is_instance_valid(_restart_dialog):
			_finish_restart(false)
		elif screen_name == "home":
			get_tree().quit()
		elif screen_name == "settings" and not _settings_return.is_empty():
			resume_saved(_settings_return)
		elif screen_name == "settings" and not _settings_lesson.is_empty():
			start_tutorial(_settings_lesson)
		else:
			show_home()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_hint()
		if what == NOTIFICATION_APPLICATION_PAUSED:
			_app_suspended = true
		else:
			_app_unfocused = true
		solve_clock.pause(Time.get_ticks_msec())
		_stash_session()
		if is_instance_valid(feedback):
			feedback.stop()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if what == NOTIFICATION_APPLICATION_RESUMED:
			_app_suspended = false
		else:
			_app_unfocused = false
		if not _app_suspended and not _app_unfocused and not is_instance_valid(_restart_dialog):
			solve_clock.resume(Time.get_ticks_msec())

func _process(_delta: float) -> void :
	if _hint_job != null and screen_name == "game" and not _app_suspended and not _app_unfocused:
		_hint_job.step()
		if _hint_job.done:
			if OS.is_debug_build():
				print("HINT PERF work_us=%d peak_slice_us=%d states=%d result=%s" % [_hint_job.work_usec, _hint_job.peak_slice_usec, _hint_job.visited_count(), _hint_job.reason])
			var suggestion: Dictionary = _hint_job.result
			_hint_job = null
			hint_button.disabled = false
			_apply_hint(suggestion)
	if screen_name == "home" and Time.get_ticks_msec() - _last_date_check >= 1000:
		_last_date_check = Time.get_ticks_msec()
		if _home_day != today():
			show_home()
	if screen_name == "game" and not completion_pending:
		solve_clock.tick(Time.get_ticks_msec())
		var tenth: = int(solve_clock.elapsed_ms / 100)
		if tenth != _timer_tenth:
			_timer_tenth = tenth
			_update_stats()
		if Time.get_ticks_msec() - _last_autosave >= 5000:
			_stash_session()

func _update_stats() -> void :
	if is_instance_valid(stats_label):
		stats_label.text = "Practice   /   Moves %d" % attempt_moves if run_kind == "tutorial" else "%s   /   Moves %d   /   Undo %d" % [SolveClock.format_time(solve_clock.elapsed_ms), attempt_moves, undo_count]

func today() -> String:
	return date_override if not date_override.is_empty() else Time.get_date_string_from_system()

func _best_for_run() -> Dictionary:
	if run_kind == "daily":
		return records.best_daily(run_date, mode)
	return records.best(mode, level_index) if run_kind == "normal" else {}

func _level_counts() -> Dictionary:
	return {"parcel": levels.parcel.size(), "block": levels.block.size()}

func _total_levels() -> int:
	return levels.parcel.size() + levels.block.size()

func _style(color: Color, radius: = 26, border: = Color.TRANSPARENT) -> StyleBoxFlat:
	return Look.box(color, radius, border if border.a > 0 else Color("e9e0f2"), color.a > 0)

func _meter_style(color: Color) -> StyleBoxFlat:
	var style: = Look.box(color, 8)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _art(kind: String, minimum: Vector2) -> Control:
	var art = Art.new()
	art.kind = kind
	art.reduced_motion = records.settings.reduced_motion
	art.custom_minimum_size = minimum
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return art

func _sticker(id: String, minimum: Vector2, locked: = false) -> Control:
	var art = StickerArt.new()
	var definition: = Journey.definition(id)
	art.kind = definition.get("art", "medal")
	for index in range(Journey.STICKERS.size()):
		if Journey.STICKERS[index].id == id:
			art.variant = index
	art.locked = locked
	art.custom_minimum_size = minimum
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return art

func _avatar(id: String, minimum: Vector2, variant: = 0) -> Control:
	if not id.is_empty():
		return _sticker(id, minimum)
	var art = _art("avatar", minimum)
	art.variant = variant
	return art

func _label(text: String, font_size: = 24, color: = INK) -> Label:
	var label: = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if font_size >= 26:
		label.add_theme_font_override("font", Look.bold_font())
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, callback: Callable, primary: = false) -> Button:
	var button: = Button.new()
	button.text = text
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size.y = 88
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_font_override("font", Look.bold_font())
	button.add_theme_color_override("font_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	button.add_theme_color_override("font_pressed_color", PAPER if primary else INK)
	button.add_theme_color_override("font_focus_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_pressed_color", PAPER if primary else INK)
	button.add_theme_color_override("font_disabled_color", Color("aaa0b8"))
	button.add_theme_stylebox_override("normal", _style(Look.PURPLE if primary else PAPER))
	button.add_theme_stylebox_override("hover", _style(Look.PURPLE.lightened(0.1) if primary else Color("f1eafb")))
	var pressed: = _style(Look.PURPLE.darkened(0.1) if primary else Color("e8dcf6"))
	pressed.content_margin_top = 18
	pressed.content_margin_bottom = 10
	pressed.shadow_offset = Vector2(0, 1)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", Look.box(Color("eee9f4"), 26))
	button.add_theme_stylebox_override("focus", Look.box(Color.TRANSPARENT, 26, Look.PURPLE))
	button.pressed.connect(callback)
	return button

func _clear_page() -> void :
	_cancel_hint()
	if is_instance_valid(_restart_dialog):
		_restart_dialog.queue_free()
		_restart_dialog = null
	_stash_session()
	solve_clock.finish(Time.get_ticks_msec())
	stats_label = null
	instructions_label = null
	status_label = null
	challenge_label = null
	completion_pending = false
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	board = null
	arrow_buttons.clear()
	_scroll.scroll_vertical = 0

func _header(tag: String) -> void :
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_art("mark", Vector2(38, 40)))
	var brand: = _label("PocketPuzzle", 26)
	brand.custom_minimum_size.x = 188
	brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(brand)
	var pill: = PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pill_style: = Look.box(Color("eee5fa"), 18)
	pill_style.content_margin_top = 7
	pill_style.content_margin_bottom = 7
	pill.add_theme_stylebox_override("panel", pill_style)
	var badge: = _label(tag.capitalize(), 15, Look.PURPLE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(badge)
	row.add_child(pill)
	page.add_child(row)

func show_home() -> void :
	_clear_page()
	screen_name = "home"
	_home_day = today()
	_header("A HAPPY LITTLE BREAK")
	var welcome: = HBoxContainer.new()
	welcome.add_theme_constant_override("separation", 12)
	var greeting: = VBoxContainer.new()
	greeting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	greeting.add_child(_label("Little puzzles,\nbig smiles.", 46))
	greeting.add_child(_label("Pick a pal. Find your happy place.", 22, MUTED))
	welcome.add_child(greeting)
	welcome.add_child(_art("welcome", Vector2(138, 145)) if records.current().journey.avatar.is_empty() else _avatar(records.current().journey.avatar, Vector2(138, 145)))
	page.add_child(welcome)
	var player_row: = HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 12)
	player_row.add_child(_button(records.current().name, show_players))
	player_row.add_child(_button("Rankings", show_rankings))
	player_row.add_child(_button("Settings", show_settings))
	page.add_child(player_row)
	_add_daily_card()
	_add_game_card("parcel", "PARCEL SORT", "A bundle of joy.", "Happy mail needs a little help. Match the parcels and make room!", CORAL)
	_add_game_card("block", "BLOCK EXIT", "Give pals a way out.", "A little nudge, a happy exit. Find the matching gate for each pal.", TEAL)
	var completed: int = Journey.metrics(records.current()).total
	var collection: = PanelContainer.new()
	collection.add_theme_stylebox_override("panel", _style(PAPER))
	var contents: = VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	var total_score: = 0
	for row in records.ranking():
		if row.id == records.active_id:
			total_score = int(row.score)
	contents.add_child(_label("YOUR HAPPY LITTLE COLLECTION", 17, Look.PURPLE))
	contents.add_child(_label("%d / %d puzzles   /   %d points" % [completed, _total_levels(), total_score], 25))
	var bar: = ProgressBar.new()
	bar.custom_minimum_size.y = 10
	bar.max_value = _total_levels()
	bar.value = completed
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _meter_style(Color("eee5f7")))
	bar.add_theme_stylebox_override("fill", _meter_style(Color("b99cdc")))
	contents.add_child(bar)
	contents.add_child(_label(Journey.next_goal(records.current()), 22, Look.PURPLE))
	var rewards: = HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 12)
	rewards.add_child(_button("Journey maps", show_journey.bind("parcel")))
	rewards.add_child(_button("Sticker album %d/20" % Journey.earned_ids(records.current()).size(), show_album))
	contents.add_child(rewards)
	collection.add_child(contents)
	page.add_child(collection)
	var footer: = _label("A cozy little break. Offline, ad-free, and all yours.", 18, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(footer)

func _add_game_card(game_mode: String, eyebrow: String, title: String, description: String, accent: Color) -> void :
	var panel: = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("fff0f1") if game_mode == "parcel" else Color("eaf7ef"), 30, Color("f0d7df") if game_mode == "parcel" else Color("cde7db")))
	var contents: = VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	var preview: = HBoxContainer.new()
	preview.add_theme_constant_override("separation", 16)
	preview.add_child(_art(game_mode, Vector2(130, 132)))
	var copy: = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 5)
	copy.add_child(_label(eyebrow + "  /  %d puzzles" % levels[game_mode].size(), 16, accent))
	copy.add_child(_label(title, 30))
	copy.add_child(_label(description, 21, MUTED))
	preview.add_child(copy)
	contents.add_child(preview)
	var number: int = int(progress["last_" + game_mode])
	var pending: Dictionary = records.current().sessions.get(game_mode, {})
	var pending_level: = Session.integer(pending.get("level"), 0, levels[game_mode].size() - 1)
	var resume_available: = not pending.is_empty() and pending_level >= 0
	var play: = _button(("Resume" if resume_available else "Play") + " level %02d   >" % ((pending_level if resume_available else number) + 1), open_game.bind(game_mode), true)
	play.custom_minimum_size.y = 80
	play.add_theme_stylebox_override("normal", _style(accent, 24, accent.lightened(0.15)))
	play.add_theme_stylebox_override("hover", _style(accent.lightened(0.08)))
	play.add_theme_stylebox_override("pressed", _style(accent.darkened(0.08)))
	var play_row: = HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 12)
	play_row.add_child(play)
	var map_button: = _button("Map", show_journey.bind(game_mode))
	map_button.custom_minimum_size = Vector2(96, 80)
	map_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	map_button.add_theme_font_size_override("font_size", 20)
	play_row.add_child(map_button)
	var learn: = _button("Learn", start_tutorial.bind(game_mode))
	learn.custom_minimum_size = Vector2(100, 80)
	learn.add_theme_font_size_override("font_size", 20)
	learn.size_flags_horizontal = Control.SIZE_SHRINK_END
	play_row.add_child(learn)
	contents.add_child(play_row)
	panel.add_child(contents)
	page.add_child(panel)

func show_levels(game_mode: String, page_number: int = -1) -> void :
	_clear_page()
	screen_name = "levels"
	mode = game_mode
	_header("CHOOSE YOUR PUZZLE")
	page.add_child(_label("Parcel Sort" if mode == "parcel" else "Block Exit", 46))
	var count: int = levels[mode].size()
	var current_page: = clampi(int(level_index / 30) if page_number < 0 else page_number, 0, int((count - 1) / 30))
	page.add_child(_label("Chapter %d / %s" % [current_page + 1, Journey.CHAPTERS[mode][current_page]], 25, Look.PURPLE))
	page.add_child(_label("%d little adventures. Every level is open!" % count, 22, MUTED))
	page.add_child(_label("G = Gentle / T = Tricky / C = Challenging (estimates)", 20, MUTED))
	var completed: = Journey.completed(records.current(), mode)
	var grid: = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in range(current_page * 30, mini(current_page * 30 + 30, count)):
		var done: bool = completed.has(i)
		var difficulty: = PuzzleProgress.difficulty(mode, levels[mode][i])
		var button: = _button("%02d / %s" % [i + 1, difficulty.left(1)], start_level.bind(mode, i))
		button.add_theme_font_size_override("font_size", 21)
		button.tooltip_text = "%s difficulty estimate" % difficulty
		button.add_theme_stylebox_override("normal", _style(Color("def0e5") if done else PAPER, 24, Color("b8d8c7") if done else Color("e9e0f2")))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var tile_style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			tile_style.content_margin_left = 8
			tile_style.content_margin_right = 8
			button.add_theme_stylebox_override(state, tile_style)
		if done:
			button.icon = STAR
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 22)
		button.custom_minimum_size = Vector2(100, 94)
		grid.add_child(button)
	page.add_child(grid)
	var navigation: = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	var previous: = _button("< Previous", show_levels.bind(mode, current_page - 1))
	previous.disabled = current_page == 0
	navigation.add_child(previous)
	var next: = _button("Next >", show_levels.bind(mode, current_page + 1))
	next.disabled = (current_page + 1) * 30 >= count
	navigation.add_child(next)
	page.add_child(navigation)
	page.add_child(_button("Back to journey", show_journey.bind(mode)))

func show_journey(game_mode: String = "parcel") -> void :
	_clear_page()
	screen_name = "journey"
	mode = game_mode
	_header("YOUR PUZZLE JOURNEY")
	var navigation: = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	navigation.add_child(_button("< Home", show_home))
	navigation.add_child(_button("Parcel" if mode == "block" else "Block", show_journey.bind("parcel" if mode == "block" else "block")))
	var next_button: = _button("Find next >", find_next_puzzle.bind(mode), true)
	next_button.name = "FindNextPuzzle"
	next_button.tooltip_text = "Find my next puzzle; saved attempts resume first"
	next_button.disabled = PuzzleProgress.next_unfinished(records.current(), mode, levels[mode].size()) < 0 and not records.current().sessions.has(mode)
	navigation.add_child(next_button)
	page.add_child(navigation)
	page.add_child(_label("Your %s journey." % ("Parcel" if mode == "parcel" else "Block"), 36))
	page.add_child(_label("Five cozy chapters. Every puzzle is open.", 22, MUTED))
	for chapter in range(5):
		var margin: = MarginContainer.new()
		margin.add_theme_constant_override("margin_left" if chapter % 2 == 1 else "margin_right", 40)
		var panel: = PanelContainer.new()
		panel.name = "Chapter%d" % chapter
		panel.add_theme_stylebox_override("panel", _style(Look.PASTELS[chapter % 4].lightened(0.75)))
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_sticker(Journey.STICKERS[(chapter * 2 + (0 if mode == "parcel" else 10)) % 20].id, Vector2(78, 78)))
		var content: = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var done: = Journey.chapter_count(records.current(), mode, chapter)
		var visit: = _button("%d. %s\nLevels %02d-%02d / %d of 30 stars" % [chapter + 1, Journey.CHAPTERS[mode][chapter], chapter * 30 + 1, (chapter + 1) * 30, done], show_levels.bind(mode, chapter))
		visit.name = "VisitChapter%d" % chapter
		visit.add_theme_font_size_override("font_size", 22)
		visit.custom_minimum_size.y = 78
		content.add_child(visit)
		var bar: = ProgressBar.new()
		bar.custom_minimum_size.y = 8
		bar.show_percentage = false
		bar.max_value = 30
		bar.value = done
		bar.add_theme_stylebox_override("background", _meter_style(Color("e9e0f3")))
		bar.add_theme_stylebox_override("fill", _meter_style(Look.PURPLE))
		content.add_child(bar)
		row.add_child(content)
		panel.add_child(row)
		margin.add_child(panel)
		page.add_child(margin)
		if chapter < 4:
			page.add_child(_art("trail", Vector2(0, 14)))
	page.add_child(_button("Visit my sticker album", show_album))

func show_album(page_number: int = 0, achievements: = false) -> void :
	_clear_page()
	screen_name = "album"
	_header("LITTLE WINS, LOVELY PALS")
	page.add_child(_label("%s's %s" % [records.current().name, "achievements" if achievements else "sticker album"], 34))
	var tabs: = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.add_child(_button("Stickers %d/20" % Journey.earned_ids(records.current()).size(), show_album.bind(0, false), not achievements))
	tabs.add_child(_button("Badges %d/10" % Journey.earned_ids(records.current(), true).size(), show_album.bind(0, true), achievements))
	page.add_child(tabs)
	var goal: = _label(Journey.next_goal(records.current()), 21, Look.PURPLE)
	goal.custom_minimum_size.y = 54
	page.add_child(goal)
	var entries: = Journey.rows(records.current(), achievements)
	var current_page: = clampi(page_number, 0, int((entries.size() - 1) / 4))
	var grid: = GridContainer.new()
	grid.name = "AlbumGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for index in range(current_page * 4, mini(current_page * 4 + 4, entries.size())):
		var entry: Dictionary = entries[index]
		var panel: = PanelContainer.new()
		panel.name = entry.id
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _style(PAPER if entry.earned else Color("f0ebf6")))
		var content: = VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		content.add_child(_sticker(entry.id if not achievements else "medal", Vector2(0, 100), not entry.earned))
		var title: = _label(entry.name, 24)
		title.custom_minimum_size.y = 66 if achievements else 34
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(title)
		var requirement: = _label(entry.goal, 20, MUTED)
		requirement.custom_minimum_size.y = 56
		content.add_child(requirement)
		content.add_child(_label("Earned!" if entry.earned else "%d / %d" % [entry.current, entry.target], 21, TEAL if entry.earned else MUTED))
		if not achievements:
			var selected: bool = records.current().journey.avatar == entry.id
			var choose: = _button("My avatar" if selected else "Use as avatar" if entry.earned else "Keep exploring", _choose_avatar.bind(entry.id, current_page), selected)
			choose.disabled = not entry.earned or selected
			choose.custom_minimum_size.y = 72
			choose.add_theme_font_size_override("font_size", 21)
			content.add_child(choose)
		panel.add_child(content)
		grid.add_child(panel)
	page.add_child(grid)
	var navigation: = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	var previous: = _button("< Previous", show_album.bind(current_page - 1, achievements))
	previous.disabled = current_page == 0
	navigation.add_child(previous)
	var page_label: = _label("%d / %d" % [current_page + 1, int(ceil(entries.size() / 4.0))], 22, MUTED)
	page_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	page_label.custom_minimum_size.x = 64
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(page_label)
	var next: = _button("Next >", show_album.bind(current_page + 1, achievements))
	next.disabled = (current_page + 1) * 4 >= entries.size()
	navigation.add_child(next)
	page.add_child(navigation)
	var footer: = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.add_child(_button("Default avatar", _choose_avatar.bind("", current_page)))
	footer.add_child(_button("< Home", show_home))
	page.add_child(footer)

func _choose_avatar(id: String, album_page: int) -> void :
	if records.select_avatar(id):
		_save_progress()
		show_album(album_page)

func start_level(game_mode: String, number: int, kind: String = "normal", day: String = "") -> void :
	_clear_page()
	screen_name = "game"
	mode = game_mode
	run_kind = kind
	run_date = day
	level_index = clampi(number, 0, levels[mode].size() - 1)
	if run_kind == "normal":
		progress["last_" + mode] = level_index
	if run_kind != "tutorial":
		records.current().sessions.erase(Session.key(run_kind, mode))
	_save_progress()
	rules = ParcelRules.new() if mode == "parcel" else BlockRules.new()
	rules.setup(levels[mode][level_index])
	attempt_moves = 0
	undo_count = 0
	_run_recorded = false
	_timer_tenth = -1
	active_actions = []
	tutorial_step = 0
	_latest_result = {}
	_reference_goal = PuzzleProgress.reference_goal(mode, levels[mode][level_index]) if run_kind != "tutorial" else 0
	_new_stickers = []
	_new_achievements = []
	_header(("LEARN " if run_kind == "tutorial" else "DAILY JOY / " if run_kind == "daily" else "") + ("PARCEL SORT" if mode == "parcel" else "BLOCK EXIT"))
	var nav: = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	var home_button: = _button("< Home", show_home)
	home_button.custom_minimum_size.x = 130
	home_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nav.add_child(home_button)
	if run_kind == "tutorial":
		nav.add_child(_button("Skip lesson >", start_level.bind(mode, 0)))
	elif run_kind == "daily":
		nav.add_child(_button(run_date, show_home))
	else:
		nav.add_child(_button("LEVEL %02d / %d" % [level_index + 1, levels[mode].size()], show_journey.bind(mode)))
	var settings_button: = _button("Settings", show_settings)
	settings_button.custom_minimum_size.x = 126
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	settings_button.add_theme_font_size_override("font_size", 20)
	nav.add_child(settings_button)
	page.add_child(nav)
	page.add_child(_label("Let's send a little happiness!" if mode == "parcel" else "A little nudge. A happy exit.", 30))
	instructions_label = _label("Tap a queue to send a parcel. Extras wait for their turn." if mode == "parcel" else "Tap a pal, then swipe or use the arrows. Find its matching gate!", 22, MUTED)
	page.add_child(instructions_label)
	challenge_label = _label("", 20, TEAL)
	page.add_child(challenge_label)
	stats_label = _label("", 22, INK)
	page.add_child(stats_label)
	delivery_label = _label("", 20, TEAL)
	page.add_child(delivery_label)
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 8
	meter.show_percentage = false
	meter.add_theme_stylebox_override("background", _meter_style(Color("e9e0f3")))
	meter.add_theme_stylebox_override("fill", _meter_style(Color("b89bd8")))
	page.add_child(meter)
	board = PuzzleBoard.new()
	board.name = "PuzzleBoard"
	board.mode = mode
	board.rules = rules
	board.reduced_motion = records.settings.reduced_motion
	board.clear_symbols = records.settings.clear_symbols
	board.custom_minimum_size.y = 610 if mode == "parcel" else 540
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.played.connect(play_move)
	board.selection_changed.connect(_selection_changed)
	page.add_child(board)
	if mode == "block":
		var arrows: = HBoxContainer.new()
		arrows.add_theme_constant_override("separation", 12)
		var directions: = [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
		var names: = ["<", "^", "v", ">"]
		for i in range(4):
			var button: = _button(names[i], _arrow_move.bind(directions[i]), true)
			button.tooltip_text = ["Move left", "Move up", "Move down", "Move right"][i]
			arrow_buttons.append(button)
			arrows.add_child(button)
		page.add_child(arrows)
	var actions: = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	undo_button = _button("Undo", undo_move)
	actions.add_child(undo_button)
	hint_button = _button("Hint", show_hint)
	hint_button.disabled = run_kind == "tutorial"
	actions.add_child(hint_button)
	actions.add_child(_button("Restart", restart_run))
	page.add_child(actions)
	status_label = _label("Take your time, puzzle pal. You've got this!", 21, MUTED)
	status_label.custom_minimum_size.y = 42
	page.add_child(status_label)
	solve_clock.start(Time.get_ticks_msec())
	if _app_suspended or _app_unfocused:
		solve_clock.pause(Time.get_ticks_msec())
	_refresh()
	_refresh_guide()
	_stash_session()

func restart_run() -> void :
	if screen_name != "game" or completion_pending or is_instance_valid(_restart_dialog):
		return
	if attempt_moves == 0:
		start_level(mode, level_index, run_kind, run_date)
		return
	_cancel_hint()
	solve_clock.pause(Time.get_ticks_msec())
	_stash_session()
	_restart_dialog = ConfirmationDialog.new()
	_restart_dialog.title = "Start this puzzle again?"
	_restart_dialog.dialog_text = "Start this puzzle again?\n\nYour moves, undo history and time will reset.\nYour best scores and stickers stay saved."
	_restart_dialog.ok_button_text = "Restart"
	_restart_dialog.cancel_button_text = "Keep playing"
	_restart_dialog.exclusive = true
	_restart_dialog.borderless = true
	_restart_dialog.transparent_bg = true
	_restart_dialog.theme = theme.duplicate()
	_restart_dialog.theme.default_font_size = 24
	_restart_dialog.add_theme_constant_override("buttons_min_height", 80)
	_restart_dialog.add_theme_constant_override("buttons_min_width", 180)
	_restart_dialog.add_theme_stylebox_override("panel", _style(PAPER, 26, Color("d8c7ed")))
	_restart_dialog.get_label().add_theme_color_override("font_color", INK)
	_restart_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_restart_dialog.get_label().custom_minimum_size = Vector2(480, 160)
	_restart_dialog.get_ok_button().custom_minimum_size = Vector2(180, 72)
	_restart_dialog.get_cancel_button().custom_minimum_size = Vector2(180, 72)
	for button in [_restart_dialog.get_ok_button(), _restart_dialog.get_cancel_button()]:
		var primary: bool = button == _restart_dialog.get_ok_button()
		button.add_theme_font_override("font", Look.bold_font())
		button.add_theme_stylebox_override("normal", _style(Look.PURPLE if primary else Color("eee5fa")))
		button.add_theme_stylebox_override("hover", _style(Look.PURPLE.lightened(0.1) if primary else Color("e5d8f5")))
		button.add_theme_stylebox_override("pressed", _style(Look.PURPLE.darkened(0.1) if primary else Color("dbc9ef")))
		button.add_theme_stylebox_override("focus", Look.box(Color.TRANSPARENT, 26, Look.PURPLE))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, PAPER if primary else INK)
	_restart_dialog.confirmed.connect(_finish_restart.bind(true))
	_restart_dialog.canceled.connect(_finish_restart.bind(false))
	add_child(_restart_dialog)
	_restart_dialog.popup_centered(Vector2i(560, 300))

func _finish_restart(confirmed: bool) -> void :
	if not is_instance_valid(_restart_dialog):
		return
	_restart_dialog.hide()
	_restart_dialog.queue_free()
	_restart_dialog = null
	if screen_name != "game":
		return
	if confirmed:
		start_level(mode, level_index, run_kind, run_date)
	elif not _app_suspended and not _app_unfocused:
		solve_clock.resume(Time.get_ticks_msec())

func find_next_puzzle(game_mode: String) -> void :
	_stash_session()
	var pending: Dictionary = records.current().sessions.get(game_mode, {})
	if not pending.is_empty():
		if not Session.restore(pending, levels).is_empty():
			resume_saved(game_mode)
			return
		records.current().sessions.erase(game_mode)
		_save_progress()
	var number: = PuzzleProgress.next_unfinished(records.current(), game_mode, levels[game_mode].size())
	if number < 0:
		show_journey(game_mode)
	else:
		start_level(game_mode, number)

func open_game(game_mode: String) -> void :
	if records.current().sessions.has(game_mode):
		resume_saved(game_mode)
	elif not records.current().tutorials[game_mode] and records.current().progress[game_mode].is_empty():
		start_tutorial(game_mode)
	else:
		start_level(game_mode, int(progress["last_" + game_mode]))

func start_tutorial(game_mode: String) -> void :
	start_level(game_mode, Lesson.level_for(game_mode), "tutorial")

func _selection_changed() -> void :
	_update_arrows()
	_stash_session()

func _refresh_guide() -> void :
	if run_kind != "tutorial" or board == null or rules.won():
		return
	var solution: Array = levels[mode][level_index].solution
	instructions_label.text = Lesson.message(mode, tutorial_step, solution)
	var expected: Array = Lesson.expected(mode, tutorial_step, solution)
	board.guide_lane = int(expected[0]) if mode == "parcel" else -1
	board.guide_piece = int(expected[0]) if mode == "block" else -1
	board.queue_redraw()
	_update_arrows()

func _arrow_move(direction: Vector2i) -> void :
	if board != null:
		play_move(board.selected, direction)

func _clear_hint() -> void :
	_cancel_hint()
	if board != null and run_kind != "tutorial":
		board.guide_lane = -1
		board.guide_piece = -1
		board.queue_redraw()

func show_hint() -> void :
	if screen_name != "game" or completion_pending or run_kind == "tutorial" or is_instance_valid(_restart_dialog):
		return
	_clear_hint()
	_hint_job = HintSearch.new(mode, levels[mode][level_index], rules)
	if _hint_job.done:
		var suggestion: Dictionary = _hint_job.result
		_hint_job = null
		_apply_hint(suggestion)
	else:
		hint_button.disabled = true
		status_label.text = "Finding a gentle nudge... You can keep playing."

func _cancel_hint() -> void :
	if _hint_job != null:
		_hint_job = null
		if is_instance_valid(hint_button):
			hint_button.disabled = run_kind == "tutorial" or completion_pending
		if is_instance_valid(status_label):
			status_label.text = "Hint paused. Tap Hint whenever you're ready."

func _apply_hint(suggestion: Dictionary) -> void :
	if suggestion.is_empty():
		status_label.text = "No hint here yet. Try undo, or a fresh start."
	elif suggestion.get("kind") == "undo":
		status_label.text = "Undo %d move%s to return to a known route. Undo still affects your score." % [suggestion.count, "" if suggestion.count == 1 else "s"]
	elif suggestion.get("kind") == "move":
		var action: Array = suggestion.action
		if mode == "parcel":
			board.guide_lane = action[0]
			status_label.text = "Try the highlighted %s queue. Hints are free!" % ["left", "middle", "right"][int(action[0])]
		else:
			board.guide_piece = action[0]
			board.selected = action[0]
			var direction: = Vector2i(action[1], action[2])
			var word: = "left" if direction == Vector2i.LEFT else "right" if direction == Vector2i.RIGHT else "up" if direction == Vector2i.UP else "down"
			status_label.text = "Try moving the highlighted pal one step %s. Hints are free!" % word
			_update_arrows()
			_stash_session()
	else:
		status_label.text = "No hint found within the search limit. Try undo or a fresh start."
	board.queue_redraw()

func play_move(index: int, direction: Vector2i) -> void :
	if screen_name != "game" or completion_pending or is_instance_valid(_restart_dialog):
		return
	if active_actions.size() >= Session.MAX_ACTIONS:
		status_label.text = "That's a lot of nudges! Undo or restart for a fresh try."
		return
	if run_kind == "tutorial":
		var expected: Array = Lesson.expected(mode, tutorial_step, levels[mode][level_index].solution)
		if int(expected[0]) != index or (mode == "block" and direction != Vector2i(int(expected[1]), int(expected[2]))):
			status_label.text = "Follow the glowing pal. You're doing great!"
			return
	var before: int = rules.delivered if mode == "parcel" else rules.remaining()
	var accepted: bool = rules.send(index) if mode == "parcel" else rules.move_piece(index, direction)
	if not accepted:
		status_label.text = "A little crowded! Try a matching parcel, or undo." if mode == "parcel" else "Oops, a cozy squeeze! Try another way to the matching gate."
		return
	_clear_hint()
	attempt_moves += 1
	active_actions.append([index] if mode == "parcel" else [index, direction.x, direction.y])
	if run_kind == "tutorial":
		tutorial_step += 1
	board.celebrate_move()
	if mode == "parcel":
		var count: int = rules.delivered - before
		status_label.text = "Lovely! %d parcels delivered." % count if count > 0 else "Cozy for now. Keep a waiting spot free!"
		if rules.stuck():
			status_label.text = "All spots are full. Undo and try a fresh little order."
	else:
		status_label.text = "Hooray! One happy pal is home." if rules.remaining() < before else "A little closer! Let's find that happy exit."
	_refresh()
	_refresh_guide()
	var delivered: bool = rules.delivered > before if mode == "parcel" else rules.remaining() < before
	feedback.play("deliver" if delivered else "move")
	if rules.won():
		solve_clock.finish(Time.get_ticks_msec())
		_update_stats()
		completion_pending = true
		_commit_win()
		feedback.play("win")
		var current_board = board
		await get_tree().create_timer(0.01 if records.settings.reduced_motion else 0.4).timeout
		if screen_name == "game" and board == current_board and completion_pending:
			show_result()
	else:
		_stash_session()

func undo_move() -> void :
	if screen_name != "game" or completion_pending or is_instance_valid(_restart_dialog):
		return
	if rules.undo():
		_clear_hint()
		undo_count += 1
		if not active_actions.is_empty():
			active_actions.pop_back()
		if run_kind == "tutorial":
			tutorial_step = maxi(0, tutorial_step - 1)
		status_label.text = "A tiny rewind. A fresh possibility!"
		board.queue_redraw()
		_refresh()
		_refresh_guide()
		_stash_session()
		feedback.play("undo")

func _refresh() -> void :
	if is_instance_valid(challenge_label):
		challenge_label.text = "Practice" if run_kind == "tutorial" else PuzzleProgress.difficulty(mode, levels[mode][level_index]) + " (estimate)"
		if run_kind != "tutorial" and records.settings.move_goals and _reference_goal > 0:
			challenge_label.text += " / Reference goal: %d moves" % _reference_goal
	var best: = _best_for_run()
	var high: int = int(best.get("high_score", 0))
	if mode == "parcel":
		delivery_label.text = "%d / %d delivered   /   HIGH SCORE %d" % [rules.delivered, rules.route.size(), high]
		meter.max_value = rules.route.size()
		meter.value = rules.delivered
	else:
		delivery_label.text = "%d blocks to go   /   HIGH SCORE %d" % [rules.remaining(), high]
		meter.max_value = rules.pieces.size()
		meter.value = rules.pieces.size() - rules.remaining()
	undo_button.disabled = rules.history.is_empty()
	if run_kind != "normal":
		delivery_label.text = delivery_label.text.replace("HIGH SCORE", "DAILY BEST" if run_kind == "daily" else "PRACTICE")
	if run_kind == "tutorial":
		delivery_label.text = "%d / %d parcels sent" % [rules.delivered, rules.route.size()] if mode == "parcel" else "Pals to guide: %d" % rules.remaining()
	_update_stats()
	_update_arrows()

func _update_arrows() -> void :
	if mode != "block" or board == null:
		return
	var directions: = [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
	for i in range(arrow_buttons.size()):
		arrow_buttons[i].disabled = not rules.can_move(board.selected, directions[i])
		if run_kind == "tutorial" and not rules.won():
			var expected: Array = Lesson.expected(mode, tutorial_step, levels[mode][level_index].solution)
			arrow_buttons[i].disabled = arrow_buttons[i].disabled or directions[i] != Vector2i(int(expected[1]), int(expected[2]))

func _commit_win() -> void :
	if _run_recorded:
		return
	_run_recorded = true
	var old_stickers: = Journey.earned_ids(records.current())
	var old_achievements: = Journey.earned_ids(records.current(), true)
	if run_kind == "tutorial":
		records.current().tutorials[mode] = true
	elif run_kind == "daily":
		_latest_result = records.record_daily(run_date, mode, solve_clock.elapsed_ms, attempt_moves, undo_count)
	else:
		_latest_result = records.record(mode, level_index, solve_clock.elapsed_ms, attempt_moves, undo_count)
		if not progress[mode].has(level_index):
			progress[mode].append(level_index)
		progress["last_" + mode] = mini(level_index + 1, levels[mode].size() - 1)
	if run_kind != "tutorial":
		records.current().sessions.erase(Session.key(run_kind, mode))
		_new_stickers = Journey.earned_ids(records.current()).filter( func(id): return not old_stickers.has(id))
		_new_achievements = Journey.earned_ids(records.current(), true).filter( func(id): return not old_achievements.has(id))
	_save_progress()

func show_result() -> void :
	if screen_name != "game" or not rules.won():
		return
	solve_clock.finish(Time.get_ticks_msec())
	_commit_win()
	if run_kind == "tutorial":
		_show_lesson_complete()
		return
	var result: = _latest_result
	_clear_page()
	screen_name = "result"
	_header("DAILY JOY / " + run_date if run_kind == "daily" else "A LITTLE VICTORY")
	page.add_child(_art("victory", Vector2(0, 145)))
	var cheer: = _label("You did it, puzzle pal!", 42, Look.PURPLE)
	cheer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(cheer)
	if not _new_stickers.is_empty() or not _new_achievements.is_empty():
		var names: Array = _new_stickers.map( func(id): return Journey.definition(id).name)
		page.add_child(_label("New sticker%s: %s" % ["" if names.size() == 1 else "s", ", ".join(names)] if not names.is_empty() else "A new achievement badge!", 23, Look.PURPLE))
		var index: = 0
		var definitions: Array = Journey.STICKERS if not names.is_empty() else Journey.ACHIEVEMENTS
		for number in range(definitions.size()):
			if definitions[number].id == (_new_stickers[0] if not names.is_empty() else _new_achievements[0]):
				index = number
		page.add_child(_button("See my new treasures >", show_album.bind(int(index / 4), names.is_empty())))
	var score_card: = PanelContainer.new()
	score_card.add_theme_stylebox_override("panel", _style(Color("eee5fa"), 28, Color("d8c7ed")))
	var score_label: = _label("%d points%s" % [result.score, "   /   A new best!" if result.new_high else ""], 30, Look.PURPLE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_card.add_child(score_label)
	page.add_child(score_card)
	page.add_child(_label("Solved in %s   /   Moves %d   /   Undo %d" % [SolveClock.format_time(solve_clock.elapsed_ms), attempt_moves, undo_count], 23))
	if records.settings.move_goals and _reference_goal > 0:
		page.add_child(_label(("Reference goal met!" if attempt_moves <= _reference_goal else "Another goal to try next time.") + " Target: %d moves; your moves: %d. This is not a proven minimum." % [_reference_goal, attempt_moves], 22, TEAL))
	page.add_child(_label("Level best: %d points\nFastest: %s   /   Fewest moves: %d\nTimes solved: %d" % [result.best.high_score, SolveClock.format_time(int(result.best.best_time_ms)), result.best.fewest_moves, result.best.solves], 23, MUTED))
	if run_kind == "daily":
		page.add_child(_label("Your personal best for this day's puzzle. Regular rankings stay separate.", 21, MUTED))
		page.add_child(_button("Today's other little puzzle >", open_daily.bind("block" if mode == "parcel" else "parcel"), true))
		page.add_child(_button("Play regular puzzles", open_game.bind(mode)))
	else:
		page.add_child(_label("%d / %d puzzles in your collection." % [progress.parcel.size() + progress.block.size(), _total_levels()], 22, MUTED))
		page.add_child(_button("Find my next puzzle >", find_next_puzzle.bind(mode), true))
		page.add_child(_button("Say hello to the other game", open_game.bind("block" if mode == "parcel" else "parcel")))
	var options: = HBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	options.add_child(_button("Pick a level", show_levels.bind(mode)))
	options.add_child(_button("Rankings", show_rankings))
	page.add_child(options)
	page.add_child(_button("Rate this puzzle", data_tools.rate_current))
	page.add_child(_button("Back to our happy place", show_home))

func show_players() -> void :
	_clear_page()
	screen_name = "players"
	_header("PLAYERS ON THIS DEVICE")
	page.add_child(_label("Hello, puzzle pal!", 44))
	page.add_child(_label("Up to 8 local players. Each has their own progress and records.", 23, MUTED))
	var name_input: = LineEdit.new()
	name_input.name = "PlayerName"
	name_input.placeholder_text = "Player name"
	name_input.max_length = 18
	name_input.custom_minimum_size.y = 88
	name_input.add_theme_font_size_override("font_size", 28)
	name_input.add_theme_color_override("font_color", INK)
	name_input.add_theme_color_override("font_placeholder_color", MUTED)
	name_input.add_theme_stylebox_override("normal", _style(PAPER))
	name_input.add_theme_stylebox_override("focus", _style(PAPER, 26, Look.PURPLE))
	page.add_child(name_input)
	var message: = _label("Choose a player, or enter a name above.", 21, MUTED)
	var actions: = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.add_child(_button("Add player", _add_player.bind(name_input, message), true))
	actions.add_child(_button("Rename current", _rename_player.bind(name_input, message)))
	page.add_child(actions)
	page.add_child(message)
	page.add_child(_button("Choose my sticker avatar", show_album))
	for player in records.players:
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_avatar(player.journey.avatar, Vector2(74, 74)))
		row.add_child(_button(("Selected: " if player.id == records.active_id else "Play as: ") + player.name, _select_player.bind(player.id), player.id == records.active_id))
		page.add_child(row)
	page.add_child(_button("Back to collection", show_home))

func _add_player(input: LineEdit, message: Label) -> void :
	if records.add_player(input.text).is_empty():
		message.text = "Use a unique name (1-18 characters). Up to 8 players can be saved."
		return
	progress = records.current().progress
	_save_progress()
	show_home()

func _rename_player(input: LineEdit, message: Label) -> void :
	if not records.rename_current(input.text):
		message.text = "Choose a unique name with 1-18 characters."
		return
	_save_progress()
	show_players()

func _select_player(id: String) -> void :
	if records.select_player(id):
		progress = records.current().progress
		_save_progress()
		show_home()

func show_rankings(game_mode: String = "all") -> void :
	_clear_page()
	screen_name = "rankings"
	_header("LOCAL PLAYER RANKINGS")
	page.add_child(_label("Our little hall of happy.", 40))
	page.add_child(_label("Best score per level counts once. Ties use levels solved, then total best times.", 22, MUTED))
	var filters: = HBoxContainer.new()
	filters.add_theme_constant_override("separation", 12)
	for key in ["all", "parcel", "block"]:
		filters.add_child(_button({"all": "All games", "parcel": "Parcel", "block": "Block"}[key], show_rankings.bind(key), key == game_mode))
	page.add_child(filters)
	for row in records.ranking(game_mode):
		var panel: = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color("f0e8fb") if row.id == records.active_id else PAPER, 28, Color("c7b0e1") if row.id == records.active_id else Color("e7dfee")))
		var line: = HBoxContainer.new()
		line.add_theme_constant_override("separation", 16)
		var avatar = _avatar(row.avatar, Vector2(74, 74), int(row.rank) - 1)
		line.add_child(avatar)
		var contents: = VBoxContainer.new()
		contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var place: = "#%d" % row.rank if row.completed > 0 else "--"
		contents.add_child(_label("%s   %s%s" % [place, row.name, "  (you)" if row.id == records.active_id else ""], 27))
		contents.add_child(_label("%d points   /   Levels scored: %d" % [row.score, row.completed], 22, Look.PURPLE))
		contents.add_child(_label("Total best times: " + SolveClock.format_time(int(row.time_ms)), 20, MUTED))
		line.add_child(contents)
		panel.add_child(line)
		page.add_child(panel)
	page.add_child(_label("Rankings are saved on this phone. Scores reward speed and efficient moves; undo has a penalty.", 21, MUTED))
	page.add_child(_button("Switch player", show_players))
	page.add_child(_button("Back to collection", show_home))

func _add_daily_card() -> void :
	var panel: = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("fff5df"), 26, Color("efddb0")))
	var contents: = VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	contents.add_child(_label("Today's little joy   /   " + today(), 22, INK))
	var buttons: = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	for game_mode in ["parcel", "block"]:
		var best: Dictionary = records.best_daily(today(), game_mode)
		var title: = "Parcel" if game_mode == "parcel" else "Block"
		var text: = title + (" / Best %d" % best.high_score if not best.is_empty() else " daily >")
		var button: = _button(text, open_daily.bind(game_mode))
		button.custom_minimum_size.y = 72
		button.add_theme_font_size_override("font_size", 21)
		buttons.add_child(button)
	contents.add_child(buttons)
	panel.add_child(contents)
	page.add_child(panel)

func open_daily(game_mode: String) -> void :
	var day: = today()
	var key: = Session.key("daily", game_mode)
	var pending: Dictionary = records.current().sessions.get(key, {})
	if not pending.is_empty() and pending.get("day") == day:
		resume_saved(key)
		return
	records.current().sessions.erase(key)
	start_level(game_mode, Daily.level_for(day, game_mode, levels[game_mode].size()), "daily", day)

func _stash_session() -> void :
	if screen_name != "game" or rules == null or board == null or run_kind == "tutorial" or rules.won():
		return
	solve_clock.tick(Time.get_ticks_msec())
	var key: = Session.key(run_kind, mode)
	var selected: int = board.selected if mode == "block" else -1
	records.current().sessions[key] = Session.snapshot(mode, level_index, run_kind, run_date, int(levels[mode][level_index].seed), active_actions, solve_clock.elapsed_ms, attempt_moves, undo_count, selected)
	_last_autosave = Time.get_ticks_msec()
	_save_progress()

func resume_saved(key: String) -> void :
	var data: Dictionary = records.current().sessions.get(key, {})
	var restored: = Session.restore(data, levels)
	if restored.is_empty():
		records.current().sessions.erase(key)
		_save_progress()
		if key.begins_with("daily_"):
			open_daily(key.trim_prefix("daily_"))
		else:
			start_level(key, int(progress["last_" + key]))
		return
	start_level(restored.mode, restored.level, restored.kind, restored.day)
	rules = restored.rules
	board.rules = rules
	board.selected = restored.selected
	active_actions = restored.actions
	attempt_moves = restored.moves
	undo_count = restored.undos
	solve_clock.start(Time.get_ticks_msec())
	solve_clock.elapsed_ms = restored.elapsed_ms
	if _app_suspended or _app_unfocused:
		solve_clock.pause(Time.get_ticks_msec())
	_settings_return = ""
	status_label.text = "Right where you left your pals. Welcome back!"
	board.queue_redraw()
	_refresh()
	_stash_session()

func _show_lesson_complete() -> void :
	_clear_page()
	screen_name = "result"
	_header("READY, PUZZLE PAL?")
	page.add_child(_art("victory", Vector2(0, 160)))
	page.add_child(_label("You've got the hang of it!", 40, Look.PURPLE))
	page.add_child(_label("Practice complete. Play a regular puzzle to start collecting scores and personal bests.", 24, MUTED))
	page.add_child(_button("Let's play for real >", start_level.bind(mode, 0), true))
	page.add_child(_button("Learn the other game", start_tutorial.bind("block" if mode == "parcel" else "parcel")))
	page.add_child(_button("Back to our happy place", show_home))

func show_settings() -> void :
	if screen_name != "settings":
		_settings_return = Session.key(run_kind, mode) if screen_name == "game" and run_kind != "tutorial" else ""
		_settings_lesson = mode if screen_name == "game" and run_kind == "tutorial" else ""
	_clear_page()
	screen_name = "settings"
	_header("YOUR COZY SETTINGS")
	page.add_child(_label("Make yourself comfy.", 42))
	page.add_child(_label("Gentle chimes and a tiny happy buzz. Choose what feels right for you.", 23, MUTED))
	page.add_child(_button("Sound: " + ("On" if records.settings.sound else "Off"), _toggle_setting.bind("sound"), records.settings.sound))
	page.add_child(_button("Vibration: " + ("On" if records.settings.vibration else "Off"), _toggle_setting.bind("vibration"), records.settings.vibration))
	page.add_child(_button("Reduced motion: " + ("On" if records.settings.reduced_motion else "Off"), _toggle_setting.bind("reduced_motion"), records.settings.reduced_motion))
	page.add_child(_button("Number symbols: " + ("On" if records.settings.clear_symbols else "Off"), _toggle_setting.bind("clear_symbols"), records.settings.clear_symbols))
	page.add_child(_button("Move goals: " + ("On" if records.settings.move_goals else "Off"), _toggle_setting.bind("move_goals"), records.settings.move_goals))
	page.add_child(_label("Move goals use a verified solution, not a proven minimum. They never change scores or rewards.", 21, MUTED))
	page.add_child(_label("Reduced motion keeps pals still. Number symbols match parcels, pals and gates using 1 to 4.", 21, MUTED))
	page.add_child(_button("Preview my settings", _preview_feedback))
	page.add_child(_label("Vibration depends on your phone and its system settings. Your choices are saved for everyone on this device.", 21, MUTED))
	page.add_child(_button("Backups & playtest notes", data_tools.show_page))
	if not _settings_return.is_empty():
		page.add_child(_button("Back to my puzzle", resume_saved.bind(_settings_return), true))
	elif not _settings_lesson.is_empty():
		page.add_child(_button("Restart my lesson", start_tutorial.bind(_settings_lesson), true))
	page.add_child(_button("Back to our happy place", show_home))

func _toggle_setting(key: String) -> void :
	records.settings[key] = not records.settings[key]
	feedback.configure(records.settings)
	_save_progress()
	show_settings()

func _preview_feedback() -> void :
	feedback.play("deliver")

func _load_progress() -> void :
	var saved: = Store.load_data(save_path)
	records.restore(saved, _level_counts())
	progress = records.current().progress
	if saved.get("version", 0) != 4:
		_save_progress()

func _save_progress() -> void :
	if not Store.save_data(save_path, records.to_data()):
		push_warning("Local progress could not be saved")
