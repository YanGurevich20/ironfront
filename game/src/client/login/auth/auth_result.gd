class_name AuthResult
extends RefCounted

var provider: String
var proof: String
var expires_at_unix: int
var session_token: String


func _init(
	next_provider: String,
	next_proof: String,
	next_expires_at_unix: int = 0,
	next_session_token: String = ""
) -> void:
	provider = next_provider
	proof = next_proof
	expires_at_unix = next_expires_at_unix
	session_token = next_session_token
