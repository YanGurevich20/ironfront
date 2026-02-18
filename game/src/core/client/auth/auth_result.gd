class_name AuthResult
extends RefCounted

var provider: String
var provider_user_id: String
var display_name: String
var proof: String
var expires_at_unix: int


func _init(
	next_provider: String,
	next_provider_user_id: String,
	next_display_name: String,
	next_proof: String,
	next_expires_at_unix: int = 0
) -> void:
	provider = next_provider
	provider_user_id = next_provider_user_id
	display_name = next_display_name
	proof = next_proof
	expires_at_unix = next_expires_at_unix
