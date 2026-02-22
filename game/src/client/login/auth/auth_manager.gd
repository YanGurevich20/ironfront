class_name AuthManager
extends Node

signal sign_in_succeeded(result: AuthResult)
signal sign_in_failed(reason: String)
signal username_setup_required(initial_username: String)
signal username_submit_completed(success: bool, reason: String, username: String)

const DEV_PROVIDER_SCENE: PackedScene = preload(
	"res://src/client/login/auth/providers/dev_auth_provider.tscn"
)
const PGS_PROVIDER_SCENE: PackedScene = preload(
	"res://src/client/login/auth/providers/pgs_auth_provider.tscn"
)

var _active_provider: AuthProvider
var _api_client: ApiClient
var _user_service_client: UserServiceClient
var _session_token: String = ""


func _ready() -> void:
	_api_client = ApiClient.new()
	add_child(_api_client)
	_user_service_client = UserServiceClient.new(_api_client, AppConfig.user_service_base_url)
	add_child(_user_service_client)
	_active_provider = _instantiate_provider()
	Utils.connect_checked(_active_provider.sign_in_succeeded, _on_provider_sign_in_succeeded)
	Utils.connect_checked(_active_provider.sign_in_failed, _on_provider_sign_in_failed)


func retry_sign_in() -> void:
	if not _session_token.is_empty() or _active_provider.has_sign_in_operation():
		_log_auth("sign-in ignored (already signed in or in progress)")
		return
	_log_auth("sign-in started")
	_active_provider.sign_in()


func sign_out() -> void:
	if _active_provider == null:
		return
	_log_auth("sign-out requested")
	_session_token = ""
	Account.clear()
	_active_provider.sign_out()


func _on_provider_sign_in_succeeded(result: AuthResult) -> void:
	_log_auth("provider sign-in succeeded provider=%s" % result.provider)
	var exchange_result: UserServiceExchangeAuthResult = await _user_service_client.exchange_auth(
		result
	)
	if not is_inside_tree():
		return
	if not exchange_result.success:
		_session_token = ""
		_log_auth("user-service exchange failed reason=%s" % exchange_result.reason)
		sign_in_failed.emit(exchange_result.reason)
		return
	var auth_result: AuthResult = exchange_result.auth_result
	if auth_result == null:
		_session_token = ""
		_log_auth("user-service exchange failed invalid response shape")
		sign_in_failed.emit("USER_SERVICE_INVALID_RESPONSE")
		return
	_session_token = auth_result.session_token
	_log_auth(
		"sign-in completed account_id=%s username=%s" % [Account.account_id, Account.username]
	)
	sign_in_succeeded.emit(auth_result)
	if Account.username_updated_at <= 0:
		username_setup_required.emit(Account.username)


func _on_provider_sign_in_failed(reason: String) -> void:
	_session_token = ""
	_log_auth("provider sign-in failed reason=%s" % reason)
	sign_in_failed.emit(reason)


func submit_username(username: String) -> void:
	if _session_token.is_empty():
		username_submit_completed.emit(false, "NOT_SIGNED_IN", "")
		return
	if username.is_empty():
		username_submit_completed.emit(false, "USERNAME_REQUIRED", "")
		return
	var patch_result: UserServicePatchUsernameResult = await _user_service_client.patch_username(
		_session_token, username
	)
	if not is_inside_tree():
		return
	if not patch_result.success:
		username_submit_completed.emit(false, patch_result.reason, "")
		return

	var patch_body: UserServicePatchUsernameResponseBody = patch_result.body
	if patch_body == null:
		username_submit_completed.emit(false, "USERNAME_PATCH_PARSE_FAILED", "")
		return

	Account.username = patch_body.username
	Account.username_updated_at = patch_body.username_updated_at_unix
	username_submit_completed.emit(true, "", patch_body.username)


func _instantiate_provider() -> AuthProvider:
	var use_pgs_provider: bool = AppConfig.should_use_pgs_provider()
	var provider_scene: PackedScene = PGS_PROVIDER_SCENE if use_pgs_provider else DEV_PROVIDER_SCENE
	var provider: AuthProvider = provider_scene.instantiate()
	add_child(provider)
	return provider


func _log_auth(message: String) -> void:
	print("[auth-manager] %s" % message)
