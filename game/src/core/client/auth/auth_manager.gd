class_name AuthManager
extends Node

signal sign_in_succeeded(result: AuthResult)
signal sign_in_failed(reason: String)
signal username_setup_required(initial_username: String)
signal username_submit_completed(success: bool, reason: String, username: String)

const DEV_PROVIDER_SCENE: PackedScene = preload(
	"res://src/core/client/auth/providers/dev_auth_provider.tscn"
)
const PGS_PROVIDER_SCENE: PackedScene = preload(
	"res://src/core/client/auth/providers/pgs_auth_provider.tscn"
)

var _active_provider: AuthProvider
var _api_client: ApiClient
var _user_service_client: UserServiceClient
var _is_signed_in: bool = false
var _is_sign_in_in_progress: bool = false
var _session_token: String = ""
var _auth_result: AuthResult


func _ready() -> void:
	_api_client = ApiClient.new()
	add_child(_api_client)
	_user_service_client = UserServiceClient.new(_api_client, AppConfig.user_service_base_url)
	add_child(_user_service_client)
	_active_provider = _instantiate_provider()
	Utils.connect_checked(_active_provider.sign_in_succeeded, _on_provider_sign_in_succeeded)
	Utils.connect_checked(_active_provider.sign_in_failed, _on_provider_sign_in_failed)


func retry_sign_in() -> void:
	if _is_signed_in or _is_sign_in_in_progress:
		_log_auth("sign-in ignored (already signed in or in progress)")
		return
	_log_auth("sign-in started")
	_is_sign_in_in_progress = true
	UiBus.auth_sign_in_started.emit()
	_active_provider.sign_in()


func sign_out() -> void:
	if _active_provider == null:
		return
	_log_auth("sign-out requested")
	_is_signed_in = false
	_is_sign_in_in_progress = false
	_session_token = ""
	_auth_result = null
	_active_provider.sign_out()


func _on_provider_sign_in_succeeded(result: AuthResult) -> void:
	_log_auth("provider sign-in succeeded provider=%s" % result.provider)
	var exchange_result: UserServiceExchangeAuthResult = await _user_service_client.exchange_auth(
		result
	)
	if not exchange_result.success:
		_is_signed_in = false
		_is_sign_in_in_progress = false
		_log_auth("user-service exchange failed reason=%s" % exchange_result.reason)
		sign_in_failed.emit(exchange_result.reason)
		return
	var auth_result: AuthResult = exchange_result.auth_result
	if auth_result == null:
		_is_signed_in = false
		_is_sign_in_in_progress = false
		_log_auth("user-service exchange failed invalid response shape")
		sign_in_failed.emit("USER_SERVICE_INVALID_RESPONSE")
		return
	_is_signed_in = true
	_is_sign_in_in_progress = false
	_session_token = auth_result.session_token
	_auth_result = auth_result
	_log_auth(
		(
			"sign-in completed account_id=%s username=%s"
			% [auth_result.account_id, auth_result.username]
		)
	)
	sign_in_succeeded.emit(auth_result)
	if auth_result.username_updated_at.is_empty():
		username_setup_required.emit(auth_result.username)


func _on_provider_sign_in_failed(reason: String) -> void:
	_is_signed_in = false
	_is_sign_in_in_progress = false
	_log_auth("provider sign-in failed reason=%s" % reason)
	sign_in_failed.emit(reason)


func submit_username(username: String) -> void:
	if not _is_signed_in:
		username_submit_completed.emit(false, "NOT_SIGNED_IN", "")
		return
	if _auth_result == null:
		username_submit_completed.emit(false, "AUTH_RESULT_MISSING", "")
		return
	var trimmed_username: String = username.strip_edges()
	if trimmed_username.is_empty():
		username_submit_completed.emit(false, "USERNAME_REQUIRED", "")
		return
	var patch_result: UserServicePatchUsernameResult = await _user_service_client.patch_username(
		_session_token, trimmed_username
	)
	if not patch_result.success:
		username_submit_completed.emit(false, patch_result.reason, "")
		return

	var patch_body: UserServicePatchUsernameResponseBody = patch_result.body
	if patch_body == null:
		username_submit_completed.emit(false, "USERNAME_PATCH_PARSE_FAILED", "")
		return

	_auth_result.username = patch_body.username
	_auth_result.username_updated_at = patch_body.username_updated_at
	username_submit_completed.emit(true, "", patch_body.username)


func _instantiate_provider() -> AuthProvider:
	var use_pgs_provider: bool = AppConfig.should_use_pgs_provider()
	var provider_scene: PackedScene = PGS_PROVIDER_SCENE if use_pgs_provider else DEV_PROVIDER_SCENE
	var provider_node: Node = provider_scene.instantiate()
	var provider: AuthProvider = provider_node as AuthProvider
	assert(provider != null, "Provider scene root must inherit AuthProvider")
	if use_pgs_provider:
		var pgs_provider: PgsAuthProvider = provider as PgsAuthProvider
		assert(pgs_provider != null, "PGS provider scene root must inherit PgsAuthProvider")
		pgs_provider.server_client_id = AppConfig.pgs_server_client_id
	add_child(provider)
	return provider


func _log_auth(message: String) -> void:
	print("[auth-manager] %s" % message)
