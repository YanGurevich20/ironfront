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
	var exchange_result: Dictionary[String, Variant] = await _api_client.request_json(
		exchange_url,
		HTTPClient.METHOD_POST,
		["Content-Type: application/json"],
		JSON.stringify(exchange_payload)
	)
	if not bool(exchange_result.get("success", false)):
		return UserServiceExchangeAuthResult.fail(
			str(exchange_result.get("reason", "USER_SERVICE_EXCHANGE_FAILED"))
		)

	var exchange_body: UserServiceExchangeResponseBody = UserServiceExchangeResponseBody.from_dict(
		exchange_result.get("body", {})
	)
	if exchange_body == null:
		return UserServiceExchangeAuthResult.fail("USER_SERVICE_EXCHANGE_PARSE_FAILED")

	_log_user_service("exchange succeeded, fetching profile")
	var me_url: String = "%s/me" % _base_url
	var me_result: Dictionary[String, Variant] = await _api_client.request_json(
		me_url,
		HTTPClient.METHOD_GET,
		["Authorization: Bearer %s" % exchange_body.session_token],
		""
	)
	if not bool(me_result.get("success", false)):
		return UserServiceExchangeAuthResult.fail(
			str(me_result.get("reason", "USER_SERVICE_ME_REQUEST_FAILED"))
		)

	var me_body: Dictionary = me_result.get("body", {})
	UserServiceMeResponseParser.hydrate_account_from_me_body(me_body)

	return UserServiceExchangeAuthResult.ok(
		AuthResult.new(
			provider_result.provider,
			provider_result.proof,
			exchange_body.expires_at_unix,
			exchange_body.session_token
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
