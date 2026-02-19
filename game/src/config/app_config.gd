extends Node

const STAGE_DEV: String = "dev"
const STAGE_PROD: String = "prod"
const DEV_USER_SERVICE_BASE_URL: String = "https://api-dev.ironfront.live"
const PROD_USER_SERVICE_BASE_URL: String = "https://api.ironfront.live"

var stage: String = STAGE_DEV
var user_service_base_url: String = DEV_USER_SERVICE_BASE_URL


func _ready() -> void:
	stage = _resolve_stage()
	user_service_base_url = _resolve_user_service_base_url()
	print("[app-config] stage=%s user_service_base_url=%s" % [stage, user_service_base_url])


func is_prod() -> bool:
	return stage == STAGE_PROD


func should_use_pgs_provider() -> bool:
	return is_prod() or OS.has_feature("android")


func _resolve_stage() -> String:
	var raw_stage: String = str(Env.get_env("stage", STAGE_DEV)).to_lower()
	if raw_stage == STAGE_PROD:
		return STAGE_PROD
	if raw_stage != STAGE_DEV:
		print("[app-config] invalid stage '%s', defaulting to %s" % [raw_stage, STAGE_DEV])
	return STAGE_DEV


func _resolve_user_service_base_url() -> String:
	var override_url: String = str(Env.get_env("user-service-url", ""))
	if not override_url.is_empty():
		return override_url.rstrip("/")
	return PROD_USER_SERVICE_BASE_URL if is_prod() else DEV_USER_SERVICE_BASE_URL
