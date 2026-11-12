extends Control

@onready var play_btn: Button = $CenterBox/PlayButton
@onready var levels_btn: Button = $CenterBox/LevelsButton
@onready var settings_btn: Button = $CenterBox/SettingsButton
@onready var shop_btn: Button = $CenterBox/ShopButton
@onready var modal_panel: PanelContainer = $ModalPanel
@onready var modal_title: Label = $ModalPanel/VBox/Title
@onready var modal_body: VBoxContainer = $ModalPanel/VBox/Body
@onready var modal_close: Button = $ModalPanel/VBox/CloseButton

var _status_label: Label = null
var _play_level_id: int = 1

func _ready() -> void:
	_play_level_id = clampi(int(ProgressSave.data.get("last_selected_level", GameManager.current_level_id)), 1, GameManager.TOTAL_VERTICAL_SLICE_LEVELS)
	GameManager.current_level_id = _play_level_id
	play_btn.text = "PLAY LEVEL %d" % _play_level_id
	play_btn.pressed.connect(func(): GameManager.start_level(_play_level_id))
	levels_btn.pressed.connect(func(): GameManager.go_level_select())
	settings_btn.pressed.connect(_open_settings)
	shop_btn.pressed.connect(_open_shop)
	modal_close.pressed.connect(func(): modal_panel.visible = false)
	modal_panel.visible = false
	
	BillingAdapter.purchase_succeeded.connect(_on_purchase_succeeded)
	BillingAdapter.purchase_failed.connect(_on_purchase_failed)
	BillingAdapter.purchases_restored.connect(_on_purchases_restored)

func _exit_tree() -> void:
	if BillingAdapter.purchase_succeeded.is_connected(_on_purchase_succeeded):
		BillingAdapter.purchase_succeeded.disconnect(_on_purchase_succeeded)
	if BillingAdapter.purchase_failed.is_connected(_on_purchase_failed):
		BillingAdapter.purchase_failed.disconnect(_on_purchase_failed)
	if BillingAdapter.purchases_restored.is_connected(_on_purchases_restored):
		BillingAdapter.purchases_restored.disconnect(_on_purchases_restored)

func _clear_modal_body() -> void:
	_status_label = null
	for child in modal_body.get_children():
		child.queue_free()

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

func _open_settings() -> void:
	_clear_modal_body()
	modal_title.text = "Settings"
	
	var sound_chk := CheckButton.new()
	sound_chk.text = "Sound Effects"
	sound_chk.button_pressed = bool(ProgressSave.data["settings"].get("sound_enabled", true))
	sound_chk.toggled.connect(func(on: bool):
		ProgressSave.data["settings"]["sound_enabled"] = on
		ProgressSave.save_now()
	)
	modal_body.add_child(sound_chk)
	
	var motion_chk := CheckButton.new()
	motion_chk.text = "Reduced Motion"
	motion_chk.button_pressed = bool(ProgressSave.data["settings"].get("reduced_motion", false))
	motion_chk.toggled.connect(func(on: bool):
		ProgressSave.data["settings"]["reduced_motion"] = on
		ProgressSave.save_now()
	)
	modal_body.add_child(motion_chk)
	
	var restore_btn := Button.new()
	restore_btn.text = "Restore Purchases"
	restore_btn.pressed.connect(func(): BillingAdapter.restore_purchases())
	modal_body.add_child(restore_btn)
	
	var note := Label.new()
	note.text = "Offline progress is stored locally on this device."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(note)
	
	_status_label = Label.new()
	_status_label.theme_type_variation = &"Label"
	_status_label.add_theme_color_override("font_color", Color("#38bdf8"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(_status_label)
	
	modal_panel.visible = true

func _open_shop() -> void:
	_clear_modal_body()
	modal_title.text = "Shop"
	
	var info := Label.new()
	if ProgressSave.has_remove_ads():
		info.text = "Remove Interstitial Ads: OWNED"
	else:
		info.text = "Remove Interstitial Ads ($1.99)\nRemoves optional interstitial ads between levels."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(info)
	
	if not ProgressSave.has_remove_ads():
		var buy_btn := Button.new()
		buy_btn.text = "Purchase (Google Play)"
		buy_btn.pressed.connect(func(): BillingAdapter.purchase_remove_ads())
		modal_body.add_child(buy_btn)
	
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color("#38bdf8"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(_status_label)
	
	modal_panel.visible = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if modal_panel.visible:
			modal_panel.visible = false
		else:
			get_tree().quit()
