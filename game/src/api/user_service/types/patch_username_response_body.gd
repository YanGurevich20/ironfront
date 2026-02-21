class_name UserServicePatchUsernameResponseBody
extends RefCounted

var username: String
var username_updated_at: int


func _init(next_username: String, next_username_updated_at: int) -> void:
	username = next_username
	username_updated_at = next_username_updated_at


static func from_dict(body: Dictionary) -> UserServicePatchUsernameResponseBody:
	var username: String = str(body.get("username", "")).strip_edges()
	if username.is_empty():
		return null
	var username_updated_at: int = int(body.get("username_updated_at_unix", 0))
	return UserServicePatchUsernameResponseBody.new(username, username_updated_at)
