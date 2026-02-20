class_name UserServiceClient
extends Node

var _api_client: ApiClient
var _base_url: String


func _init(next_api_client: ApiClient, next_base_url: String) -> void:
	_api_client = next_api_client
	_base_url = next_base_url


func exchange_auth(provider_result: AuthResult) -> UserServiceExchangeAuthResult:
	_log_user_service("exchanging provider proof with user-service")
	var exchange_url: String = "%s/auth/exchange" % _base_url
	var exchange_payload: Dictionary[String, Variant] = {
		"provider": provider_result.provider,
		"proof": provider_result.proof,
	}
	var failure_reason: String = ""
	var exchange_body: UserServiceExchangeResponseBody
	var me_body: UserServiceMeResponseBody
	var exchange_result: Dictionary[String, Variant] = await _api_client.request_json(
		exchange_url,
		HTTPClient.METHOD_POST,
		["Content-Type: application/json"],
		JSON.stringify(exchange_payload)
	)
	if not bool(exchange_result.get("success", false)):
		failure_reason = str(exchange_result.get("reason", "USER_SERVICE_EXCHANGE_FAILED"))
	else:
		exchange_body = UserServiceExchangeResponseBody.from_dict(exchange_result.get("body", {}))
		if exchange_body == null:
			failure_reason = "USER_SERVICE_EXCHANGE_PARSE_FAILED"
		else:
			_log_user_service("exchange succeeded, fetching profile")
			var me_url: String = "%s/me" % _base_url
			var me_result: Dictionary[String, Variant] = await _api_client.request_json(
				me_url,
				HTTPClient.METHOD_GET,
				["Authorization: Bearer %s" % exchange_body.session_token],
				""
			)
			if not bool(me_result.get("success", false)):
				failure_reason = str(me_result.get("reason", "USER_SERVICE_ME_REQUEST_FAILED"))
			else:
				me_body = UserServiceMeResponseBody.from_dict(me_result.get("body", {}))
				if me_body == null:
					failure_reason = "USER_SERVICE_ME_PARSE_FAILED"
	if not failure_reason.is_empty():
		return UserServiceExchangeAuthResult.fail(failure_reason)
	return UserServiceExchangeAuthResult.ok(
		AuthResult.new(
			provider_result.provider,
			provider_result.proof,
			exchange_body.expires_at_unix,
			exchange_body.account_id,
			me_body.username,
			exchange_body.session_token,
			me_body.username_updated_at
		)
	)


func patch_username(session_token: String, username: String) -> UserServicePatchUsernameResult:
	_log_user_service("patching username")
	var patch_url: String = "%s/me/username" % _base_url
	var payload: Dictionary[String, Variant] = {"username": username}
	var patch_result: Dictionary[String, Variant] = await _api_client.request_json(
		patch_url,
		HTTPClient.METHOD_PATCH,
		["Content-Type: application/json", "Authorization: Bearer %s" % session_token],
		JSON.stringify(payload)
	)
	if not bool(patch_result.get("success", false)):
		return UserServicePatchUsernameResult.fail(
			str(patch_result.get("reason", "USERNAME_UPDATE_FAILED"))
		)
	var patch_body: UserServicePatchUsernameResponseBody = (
		UserServicePatchUsernameResponseBody.from_dict(patch_result.get("body", {}))
	)
	if patch_body == null:
		return UserServicePatchUsernameResult.fail("USERNAME_INVALID_RESPONSE")
	return UserServicePatchUsernameResult.ok(patch_body)


func _log_user_service(message: String) -> void:
	print("[user-service-client] %s" % message)
