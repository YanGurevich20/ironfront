class_name UserServicePatchUsernameResult
extends RefCounted

var success: bool
var reason: String
var body: UserServicePatchUsernameResponseBody


func _init(
	next_success: bool, next_reason: String, next_body: UserServicePatchUsernameResponseBody = null
) -> void:
	success = next_success
	reason = next_reason
	body = next_body


static func ok(next_body: UserServicePatchUsernameResponseBody) -> UserServicePatchUsernameResult:
	return UserServicePatchUsernameResult.new(true, "", next_body)


static func fail(next_reason: String) -> UserServicePatchUsernameResult:
	return UserServicePatchUsernameResult.new(false, next_reason, null)
