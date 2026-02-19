extends Node

const STAGE_DEV: String = "dev"
const STAGE_PROD: String = "prod"
const DEV_USER_SERVICE_BASE_URL: String = "http://localhost:8080"
const PROD_USER_SERVICE_BASE_URL: String = "https://api.ironfront.live"
const DEFAULT_PGS_SERVER_CLIENT_ID: String = (
	"556532261549-5sfh8fmkgs232240dviunjr3e4kqeh8a" + ".apps.googleusercontent.com"
)

var stage: String = STAGE_DEV
var user_service_base_url: String = DEV_USER_SERVICE_BASE_URL
var pgs_server_client_id: String = ""


func _enter_tree() -> void:
	stage = _resolve_stage()
	user_service_base_url = _resolve_user_service_base_url()
	pgs_server_client_id = _resolve_pgs_server_client_id()


func _ready() -> void:
	print(
		(
			"[app-config] stage=%s user_service_base_url=%s pgs_server_client_id_set=%s"
			% [stage, user_service_base_url, not pgs_server_client_id.is_empty()]
		)
	)


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


func _resolve_pgs_server_client_id() -> String:
	var override_client_id: String = str(Env.get_env("pgs-server-client-id", "")).strip_edges()
	if not override_client_id.is_empty():
		return override_client_id
	return DEFAULT_PGS_SERVER_CLIENT_ID
