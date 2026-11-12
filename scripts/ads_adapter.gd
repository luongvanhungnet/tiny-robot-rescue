extends Node

signal rewarded_ad_completed(placement_id: String)
signal rewarded_ad_failed(placement_id: String, reason: String)
signal interstitial_closed

const MIN_LEVEL_FOR_INTERSTITIAL := 4 # Never show during tutorial levels 1-3
const INTERSTITIAL_LEVEL_INTERVAL := 4
const INTERSTITIAL_MIN_GAP_SEC := 90.0

var test_mode: bool = true
var progress_save_override: Node = null
var consent_override: Node = null
var _levels_since_interstitial: int = 0
var _last_interstitial_time: float = -999.0
var _granted_reward_tokens: Dictionary = {}

func _get_ps() -> Node:
	if progress_save_override != null:
		return progress_save_override
	return get_node_or_null("/root/ProgressSave") if is_inside_tree() else null

func _get_cm() -> Node:
	if consent_override != null:
		return consent_override
	return get_node_or_null("/root/ConsentManager") if is_inside_tree() else null

func is_interstitial_ready(level_id: int) -> bool:
	var ps := _get_ps()
	if ps != null and ps.has_remove_ads():
		return false
	if level_id < MIN_LEVEL_FOR_INTERSTITIAL:
		return false
	if _levels_since_interstitial < INTERSTITIAL_LEVEL_INTERVAL:
		return false
	var now := Time.get_unix_time_from_system()
	if (now - _last_interstitial_time) < INTERSTITIAL_MIN_GAP_SEC:
		return false
	var cm := _get_cm()
	if cm == null:
		return false
	return cm.can_request_ads()

func record_level_completed() -> void:
	_levels_since_interstitial += 1

func show_interstitial_if_ready(level_id: int) -> bool:
	if not is_interstitial_ready(level_id):
		return false
	_levels_since_interstitial = 0
	_last_interstitial_time = Time.get_unix_time_from_system()
	if Engine.has_singleton("AdMob"):
		# Hook for Godot AdMob interstitial call in M7
		pass
	interstitial_closed.emit()
	return true

func is_rewarded_sdk_available() -> bool:
	return Engine.has_singleton("AdMob")

func show_rewarded_ad(placement_id: String, request_token: String = "") -> void:
	if request_token != "" and _granted_reward_tokens.has(request_token):
		rewarded_ad_failed.emit(placement_id, "duplicate_reward_token")
		return
	
	var cm := _get_cm()
	if (cm == null or not cm.can_request_ads()) and not test_mode:
		rewarded_ad_failed.emit(placement_id, "offline_or_no_consent")
		return
	
	if not is_rewarded_sdk_available():
		rewarded_ad_failed.emit(placement_id, "sdk_unavailable_offline")
		return
	
	if request_token != "":
		_granted_reward_tokens[request_token] = true
	var ps := _get_ps()
	if ps != null:
		ps.data["analytics_local"]["ads_watched"] = int(ps.data["analytics_local"].get("ads_watched", 0)) + 1
		ps.save_now()
	rewarded_ad_completed.emit(placement_id)
