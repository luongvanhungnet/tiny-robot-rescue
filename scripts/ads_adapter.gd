extends Node

signal rewarded_ad_completed(placement_id: String)
signal rewarded_ad_failed(placement_id: String, reason: String)
signal interstitial_closed

const MIN_LEVEL_FOR_INTERSTITIAL := 4 # Never show during tutorial levels 1-3
const INTERSTITIAL_LEVEL_INTERVAL := 4
const INTERSTITIAL_MIN_GAP_SEC := 90.0

var test_mode: bool = true
var _levels_since_interstitial: int = 0
var _last_interstitial_time: float = -999.0
var _granted_reward_tokens: Dictionary = {}

func is_interstitial_ready(level_id: int) -> bool:
	if ProgressSave.has_remove_ads():
		return false
	if level_id < MIN_LEVEL_FOR_INTERSTITIAL:
		return false
	if _levels_since_interstitial < INTERSTITIAL_LEVEL_INTERVAL:
		return false
	var now := Time.get_unix_time_from_system()
	if (now - _last_interstitial_time) < INTERSTITIAL_MIN_GAP_SEC:
		return false
	return ConsentManager.can_request_ads()

func record_level_completed() -> void:
	_levels_since_interstitial += 1

func show_interstitial_if_ready(level_id: int) -> bool:
	if not is_interstitial_ready(level_id):
		return false
	_levels_since_interstitial = 0
	_last_interstitial_time = Time.get_unix_time_from_system()
	# In vertical slice / offline mode, no-op and emit closed immediately
	interstitial_closed.emit()
	return true

func show_rewarded_ad(placement_id: String, request_token: String = "") -> void:
	# Idempotency guard: never grant same reward token twice
	if request_token != "" and _granted_reward_tokens.has(request_token):
		rewarded_ad_failed.emit(placement_id, "duplicate_reward_token")
		return
	
	if not ConsentManager.can_request_ads() and not test_mode:
		rewarded_ad_failed.emit(placement_id, "offline_or_no_consent")
		return
	
	# Offline / test-mode fallback: if no SDK is attached, fail gracefully so free hint fallback can trigger
	if not Engine.has_singleton("AdMob"):
		rewarded_ad_failed.emit(placement_id, "sdk_unavailable_offline")
		return
	
	if request_token != "":
		_granted_reward_tokens[request_token] = true
	rewarded_ad_completed.emit(placement_id)
