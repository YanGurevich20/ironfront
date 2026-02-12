class_name NetworkClientJoinPayloadUtils
extends RefCounted


static func build_join_loadout_payload(player_data: PlayerData) -> Dictionary:
	if player_data == null or not player_data.is_selected_tank_valid():
		return _build_default_join_loadout_payload()
	var tank_config: PlayerTankConfig = player_data.get_current_tank_config()
	if tank_config == null:
		return _build_default_join_loadout_payload()
	var shell_loadout_by_path: Dictionary = {}
	for shell_spec_key: Variant in tank_config.shell_amounts.keys():
		var shell_spec: ShellSpec = shell_spec_key as ShellSpec
		if shell_spec == null:
			continue
		var shell_spec_path: String = shell_spec.resource_path
		if shell_spec_path.is_empty():
			continue
		var shell_count: int = max(0, int(tank_config.shell_amounts[shell_spec_key]))
		shell_loadout_by_path[shell_spec_path] = shell_count
	var selected_shell_path: String = _pick_default_selected_shell_path(
		tank_config.tank_id, shell_loadout_by_path
	)
	return {
		"tank_id": int(tank_config.tank_id),
		"shell_loadout_by_path": shell_loadout_by_path,
		"selected_shell_path": selected_shell_path,
	}


static func _build_default_join_loadout_payload() -> Dictionary:
	var default_tank_id: int = ArenaSessionState.DEFAULT_TANK_ID
	if not TankManager.tank_specs.has(default_tank_id):
		return {"tank_id": default_tank_id, "shell_loadout_by_path": {}, "selected_shell_path": ""}
	var default_tank_spec: TankSpec = TankManager.tank_specs[default_tank_id]
	if default_tank_spec == null or default_tank_spec.allowed_shells.is_empty():
		return {"tank_id": default_tank_id, "shell_loadout_by_path": {}, "selected_shell_path": ""}
	var first_shell_spec: ShellSpec = default_tank_spec.allowed_shells[0]
	if first_shell_spec == null or first_shell_spec.resource_path.is_empty():
		return {"tank_id": default_tank_id, "shell_loadout_by_path": {}, "selected_shell_path": ""}
	var default_shell_loadout_by_path: Dictionary = {
		first_shell_spec.resource_path: default_tank_spec.shell_capacity
	}
	return {
		"tank_id": default_tank_id,
		"shell_loadout_by_path": default_shell_loadout_by_path,
		"selected_shell_path": first_shell_spec.resource_path,
	}


static func _pick_default_selected_shell_path(
	tank_id: int, shell_loadout_by_path: Dictionary
) -> String:
	if not TankManager.tank_specs.has(tank_id):
		return ""
	var tank_spec: TankSpec = TankManager.tank_specs[tank_id]
	if tank_spec == null:
		return ""
	for allowed_shell_spec: ShellSpec in tank_spec.allowed_shells:
		if allowed_shell_spec == null:
			continue
		var shell_spec_path: String = allowed_shell_spec.resource_path
		if shell_spec_path.is_empty():
			continue
		var shell_count: int = max(0, int(shell_loadout_by_path.get(shell_spec_path, 0)))
		if shell_count > 0:
			return shell_spec_path
	return ""
