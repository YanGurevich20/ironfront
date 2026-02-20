class_name UserServiceExchangeAuthResult
extends RefCounted

var success: bool
var reason: String
var auth_result: AuthResult


func _init(next_success: bool, next_reason: String, next_auth_result: AuthResult = null) -> void:
	success = next_success
	reason = next_reason
	auth_result = next_auth_result


static func ok(next_auth_result: AuthResult) -> UserServiceExchangeAuthResult:
	return UserServiceExchangeAuthResult.new(true, "", next_auth_result)


static func fail(next_reason: String) -> UserServiceExchangeAuthResult:
	return UserServiceExchangeAuthResult.new(false, next_reason, null)
