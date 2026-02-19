class_name AuthManager
extends Node

signal sign_in_succeeded(result: AuthResult)
signal sign_in_failed(reason: String)

const DEV_PROVIDER_SCENE: PackedScene = preload(
	"res://src/core/client/auth/providers/dev_auth_provider.tscn"
)
const PGS_PROVIDER_SCENE: PackedScene = preload(
	"res://src/core/client/auth/providers/pgs_auth_provider.tscn"
)

var _active_provider: AuthProvider
var _is_signed_in: bool = false
var _is_sign_in_in_progress: bool = false
var _session_token: String = ""


func _ready() -> void:
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
	_active_provider.sign_out()


func _on_provider_sign_in_succeeded(result: AuthResult) -> void:
	_log_auth("provider sign-in succeeded provider=%s" % result.provider)
	var exchange_result: Dictionary[String, Variant] = await _exchange_with_user_service(result)
	if not bool(exchange_result.get("success", false)):
		_is_signed_in = false
		_is_sign_in_in_progress = false
		_log_auth(
			"user-service exchange failed reason=%s" % exchange_result.get("reason", "UNKNOWN")
		)
		sign_in_failed.emit(str(exchange_result.get("reason", "USER_SERVICE_EXCHANGE_FAILED")))
		return
	var auth_result: AuthResult = exchange_result.get("result", null) as AuthResult
	if auth_result == null:
		_is_signed_in = false
		_is_sign_in_in_progress = false
		_log_auth("user-service exchange failed invalid response shape")
		sign_in_failed.emit("USER_SERVICE_INVALID_RESPONSE")
		return
	_is_signed_in = true
	_is_sign_in_in_progress = false
	_session_token = auth_result.session_token
	_log_auth(
		(
			"sign-in completed account_id=%s username=%s"
			% [auth_result.account_id, auth_result.username]
		)
	)
	sign_in_succeeded.emit(auth_result)


func _on_provider_sign_in_failed(reason: String) -> void:
	_is_signed_in = false
	_is_sign_in_in_progress = false
	_log_auth("provider sign-in failed reason=%s" % reason)
	sign_in_failed.emit(reason)


func _instantiate_provider() -> AuthProvider:
	var use_pgs_provider: bool = AppConfig.should_use_pgs_provider()
	var provider_scene: PackedScene = PGS_PROVIDER_SCENE if use_pgs_provider else DEV_PROVIDER_SCENE
	var provider_node: Node = provider_scene.instantiate()
	var provider: AuthProvider = provider_node as AuthProvider
	assert(provider != null, "Provider scene root must inherit AuthProvider")
	add_child(provider)
	return provider


func _exchange_with_user_service(provider_result: AuthResult) -> Dictionary[String, Variant]:
	_log_auth("exchanging provider proof with user-service")
	var exchange_url: String = "%s/auth/exchange" % AppConfig.user_service_base_url
	var exchange_payload: Dictionary[String, Variant] = {
		"provider": provider_result.provider,
		"proof": provider_result.proof,
		"client":
		{
			"stage": AppConfig.stage,
			"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
			"platform": OS.get_name().to_lower()
		}
	}
	var exchange_result: Dictionary[String, Variant] = await _request_json(
		exchange_url,
		HTTPClient.METHOD_POST,
		["Content-Type: application/json"],
		JSON.stringify(exchange_payload)
	)
	if not bool(exchange_result.get("success", false)):
		return exchange_result
	var exchange_body: Dictionary = exchange_result.get("body", {})
	var session_token: String = str(exchange_body.get("session_token", "")).strip_edges()
	if session_token.is_empty():
		return {"success": false, "reason": "USER_SERVICE_SESSION_TOKEN_MISSING"}
	_log_auth("exchange succeeded, fetching profile")

	var me_url: String = "%s/me" % AppConfig.user_service_base_url
	var me_result: Dictionary[String, Variant] = await _request_json(
		me_url, HTTPClient.METHOD_GET, ["Authorization: Bearer %s" % session_token], ""
	)
	if not bool(me_result.get("success", false)):
		return me_result
	var me_body: Dictionary = me_result.get("body", {})
	var display_name: String = str(me_body.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = provider_result.display_name
	var username: String = str(me_body.get("username", "")).strip_edges()
	var account_id: String = str(exchange_body.get("account_id", "")).strip_edges()
	var expires_at_unix: int = int(exchange_body.get("expires_at_unix", 0))
	return {
		"success": true,
		"result":
		AuthResult.new(
			provider_result.provider,
			provider_result.provider_user_id,
			display_name,
			provider_result.proof,
			expires_at_unix,
			account_id,
			username,
			session_token
		)
	}


func _request_json(
	url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String
) -> Dictionary[String, Variant]:
	_log_auth("http request method=%d url=%s" % [method, url])
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	var request_error: Error = request.request(url, headers, method, body)
	if request_error != OK:
		request.queue_free()
		_log_auth("http request creation failed error=%d url=%s" % [request_error, url])
		return {"success": false, "reason": "USER_SERVICE_HTTP_REQUEST_FAILED"}
	var response: Array = await request.request_completed
	request.queue_free()

	var result: int = int(response[0])
	if result != HTTPRequest.RESULT_SUCCESS:
		_log_auth("http transport failed result=%d url=%s" % [result, url])
		return {"success": false, "reason": "USER_SERVICE_HTTP_TRANSPORT_FAILED"}
	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	var parsed_body: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	var parsed_dictionary: Dictionary = parsed_body if parsed_body is Dictionary else {}
	_log_auth("http response code=%d url=%s" % [response_code, url])
	if response_code < 200 or response_code >= 300:
		var error_reason: String = str(parsed_dictionary.get("error", "USER_SERVICE_HTTP_ERROR"))
		return {"success": false, "reason": error_reason}
	return {"success": true, "body": parsed_dictionary}


func _log_auth(message: String) -> void:
	print("[auth-manager] %s" % message)
