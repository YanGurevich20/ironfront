class_name UserServiceExchangeResponseBody
extends RefCounted

var account_id: String
var session_token: String
var expires_at_unix: int


func _init(next_account_id: String, next_session_token: String, next_expires_at_unix: int) -> void:
	account_id = next_account_id
	session_token = next_session_token
	expires_at_unix = next_expires_at_unix


static func from_dict(body: Dictionary) -> UserServiceExchangeResponseBody:
	var account_id: String = str(body.get("account_id", "")).strip_edges()
	var session_token: String = str(body.get("session_token", "")).strip_edges()
	var expires_at_unix: int = int(body.get("expires_at_unix", 0))
	if account_id.is_empty():
		return null
	if session_token.is_empty():
		return null
	if expires_at_unix <= 0:
		return null
	return UserServiceExchangeResponseBody.new(account_id, session_token, expires_at_unix)
