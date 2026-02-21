class_name UserServiceMeResponseBody
extends RefCounted

var account_id: String
var username: String
var username_updated_at: int
var economy: AccountEconomy
var loadout: AccountLoadout


func _init(
	next_account_id: String,
	next_username: String,
	next_username_updated_at: int,
	next_economy: AccountEconomy,
	next_loadout: AccountLoadout
) -> void:
	account_id = next_account_id
	username = next_username
	username_updated_at = next_username_updated_at
	economy = next_economy
	loadout = next_loadout


static func from_dict(body: Dictionary) -> UserServiceMeResponseBody:
	var account_id: String = str(body.get("account_id", "")).strip_edges()
	var username: String = str(body.get("username", "")).strip_edges()
	var username_updated_at: int = int(body.get("username_updated_at_unix", 0))
	var economy_dict: Dictionary = body.get("economy", {})
	var economy: AccountEconomy = AccountEconomy.new()
	economy.dollars = int(economy_dict.get("dollars", 0))
	economy.bonds = int(economy_dict.get("bonds", 0))
	var loadout_dict: Dictionary = body.get("loadout", {})
	var loadout: AccountLoadout = AccountLoadout.new()
	var source_tank_configs: Dictionary = loadout_dict.get("tank_configs", {})
	for tank_id_variant: Variant in source_tank_configs.keys():
		var tank_id: String = str(tank_id_variant).strip_edges()
		var tank_payload: Dictionary = source_tank_configs.get(tank_id_variant, {})
		var tank_config: TankConfig = TankConfig.new()
		tank_config.tank_id = tank_id
		tank_config.shell_loadout_by_id = tank_payload.get("shell_loadout_by_id", {})
		loadout.tank_configs[tank_id] = tank_config
	return UserServiceMeResponseBody.new(
		account_id, username, username_updated_at, economy, loadout
	)
