class_name UserServiceMeResponseParser
extends RefCounted


static func hydrate_account_from_me_body(me_body: Dictionary) -> void:
	var account: Account = Account.get_instance()
	account.account_id = str(me_body.get("account_id", "")).strip_edges()
	account.username = str(me_body.get("username", "")).strip_edges()
	var username_updated_at_unix: Variant = me_body.get("username_updated_at_unix", null)
	account.username_updated_at = (
		int(username_updated_at_unix) if username_updated_at_unix != null else 0
	)

	var economy_dict: Dictionary = me_body.get("economy", {})
	account.economy.dollars = int(economy_dict.get("dollars", 0))
	account.economy.bonds = int(economy_dict.get("bonds", 0))

	var loadout_dict: Dictionary = me_body.get("loadout", {})
	account.loadout.selected_tank_id = str(loadout_dict.get("selected_tank_id", ""))
	account.loadout.tanks.clear()
	var source_tanks: Dictionary = loadout_dict.get("tanks", {})
	for tank_id_variant: Variant in source_tanks.keys():
		var tank_id: String = str(tank_id_variant)
		var tank_payload: Dictionary = source_tanks.get(tank_id_variant, {})
		var tank_config: TankConfig = TankConfig.new()
		tank_config.tank_id = tank_id
		var unlocked_shell_ids: Array[String] = []
		for shell_id_variant: Variant in tank_payload.get("unlocked_shell_ids", []):
			unlocked_shell_ids.append(str(shell_id_variant))
		tank_config.unlocked_shell_ids = unlocked_shell_ids
		var shell_loadout_input: Dictionary = tank_payload.get("shell_loadout_by_id", {})
		var shell_loadout_by_id: Dictionary[String, int] = {}
		for shell_id_variant: Variant in shell_loadout_input.keys():
			shell_loadout_by_id[str(shell_id_variant)] = int(
				shell_loadout_input.get(shell_id_variant, 0)
			)
		tank_config.shell_loadout_by_id = shell_loadout_by_id
		account.loadout.tanks[tank_id] = tank_config
	account.save()
