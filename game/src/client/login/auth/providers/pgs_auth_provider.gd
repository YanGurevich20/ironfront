class_name PgsAuthProvider
extends AuthProvider

@export var server_client_id: String = ""
@export var force_refresh_token: bool = false

var _requesting_server_access: bool = false

@onready var sign_in_client: PlayGamesSignInClient = %PlayGamesSignInClient


func _enter_tree() -> void:
	_initialize_plugin_for_lifecycle()


func _ready() -> void:
	server_client_id = AppConfig.pgs_server_client_id
	Utils.connect_checked(sign_in_client.user_authenticated, _on_user_authenticated)
	Utils.connect_checked(
		sign_in_client.server_side_access_requested, _on_server_side_access_requested
	)


func sign_in() -> void:
	if _is_sign_in_in_progress:
		return
	if not _ensure_plugin_ready():
		sign_in_failed.emit("PGS_UNAVAILABLE")
		return
	if server_client_id.strip_edges().is_empty():
		sign_in_failed.emit("PGS_SERVER_CLIENT_ID_MISSING")
		return
	_set_sign_in_in_progress(true)
	_requesting_server_access = false
	sign_in_client.sign_in()


func sign_out() -> void:
	_set_sign_in_in_progress(false)
	_requesting_server_access = false
	sign_out_completed.emit()


func _on_user_authenticated(is_authenticated: bool) -> void:
	if not _is_sign_in_in_progress:
		return
	if not is_authenticated:
		_set_sign_in_in_progress(false)
		sign_in_failed.emit("PGS_AUTHENTICATION_FAILED")
		return
	_requesting_server_access = true
	sign_in_client.request_server_side_access(server_client_id, force_refresh_token)


func _on_server_side_access_requested(server_auth_code: String) -> void:
	if not _is_sign_in_in_progress:
		return
	if not _requesting_server_access:
		return
	_requesting_server_access = false
	_set_sign_in_in_progress(false)
	var trimmed_auth_code: String = server_auth_code.strip_edges()
	if trimmed_auth_code.is_empty():
		sign_in_failed.emit("PGS_SERVER_AUTH_CODE_MISSING")
		return
	sign_in_succeeded.emit(AuthResult.new("pgs", trimmed_auth_code, 0))


func _ensure_plugin_ready() -> bool:
	return _initialize_plugin_for_lifecycle()


func _initialize_plugin_for_lifecycle() -> bool:
	if not OS.has_feature("android"):
		return false
	if not Engine.has_singleton("GodotPlayGameServices"):
		return false
	if GodotPlayGameServices.android_plugin != null:
		return true
	var init_result: int = GodotPlayGameServices.initialize()
	return init_result == GodotPlayGameServices.PlayGamesPluginError.OK
