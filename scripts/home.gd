extends Control

@onready var play_btn: Button = $CenterBox/PlayButton
@onready var levels_btn: Button = $CenterBox/LevelsButton
@onready var settings_btn: Button = $CenterBox/SettingsButton
@onready var shop_btn: Button = $CenterBox/ShopButton
@onready var modal_panel: PanelContainer = $ModalPanel
@onready var modal_title: Label = $ModalPanel/VBox/Title
@onready var modal_body: VBoxContainer = $ModalPanel/VBox/Body
@onready var modal_close: Button = $ModalPanel/VBox/CloseButton

func _ready() -> void:
	play_btn.text = "PLAY LEVEL %d" % GameManager.current_level_id
	play_btn.pressed.connect(func(): GameManager.start_level(GameManager.current_level_id))
	levels_btn.pressed.connect(func(): GameManager.go_level_select())
	settings_btn.pressed.connect(_open_settings)
	shop_btn.pressed.connect(_open_shop)
	modal_close.pressed.connect(func(): modal_panel.visible = false)
	modal_panel.visible = false

func _clear_modal_body() -> void:
	for child in modal_body.get_children():
		child.queue_free()

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
	
	modal_panel.visible = true
