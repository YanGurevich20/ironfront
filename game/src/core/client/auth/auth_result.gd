class_name AuthResult
extends RefCounted

var provider: String
var proof: String
var expires_at_unix: int
var account_id: String
var username: String
var session_token: String
var username_updated_at_unix: Variant
var economy: AccountEconomy
var loadout: AccountLoadout


func _init(
	next_provider: String,
	next_proof: String,
	next_expires_at_unix: int = 0,
	next_account_id: String = "",
	next_username: String = "",
	next_session_token: String = "",
	next_username_updated_at_unix: Variant = null,
	next_economy: AccountEconomy = AccountEconomy.new(),
	next_loadout: AccountLoadout = AccountLoadout.new()
) -> void:
	provider = next_provider
	proof = next_proof
	expires_at_unix = next_expires_at_unix
	account_id = next_account_id
	username = next_username
	session_token = next_session_token
	username_updated_at_unix = next_username_updated_at_unix
	economy = next_economy
	loadout = next_loadout
