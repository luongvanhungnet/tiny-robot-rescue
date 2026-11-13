extends Node
const Backup = preload("res://game/backup.gd")
const Playtest = preload("res://game/playtest.gd")
const Store = preload("res://game/save_store.gd")
const Look = preload("res://ui/friendly_theme.gd")
var reports = Playtest.new()
var host
var picker: FileDialog
var confirmation: ConfirmationDialog
var pending: Dictionary = {}
var context: Dictionary = {}
var return_key: = ""
var message: = ""

func _ready() -> void :
	host = get_parent()
	reports.restore(Store.load_data(report_path()), host.levels)

func report_path() -> String:
	return host.save_path + ".feedback"

func show_page() -> void :
	if host.screen_name in ["game", "result"] or (host.screen_name == "settings" and not host._settings_return.is_empty()):
		context = {"mode": host.mode, "level": host.level_index, "kind": host.run_kind, "day": host.run_date} if host.run_kind != "tutorial" else {}
		return_key = host._settings_return if host.screen_name == "settings" else host.Session.key(host.run_kind, host.mode) if host.screen_name == "game" and host.run_kind != "tutorial" else ""
	host._clear_page()
	host.screen_name = "data_tools"
	host._header("YOUR DATA, YOUR CHOICE")
	host.page.add_child(host._label("Keep your little treasures.", 36))
	host.page.add_child(host._label("Backups contain all local player names, scores, stickers, settings and unfinished puzzles. Keep them somewhere private.", 22, Look.MUTED))
	host.page.add_child(host._button("Export my backup", _pick.bind("backup"), true))
	host.page.add_child(host._button("Restore a backup", _pick.bind("restore")))
	var recovery = host._button("Recover save from before last restore", _recover)
	recovery.disabled = not FileAccess.file_exists(host.save_path + ".before-restore")
	host.page.add_child(recovery)
	host.page.add_child(host._label("Optional playtest notes", 29))
	host.page.add_child(host._button("Playtest feedback: " + ("On" if host.records.settings.playtest_feedback else "Off"), _toggle_feedback, host.records.settings.playtest_feedback))
	host.page.add_child(host._label("Nothing is recorded until you submit a rating. Notes stay on this device until you export them. No profile names, scores or identifiers are added; notes contain what you type.", 21, Look.MUTED))
	if not context.is_empty():
		host.page.add_child(host._button("Rate %s level %d" % ["Parcel" if context.mode == "parcel" else "Block", context.level + 1], show_rating))
	var counts: = reports.summary()
	host.page.add_child(host._label("%d notes / Easy %d / Hard %d / Confusing %d / Right %d" % [reports.entries.size(), counts.easy, counts.hard, counts.confusing, counts.right], 20, Look.MUTED))
	var buttons: = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var export_button = host._button("Export notes", _pick.bind("reports"))
	export_button.disabled = reports.entries.is_empty()
	buttons.add_child(export_button)
	var clear_button = host._button("Clear notes", _clear_reports)
	var backup_entries: Variant = Store.load_data(report_path() + ".bak").get("entries", [])
	clear_button.disabled = reports.entries.is_empty() and not (backup_entries is Array and not backup_entries.is_empty())
	buttons.add_child(clear_button)
	host.page.add_child(buttons)
	if not message.is_empty():
		host.page.add_child(host._label(message, 22, Look.PURPLE))
	host.page.add_child(host._button("Back to my puzzle" if not return_key.is_empty() else "< Home", _back))

