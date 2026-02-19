class_name AuthResult
extends RefCounted

var provider: String
var provider_user_id: String
var display_name: String
var proof: String
var expires_at_unix: int
var account_id: String
var username: String
var session_token: String


func _init(
	next_provider: String,
	next_provider_user_id: String,
	next_display_name: String,
	next_proof: String,
	next_expires_at_unix: int = 0,
	next_account_id: String = "",
	next_username: String = "",
	next_session_token: String = ""
) -> void:
	provider = next_provider
	provider_user_id = next_provider_user_id
	display_name = next_display_name
	proof = next_proof
	expires_at_unix = next_expires_at_unix
	account_id = next_account_id
	username = next_username
	session_token = next_session_token
