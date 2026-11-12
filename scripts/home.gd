extends Control

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")

@onready var stars_lbl: Label = $TopStats/StarsLabel
@onready var bolts_lbl: Label = $TopStats/BoltsLabel
@onready var preview_anchor: Node2D = $RobotPreviewAnchor
@onready var play_btn: Button = $CenterBox/PlayButton
@onready var levels_btn: Button = $CenterBox/LevelsButton
@onready var hangar_btn: Button = $CenterBox/HangarButton
@onready var shop_btn: Button = $CenterBox/ShopButton
@onready var settings_btn: Button = $CenterBox/SettingsButton
@onready var modal_panel: PanelContainer = $ModalPanel
@onready var modal_title: Label = $ModalPanel/VBox/Title
@onready var modal_body: VBoxContainer = $ModalPanel/VBox/Scroll/Body
@onready var modal_close: Button = $ModalPanel/VBox/CloseButton

var _status_label: Label = null
var _play_level_id: int = 1
var _preview_robot: RobotController = null

func _ready() -> void:
	_apply_styles()
	_refresh_header_stats()
	_spawn_preview_robot()
	
	_play_level_id = clampi(int(ProgressSave.data.get("last_selected_level", GameManager.current_level_id)), 1, GameManager.TOTAL_LEVELS)
	GameManager.current_level_id = _play_level_id
	play_btn.text = "PLAY LEVEL %d" % _play_level_id
	play_btn.pressed.connect(func(): GameManager.start_level(_play_level_id))
	levels_btn.pressed.connect(func(): GameManager.go_level_select())
	hangar_btn.pressed.connect(_open_hangar)
	shop_btn.pressed.connect(_open_shop)
	settings_btn.pressed.connect(_open_settings)
	modal_close.pressed.connect(func(): modal_panel.visible = false)
	modal_panel.visible = false
	
	BillingAdapter.purchase_succeeded.connect(_on_purchase_succeeded)
	BillingAdapter.purchase_failed.connect(_on_purchase_failed)
	BillingAdapter.purchases_restored.connect(_on_purchases_restored)
	
	if ConsentManager.needs_consent_prompt():
		_open_consent_prompt()

func _exit_tree() -> void:
	if BillingAdapter.purchase_succeeded.is_connected(_on_purchase_succeeded):
		BillingAdapter.purchase_succeeded.disconnect(_on_purchase_succeeded)
	if BillingAdapter.purchase_failed.is_connected(_on_purchase_failed):
		BillingAdapter.purchase_failed.disconnect(_on_purchase_failed)
	if BillingAdapter.purchases_restored.is_connected(_on_purchases_restored):
		BillingAdapter.purchases_restored.disconnect(_on_purchases_restored)

func _apply_styles() -> void:
	UIThemeHelper.style_button(play_btn, Color("#16a34a"), Color("#14532d"))
	UIThemeHelper.style_button(levels_btn, Color("#0284c7"), Color("#0c4a6e"))
	UIThemeHelper.style_button(hangar_btn, Color("#7c3aed"), Color("#4c1d95"))
	UIThemeHelper.style_button(shop_btn, Color("#d97706"), Color("#78350f"))
	UIThemeHelper.style_button(settings_btn, Color("#334155"), Color("#0f172a"))
	UIThemeHelper.style_button(modal_close, Color("#475569"), Color("#1e293b"))

func _refresh_header_stats() -> void:
	stars_lbl.text = "STARS: %d / 180" % ProgressSave.get_total_stars()
	bolts_lbl.text = "BOLTS: %d" % ProgressSave.get_bolts()

func _spawn_preview_robot() -> void:
	for c in preview_anchor.get_children():
		c.queue_free()
	var shield := Line2D.new()
	shield.points = PackedVector2Array([Vector2(-70, -45), Vector2(0, -82), Vector2(70, -45)])
	shield.width = 10.0
	shield.default_color = Color("#38bdf8", 0.85)
	shield.joint_mode = Line2D.LINE_JOINT_ROUND
	shield.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shield.end_cap_mode = Line2D.LINE_CAP_ROUND
	preview_anchor.add_child(shield)
	
	_preview_robot = ROBOT_SCENE.instantiate() as RobotController
	_preview_robot.freeze = true
	_preview_robot.scale = Vector2(1.4, 1.4)
	_preview_robot.skin_id = ProgressSave.get_selected_skin()
	preview_anchor.add_child(_preview_robot)

func _clear_modal_body() -> void:
	_status_label = null
	for child in modal_body.get_children():
		child.queue_free()

