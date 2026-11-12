extends Node

signal consent_updated

var consent_granted: bool = false
var personalized_ads_allowed: bool = false
var analytics_allowed: bool = false

func _ready() -> void:
	sync_from_save()

func sync_from_save() -> void:
	var ps := get_node_or_null("/root/ProgressSave") if is_inside_tree() else null
	if ps != null and ps.data.has("privacy"):
		var priv: Dictionary = ps.data["privacy"]
		consent_granted = bool(priv.get("prompt_completed", false))
		personalized_ads_allowed = bool(priv.get("personalized_ads", false))
		analytics_allowed = bool(priv.get("analytics_allowed", false))

func needs_consent_prompt() -> bool:
	var ps := get_node_or_null("/root/ProgressSave") if is_inside_tree() else null
	if ps != null and ps.data.has("privacy"):
		return not bool(ps.data["privacy"].get("prompt_completed", false))
	return not consent_granted

func can_request_ads() -> bool:
	return consent_granted

func set_consent(personalized: bool, analytics: bool) -> void:
	consent_granted = true
	personalized_ads_allowed = personalized
	analytics_allowed = analytics
	var ps := get_node_or_null("/root/ProgressSave") if is_inside_tree() else null
	if ps != null:
		ps.data["privacy"]["prompt_completed"] = true
		ps.data["privacy"]["personalized_ads"] = personalized
		ps.data["privacy"]["analytics_allowed"] = analytics
		ps.save_now()
	consent_updated.emit()
