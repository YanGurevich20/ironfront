class_name UserServicePatchUsernameResponseBody
extends RefCounted

var username: String
var username_updated_at: String


func _init(next_username: String, next_username_updated_at: String) -> void:
	username = next_username
	username_updated_at = next_username_updated_at


static func from_dict(body: Dictionary) -> UserServicePatchUsernameResponseBody:
	var username: String = str(body.get("username", "")).strip_edges()
	if username.is_empty():
		return null
	var username_updated_at: String = ""
	var username_updated_at_raw: Variant = body.get("username_updated_at", "")
	if username_updated_at_raw is String:
		username_updated_at = String(username_updated_at_raw).strip_edges()
	return UserServicePatchUsernameResponseBody.new(username, username_updated_at)
