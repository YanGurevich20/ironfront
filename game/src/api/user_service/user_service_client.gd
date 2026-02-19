class_name UserServiceClient
extends Node

var _api_client: ApiClient
var _base_url: String


func _init(next_api_client: ApiClient, next_base_url: String) -> void:
	_api_client = next_api_client
	_base_url = next_base_url


func exchange_auth(provider_result: AuthResult, stage: String) -> Dictionary[String, Variant]:
	_log_user_service("exchanging provider proof with user-service")
	var exchange_url: String = "%s/auth/exchange" % _base_url
	var exchange_payload: Dictionary[String, Variant] = {
		"provider": provider_result.provider,
		"proof": provider_result.proof,
		"client":
		{
			"stage": stage,
			"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
			"platform": OS.get_name().to_lower()
		}
	}
	var exchange_result: Dictionary[String, Variant] = await _api_client.request_json(
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

	_log_user_service("exchange succeeded, fetching profile")
	var me_url: String = "%s/me" % _base_url
	var me_result: Dictionary[String, Variant] = await _api_client.request_json(
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


func _log_user_service(message: String) -> void:
	print("[user-service-client] %s" % message)