func _add_status_label() -> void:
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color("#38bdf8"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(_status_label)

func _set_status(msg: String) -> void:
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = msg

func _on_purchase_succeeded(_product_id: String) -> void:
	_set_status("Purchase active! Thank you.")

func _on_purchase_failed(_product_id: String, reason: String) -> void:
	if reason == "billing_unavailable_offline":
		_set_status("Google Play Billing is unavailable offline.")
	else:
		_set_status("Purchase unavailable: " + reason)

func _on_purchases_restored(entitlements: Array) -> void:
	if entitlements.is_empty():
		_set_status("No previous purchases found (offline).")
	else:
		_set_status("Restored purchases successfully!")

func _on_equip_skin_pressed(sid: String) -> void:
	ProgressSave.select_skin(sid)
	_spawn_preview_robot()
	_open_hangar()

func _on_buy_skin_pressed(sid: String, cost: int, unlock_lvl: int) -> void:
	if ProgressSave.buy_skin_with_bolts(sid):
		_refresh_header_stats()
		_spawn_preview_robot()
		_open_hangar()
	else:
		_set_status("Need %d Bolts (or complete Level %d)!" % [cost, unlock_lvl])

func _open_hangar() -> void:
	_clear_modal_body()
	modal_title.text = "Robot Hangar (%d Bolts)" % ProgressSave.get_bolts()
	modal_close.visible = true
	
	var selected: String = ProgressSave.get_selected_skin()
	for skin in ProgressSave.SKIN_CATALOG:
		var sid: String = str(skin["id"])
		var sname: String = str(skin["name"])
		var sdesc: String = str(skin["desc"])
		var cost: int = int(skin["cost"])
		var unlock_lvl: int = int(skin["unlock_level"])
		var unlocked: bool = ProgressSave.is_skin_unlocked(sid)
		
		var lbl: Label = Label.new()
		lbl.text = "%s — %s" % [sname, sdesc]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_body.add_child(lbl)
		
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 18)
		if sid == selected:
			btn.text = "EQUIPPED"
			btn.disabled = true
			UIThemeHelper.style_button(btn, Color("#16a34a"), Color("#14532d"))
		elif unlocked:
			btn.text = "EQUIP"
			UIThemeHelper.style_button(btn, Color("#0284c7"), Color("#0c4a6e"))
			btn.pressed.connect(_on_equip_skin_pressed.bind(sid))
		else:
			btn.text = "UNLOCK: %d Bolts / Lv.%d" % [cost, unlock_lvl]
			UIThemeHelper.style_button(btn, Color("#d97706"), Color("#78350f"))
			btn.pressed.connect(_on_buy_skin_pressed.bind(sid, cost, unlock_lvl))
		modal_body.add_child(btn)
	
	_add_status_label()
	modal_panel.visible = true

func _open_settings() -> void:
	_clear_modal_body()
	modal_title.text = "Settings"
	modal_close.visible = true
	
	var sound_chk := CheckButton.new()
	sound_chk.text = "Sound Effects"
	sound_chk.button_pressed = bool(ProgressSave.data["settings"].get("sound_enabled", true))
	sound_chk.toggled.connect(func(on: bool):
		ProgressSave.data["settings"]["sound_enabled"] = on
		ProgressSave.save_now()
	)
	modal_body.add_child(sound_chk)
	
	var music_chk := CheckButton.new()
	music_chk.text = "Background Music"
	music_chk.button_pressed = bool(ProgressSave.data["settings"].get("music_enabled", true))
	music_chk.toggled.connect(func(on: bool):
		ProgressSave.data["settings"]["music_enabled"] = on
		ProgressSave.save_now()
		GameManager.refresh_music_state()
	)
	modal_body.add_child(music_chk)
	
	var vib_chk := CheckButton.new()
	vib_chk.text = "Haptic Vibration"
	vib_chk.button_pressed = bool(ProgressSave.data["settings"].get("vibration_enabled", true))
	vib_chk.toggled.connect(func(on: bool):
		ProgressSave.data["settings"]["vibration_enabled"] = on
		ProgressSave.save_now()
	)
	modal_body.add_child(vib_chk)
	
	var motion_chk := CheckButton.new()
	motion_chk.text = "Reduced Motion"
	motion_chk.button_pressed = bool(ProgressSave.data["settings"].get("reduced_motion", false))
	motion_chk.toggled.connect(func(on: bool):
		ProgressSave.data["settings"]["reduced_motion"] = on
		ProgressSave.save_now()
	)
	modal_body.add_child(motion_chk)
	
	var cap_chk := CheckButton.new()
	cap_chk.text = "Clean Capture Mode (TikTok Clips)"
	cap_chk.button_pressed = bool(ProgressSave.data["settings"].get("clean_capture_mode", false))
	cap_chk.toggled.connect(func(on: bool):
		ProgressSave.data["settings"]["clean_capture_mode"] = on
		ProgressSave.save_now()
	)
	modal_body.add_child(cap_chk)
	
	var restore_btn := Button.new()
	restore_btn.text = "Restore Purchases"
	UIThemeHelper.style_button(restore_btn, Color("#0284c7"), Color("#0c4a6e"))
	restore_btn.pressed.connect(func(): BillingAdapter.restore_purchases())
	modal_body.add_child(restore_btn)
	
	var priv_btn := Button.new()
	priv_btn.text = "Privacy & Ad Preferences"
	UIThemeHelper.style_button(priv_btn, Color("#334155"), Color("#0f172a"))
	priv_btn.pressed.connect(_open_consent_prompt)
	modal_body.add_child(priv_btn)
	
	var credits_btn := Button.new()
	credits_btn.text = "Privacy Policy & Credits"
	UIThemeHelper.style_button(credits_btn, Color("#334155"), Color("#0f172a"))
	credits_btn.pressed.connect(_open_privacy_and_credits)
	modal_body.add_child(credits_btn)
	
	_add_status_label()
	modal_panel.visible = true

