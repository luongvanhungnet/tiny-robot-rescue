extends Node

var consent_granted: bool = false
var personalized_ads_allowed: bool = false
var analytics_allowed: bool = false

func can_request_ads() -> bool:
	# In MVP offline mode, returns false unless explicitly enabled after consent
	return consent_granted

func set_consent(personalized: bool, analytics: bool) -> void:
	consent_granted = true
	personalized_ads_allowed = personalized
	analytics_allowed = analytics