func show_rating() -> void :
	if context.is_empty():
		return
	host._clear_page()
	host.screen_name = "rating"
	host._header("HOW DID THAT PUZZLE FEEL?")
	host.page.add_child(host._label("%s level %d" % ["Parcel Sort" if context.mode == "parcel" else "Block Exit", context.level + 1], 36))
	if not host.records.settings.playtest_feedback:
		host.page.add_child(host._label("Playtest feedback is off. Enable it to save a rating on this device. Nothing will be sent automatically.", 23, Look.MUTED))
		host.page.add_child(host._button("Enable local feedback", _enable_feedback, true))
	else:
		host.page.add_child(host._label("Choose how it felt. Re-rating replaces your last note for this puzzle. All players on this device share these notes.", 23, Look.MUTED))
		var note: = LineEdit.new()
		note.name = "PlaytestNote"
		note.max_length = 240
		note.placeholder_text = "Optional note; please leave out personal details"
		note.custom_minimum_size.y = 88
		note.add_theme_font_size_override("font_size", 23)
		note.add_theme_color_override("font_color", Look.INK)
		note.add_theme_color_override("font_placeholder_color", Look.MUTED)
		note.add_theme_stylebox_override("normal", host._style(Look.PAPER))
		host.page.add_child(note)
		for rating in Playtest.RATINGS:
			host.page.add_child(host._button(Playtest.RATINGS[rating], _submit.bind(rating, note)))
	host.page.add_child(host._button("< Back", show_page))

func rate_current() -> void :
	context = {"mode": host.mode, "level": host.level_index, "kind": host.run_kind, "day": host.run_date}
	return_key = ""
	show_rating()

func _enable_feedback() -> void :
	host.records.settings.playtest_feedback = true
	host._save_progress()
	show_rating()

func _toggle_feedback() -> void :
	host.records.settings.playtest_feedback = not host.records.settings.playtest_feedback
	host._save_progress()
	show_page()

func _submit(rating: String, note: LineEdit) -> void :
	if not host.records.settings.playtest_feedback or context.is_empty():
		return
	var before: = reports.to_data()
	if reports.submit(context.mode, context.level, host.levels, context.kind, context.day, rating, note.text) and Store.save_data(report_path(), reports.to_data()):
		message = "Saved on this device. Thank you for helping the pals!"
	else:
		reports.restore(before, host.levels)
		message = "The note could not be saved. Please try again."
	show_page()

func _pick(action: String) -> void :
	if is_instance_valid(picker):
		return
	if OS.has_feature("android") and not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		message = "A system file picker is unavailable on this device. Your data is unchanged."
		show_page()
		return
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action == "restore" else FileDialog.FILE_MODE_SAVE_FILE
	picker.filters = PackedStringArray(["*.json;PocketPuzzle JSON;application/json"])
	picker.deleting_enabled = false
	if action != "restore":
		picker.current_file = "PocketPuzzle-%s-%s.json" % ["backup" if action == "backup" else "playtest", Time.get_date_string_from_system()]
	picker.file_selected.connect(_selected.bind(action))
	picker.canceled.connect(_close_picker)
	add_child(picker)
	picker.popup_centered_clamped(Vector2i(640, 760), 0.9)

func _close_picker() -> void :
	if is_instance_valid(picker):
		picker.hide()
		picker.queue_free()
		picker = null

func _selected(path: String, action: String) -> void :
	_close_picker()
	if action == "restore":
		preview_restore(path)
		return

	var local_path: = ProjectSettings.globalize_path(path).simplify_path().to_lower()
	var private_root: = OS.get_user_data_dir().simplify_path().to_lower().trim_suffix("/")
	var resource_root: = ProjectSettings.globalize_path("res://").simplify_path().to_lower().trim_suffix("/")
	if not path.begins_with("content://") and (local_path.begins_with(private_root + "/") or local_path.begins_with(resource_root + "/")):
		message = "Choose a location outside this app's private save and project folders."
	else:
		var text: = Backup.encode(host.records.to_data()) if action == "backup" else JSON.stringify(reports.to_data(), "  ")
		message = "File exported. Share it only if you choose." if Backup.write_text(path, text) else "The file could not be written. Please choose another location."
	show_page()