func _open_privacy_and_credits() -> void:
	_clear_modal_body()
	modal_title.text = "Privacy & Credits"
	modal_close.visible = true
	var info := Label.new()
	info.text = "Tiny Robot Rescue v1.0\n\nOffline Save Notice:\nAll progress and settings are stored locally on your device. Uninstalling or clearing app data may erase offline progress.\n\nPrivacy Policy:\nNo personal data is collected in offline gameplay. Optional ads and Google Play Billing use platform SDKs only when enabled with your consent.\n\nCredits:\nOriginal 2D Physics Puzzle & Procedural Art/Audio — Tiny Robot Rescue."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(info)
	modal_panel.visible = true

func _open_consent_prompt() -> void:
	_clear_modal_body()
	modal_title.text = "Privacy & Offline Play"
	modal_close.visible = false
	
	var msg := Label.new()
	msg.text = "Tiny Robot Rescue works 100% offline with local saves. Choose your optional ad/analytics preference below (you can change this anytime in Settings):"
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(msg)
	
	var offline_btn := Button.new()
	offline_btn.custom_minimum_size = Vector2(0, 52)
	offline_btn.text = "Play Offline / Non-Personalized"
	UIThemeHelper.style_button(offline_btn, Color("#0284c7"), Color("#0c4a6e"))
	offline_btn.pressed.connect(func():
		ConsentManager.set_consent(false, false)
		modal_close.visible = true
		modal_panel.visible = false
	)
	modal_body.add_child(offline_btn)
	
	var allow_btn := Button.new()
	allow_btn.custom_minimum_size = Vector2(0, 52)
	allow_btn.text = "Allow Optional Ads & Analytics"
	UIThemeHelper.style_button(allow_btn, Color("#16a34a"), Color("#14532d"))
	allow_btn.pressed.connect(func():
		ConsentManager.set_consent(true, true)
		modal_close.visible = true
		modal_panel.visible = false
	)
	modal_body.add_child(allow_btn)
	modal_panel.visible = true

func _open_shop() -> void:
	_clear_modal_body()
	modal_title.text = "Shop"
	modal_close.visible = true
	
	var info := Label.new()
	if ProgressSave.has_remove_ads():
		info.text = "Remove Interstitial Ads: OWNED\nAll optional between-level interstitial ads are permanently disabled."
	else:
		info.text = "Remove Interstitial Ads ($1.99)\nRemoves optional between-level interstitial ads permanently.\n(Optional rewarded hints remain completely optional.)"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(info)
	
	if not ProgressSave.has_remove_ads():
		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(0, 54)
		buy_btn.text = "Purchase via Google Play"
		UIThemeHelper.style_button(buy_btn, Color("#d97706"), Color("#78350f"))
		buy_btn.pressed.connect(func(): BillingAdapter.purchase_remove_ads())
		modal_body.add_child(buy_btn)
	
	_add_status_label()
	modal_panel.visible = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if modal_panel.visible and modal_close.visible:
			modal_panel.visible = false
		else:
			get_tree().quit()
