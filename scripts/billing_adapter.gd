extends Node

signal purchase_succeeded(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal purchases_restored(entitlements: Array)

const PRODUCT_REMOVE_ADS := "remove_interstitial_ads"

var _processed_tokens: Dictionary = {}

func is_billing_available() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling")

func purchase_remove_ads() -> void:
	if ProgressSave.has_remove_ads():
		purchase_succeeded.emit(PRODUCT_REMOVE_ADS)
		return
	if not is_billing_available():
		purchase_failed.emit(PRODUCT_REMOVE_ADS, "billing_unavailable_offline")
		return
	# Real Play Billing integration hooks here in M7

func verify_and_grant_purchase(product_id: String, purchase_token: String) -> bool:
	if purchase_token == "":
		return false
	if _processed_tokens.has(purchase_token):
		return false
	_processed_tokens[purchase_token] = true
	if product_id == PRODUCT_REMOVE_ADS:
		ProgressSave.set_remove_ads(true)
		purchase_succeeded.emit(product_id)
		return true
	return false

func restore_purchases() -> void:
	if not is_billing_available():
		purchases_restored.emit([])
		return
	# Real Play Billing queryPurchases hooks here in M7
	var restored: Array = []
	if ProgressSave.has_remove_ads():
		restored.append(PRODUCT_REMOVE_ADS)
	purchases_restored.emit(restored)