func preview_restore(path: String) -> void :
	pending = Backup.read(path, host.levels)
	if pending.has("error"):
		message = pending.error
		pending = {}
		show_page()
		return
	_confirm("Restore this backup?\n\n%d players / %d completions / %d unfinished games.\nThis replaces all local profiles and settings. A recovery copy is kept. Playtest notes stay on this device." % [pending.players, pending.completed, pending.sessions], _perform_restore)

func _perform_restore() -> void :
	if pending.has("data") and Backup.restore(host.save_path, host.records.to_data(), pending.data, host.levels):
		host.records.restore(pending.data, host._level_counts())
		host.progress = host.records.current().progress
		host.feedback.configure(host.records.settings)
		pending = {}
		context = {}
		return_key = ""
		message = "Backup restored. Your previous local save is available under Recover."
	else:
		message = "Restore could not be completed. Your current save is unchanged."
	show_page()

func _recover() -> void :
	preview_restore(host.save_path + ".before-restore")

func _clear_reports() -> void :
	_confirm("Clear all playtest notes?\n\nThis removes the notes stored on this device. Exported files and game progress are unaffected.", _delete_reports, "Clear notes")

func _delete_reports() -> void :
	var empty: = {"format": "PocketPuzzlePlaytest", "version": 1, "game_version": "0.9.0", "entries": []}
	if Store.save_data(report_path(), empty) and Store.save_data(report_path(), empty):
		reports.entries = []
		message = "Local playtest notes cleared."
	else:
		message = "Some local copies could not be cleared. Please try Clear notes again."
	show_page()

func _confirm(text: String, action: Callable, action_label: = "Restore") -> void :
	if is_instance_valid(confirmation):
		return
	confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = text
	confirmation.ok_button_text = action_label
	confirmation.borderless = true
	confirmation.transparent_bg = true
	confirmation.exclusive = true
	confirmation.theme = host.theme.duplicate()
	confirmation.theme.default_font_size = 23
	confirmation.add_theme_constant_override("buttons_min_height", 80)
	confirmation.add_theme_constant_override("buttons_min_width", 180)
	confirmation.add_theme_stylebox_override("panel", host._style(Look.PAPER, 26, Color("d8c7ed")))
	confirmation.get_label().add_theme_color_override("font_color", Look.INK)
	confirmation.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation.get_label().custom_minimum_size = Vector2(480, 220)
	for button in [confirmation.get_ok_button(), confirmation.get_cancel_button()]:
		var primary: bool = button == confirmation.get_ok_button()
		button.add_theme_font_override("font", Look.bold_font())
		button.add_theme_stylebox_override("normal", host._style(Look.PURPLE if primary else Color("eee5fa")))
		button.add_theme_stylebox_override("hover", host._style(Look.PURPLE.lightened(0.1) if primary else Color("e5d8f5")))
		button.add_theme_stylebox_override("pressed", host._style(Look.PURPLE.darkened(0.1) if primary else Color("dbc9ef")))
		button.add_theme_stylebox_override("focus", Look.box(Color.TRANSPARENT, 26, Look.PURPLE))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Look.PAPER if primary else Look.INK)
	confirmation.confirmed.connect( func(): _close_confirmation(true);action.call())
	confirmation.canceled.connect(_close_confirmation)
	add_child(confirmation)
	confirmation.popup_centered(Vector2i(560, 380))

func _close_confirmation(keep_pending: = false) -> void :
	if is_instance_valid(confirmation):
		confirmation.hide()
		confirmation.queue_free()
		confirmation = null
	if not keep_pending:
		pending = {}

func _back() -> void :
	context = {}
	message = ""
	if not return_key.is_empty():
		var key: = return_key
		return_key = ""
		host.resume_saved(key)
	else:
		host.show_home()

func handle_back() -> bool:
	if is_instance_valid(picker):
		_close_picker()
		return true
	if is_instance_valid(confirmation):
		_close_confirmation()
		pending = {}
		return true
	if host.screen_name == "rating":
		show_page()
		return true
	if host.screen_name == "data_tools":
		_back()
		return true
	return false
