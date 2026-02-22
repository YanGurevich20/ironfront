class_name ArenaSessionState
extends RefCounted

const DEFAULT_TANK_ID: String = TankManager.TANK_ID_M4A1_SHERMAN

var max_players: int = 10
var created_unix_time: float = 0.0
var players_by_peer_id: Dictionary[int, Dictionary] = {}


func _init(max_player_count: int = 10) -> void:
	max_players = max(1, max_player_count)
	created_unix_time = Time.get_unix_time_from_system()


func try_join_peer(peer_id: int, player_name: String, requested_loadout: Dictionary) -> Dictionary:
	if players_by_peer_id.has(peer_id):
		return {"success": false, "message": "ALREADY JOINED ARENA"}
	if players_by_peer_id.size() >= max_players:
		return {"success": false, "message": "ARENA FULL"}

	var validation_result: Dictionary = _validate_requested_loadout(requested_loadout)
	if not validation_result.get("valid", false):
		return {
			"success": false,
			"message": str(validation_result.get("message", "INVALID TANK CONFIGURATION")),
		}

	var tank_spec: TankSpec = validation_result.get("tank_spec", null)
	var selected_shell_spec: ShellSpec = validation_result.get("selected_shell_spec", null)
	var ammo_by_shell_spec: Dictionary = validation_result.get("ammo_by_shell_spec", {})

	players_by_peer_id[peer_id] = {
		"peer_id": peer_id,
		"player_name": player_name,
		"joined_unix_time": Time.get_unix_time_from_system(),
		"tank_spec": tank_spec,
		"selected_shell_spec": selected_shell_spec,
		"ammo_by_shell_spec": ammo_by_shell_spec.duplicate(true),
		"entry_selected_shell_spec": selected_shell_spec,
		"entry_ammo_by_shell_spec": ammo_by_shell_spec.duplicate(true),
		"state_position": Vector2.ZERO,
		"state_rotation": 0.0,
		"state_linear_velocity": Vector2.ZERO,
		"state_turret_rotation": 0.0,
		"input_left_track": 0.0,
		"input_right_track": 0.0,
		"input_turret_aim": 0.0,
		"last_input_tick": 0,
		"last_input_received_msec": 0,
		"pending_fire_request_seq": 0,
		"last_fire_request_seq": 0,
		"last_fire_request_received_msec": 0,
		"pending_shell_select_seq": 0,
		"pending_shell_select_id": "",
		"last_shell_select_seq": 0,
		"last_shell_select_received_msec": 0,
	}
	return {
		"success": true,
		"message": "JOINED GLOBAL ARENA",
		"tank_spec": tank_spec,
	}


func has_peer(peer_id: int) -> bool:
	return players_by_peer_id.has(peer_id)


func get_peer_ids() -> Array[int]:
	return players_by_peer_id.keys()


func get_peer_state(peer_id: int) -> Dictionary:
	if not players_by_peer_id.has(peer_id):
		return {}
	return players_by_peer_id[peer_id]


func set_peer_authoritative_state(
	peer_id: int,
	position: Vector2,
	rotation: float,
	linear_velocity: Vector2,
	turret_rotation: float = 0.0
) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	peer_state["state_position"] = position
	peer_state["state_rotation"] = rotation
	peer_state["state_linear_velocity"] = linear_velocity
	peer_state["state_turret_rotation"] = turret_rotation
	players_by_peer_id[peer_id] = peer_state
	return true


func get_peer_last_input_tick(peer_id: int) -> int:
	if not players_by_peer_id.has(peer_id):
		return 0
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	return peer_state.get("last_input_tick", 0)


func set_peer_input_intent(
	peer_id: int,
	input_tick: int,
	left_track_input: float,
	right_track_input: float,
	turret_aim: float,
	received_msec: int
) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var last_input_tick: int = peer_state.get("last_input_tick", 0)
	if input_tick <= last_input_tick:
		return false
	peer_state["input_left_track"] = left_track_input
	peer_state["input_right_track"] = right_track_input
	peer_state["input_turret_aim"] = turret_aim
	peer_state["last_input_tick"] = input_tick
	peer_state["last_input_received_msec"] = received_msec
	players_by_peer_id[peer_id] = peer_state
	return true


func queue_peer_fire_request(peer_id: int, fire_request_seq: int, received_msec: int) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	if fire_request_seq <= 0:
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var last_fire_request_seq: int = peer_state.get("last_fire_request_seq", 0)
	if fire_request_seq <= last_fire_request_seq:
		return false
	peer_state["pending_fire_request_seq"] = fire_request_seq
	peer_state["last_fire_request_seq"] = fire_request_seq
	peer_state["last_fire_request_received_msec"] = received_msec
	players_by_peer_id[peer_id] = peer_state
	return true


func queue_peer_shell_select_request(
	peer_id: int, shell_select_seq: int, shell_id: String, received_msec: int
) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	if shell_select_seq <= 0:
		return false
	if shell_id.is_empty():
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var last_shell_select_seq: int = peer_state.get("last_shell_select_seq", 0)
	if shell_select_seq <= last_shell_select_seq:
		return false
	peer_state["pending_shell_select_seq"] = shell_select_seq
	peer_state["pending_shell_select_id"] = shell_id
	peer_state["last_shell_select_seq"] = shell_select_seq
	peer_state["last_shell_select_received_msec"] = received_msec
	players_by_peer_id[peer_id] = peer_state
	return true


func consume_peer_fire_request_seq(peer_id: int) -> int:
	if not players_by_peer_id.has(peer_id):
		return 0
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var pending_fire_request_seq: int = peer_state.get("pending_fire_request_seq", 0)
	if pending_fire_request_seq <= 0:
		return 0
	peer_state["pending_fire_request_seq"] = 0
	players_by_peer_id[peer_id] = peer_state
	return pending_fire_request_seq


func consume_peer_shell_select_request(peer_id: int) -> Dictionary:
	if not players_by_peer_id.has(peer_id):
		return {}
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var pending_shell_select_seq: int = peer_state.get("pending_shell_select_seq", 0)
	if pending_shell_select_seq <= 0:
		return {}
	var pending_shell_select_id: String = str(peer_state.get("pending_shell_select_id", ""))
	peer_state["pending_shell_select_seq"] = 0
	peer_state["pending_shell_select_id"] = ""
	players_by_peer_id[peer_id] = peer_state
	var shell_spec: ShellSpec = ShellManager.find_shell_spec(pending_shell_select_id)
	return {
		"shell_select_seq": pending_shell_select_seq,
		"shell_spec": shell_spec,
	}


func apply_peer_shell_selection(peer_id: int, shell_spec: ShellSpec) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	if shell_spec == null:
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var ammo_by_shell_spec: Dictionary = peer_state.get("ammo_by_shell_spec", {})
	if not ammo_by_shell_spec.has(shell_spec):
		return false
	var shell_count: int = int(ammo_by_shell_spec.get(shell_spec, 0))
	if shell_count <= 0:
		return false
	peer_state["selected_shell_spec"] = shell_spec
	players_by_peer_id[peer_id] = peer_state
	return true


func consume_peer_shell_ammo(peer_id: int, shell_spec: ShellSpec) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	if shell_spec == null:
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var ammo_by_shell_spec: Dictionary = peer_state.get("ammo_by_shell_spec", {})
	if not ammo_by_shell_spec.has(shell_spec):
		return false
	var shell_count: int = int(ammo_by_shell_spec.get(shell_spec, 0))
	if shell_count <= 0:
		return false
	ammo_by_shell_spec[shell_spec] = shell_count - 1
	peer_state["ammo_by_shell_spec"] = ammo_by_shell_spec
	players_by_peer_id[peer_id] = peer_state
	return true


func get_peer_tank_spec(peer_id: int) -> TankSpec:
	if not players_by_peer_id.has(peer_id):
		return TankManager.require_tank_spec(DEFAULT_TANK_ID)
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var tank_spec: TankSpec = peer_state.get("tank_spec", null)
	if tank_spec != null:
		return tank_spec
	return TankManager.require_tank_spec(DEFAULT_TANK_ID)


func get_peer_selected_shell_spec(peer_id: int) -> ShellSpec:
	if not players_by_peer_id.has(peer_id):
		return null
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	return peer_state.get("selected_shell_spec", null)


func get_peer_shell_count(peer_id: int, shell_spec: ShellSpec) -> int:
	if not players_by_peer_id.has(peer_id):
		return 0
	if shell_spec == null:
		return 0
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var ammo_by_shell_spec: Dictionary = peer_state.get("ammo_by_shell_spec", {})
	return int(ammo_by_shell_spec.get(shell_spec, 0))


func get_peer_ammo_by_shell_id(peer_id: int) -> Dictionary:
	if not players_by_peer_id.has(peer_id):
		return {}
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var ammo_by_shell_spec: Dictionary = peer_state.get("ammo_by_shell_spec", {})
	var ammo_by_shell_id: Dictionary = {}
	for shell_spec_variant: Variant in ammo_by_shell_spec.keys():
		var shell_spec: ShellSpec = shell_spec_variant as ShellSpec
		if shell_spec == null:
			continue
		ammo_by_shell_id[ShellManager.get_shell_id(shell_spec)] = int(
			ammo_by_shell_spec.get(shell_spec_variant, 0)
		)
	return ammo_by_shell_id


func clear_peer_control_intent(peer_id: int) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	peer_state["input_left_track"] = 0.0
	peer_state["input_right_track"] = 0.0
	peer_state["input_turret_aim"] = 0.0
	peer_state["pending_fire_request_seq"] = 0
	peer_state["pending_shell_select_seq"] = 0
	peer_state["pending_shell_select_id"] = ""
	players_by_peer_id[peer_id] = peer_state
	return true


func _reset_peer_loadout_to_entry_state(peer_id: int) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var entry_selected_shell_spec: ShellSpec = peer_state.get("entry_selected_shell_spec", null)
	var entry_ammo_by_shell_spec: Dictionary = peer_state.get("entry_ammo_by_shell_spec", {})
	if entry_selected_shell_spec == null or entry_ammo_by_shell_spec.is_empty():
		return false
	peer_state["selected_shell_spec"] = entry_selected_shell_spec
	peer_state["ammo_by_shell_spec"] = entry_ammo_by_shell_spec.duplicate(true)
	peer_state["pending_fire_request_seq"] = 0
	peer_state["pending_shell_select_seq"] = 0
	peer_state["pending_shell_select_id"] = ""
	players_by_peer_id[peer_id] = peer_state
	return true


func remove_peer(peer_id: int, reason: String = "UNKNOWN") -> Dictionary:
	if not players_by_peer_id.has(peer_id):
		return {"removed": false}
	players_by_peer_id.erase(peer_id)
	print(
		(
			"[server][arena] remove_peer peer=%d reason=%s active_players=%d/%d"
			% [peer_id, reason, players_by_peer_id.size(), max_players]
		)
	)
	return {"removed": true}


func get_player_count() -> int:
	return players_by_peer_id.size()


func _validate_requested_loadout(requested_loadout: Dictionary) -> Dictionary:
	var validation_result: Dictionary = {"valid": false, "message": "INVALID TANK CONFIGURATION"}
	var requested_tank_id: String = str(requested_loadout.get("tank_id", "")).strip_edges()
	var requested_shell_loadout_by_id: Dictionary = requested_loadout.get("shell_loadout_by_id", {})
	var requested_selected_shell_id: String = (
		str(requested_loadout.get("selected_shell_id", "")).strip_edges()
	)

	var tank_id: String = requested_tank_id if not requested_tank_id.is_empty() else DEFAULT_TANK_ID
	var tank_spec: TankSpec = TankManager.find_tank_spec(tank_id)
	var ammo_by_shell_spec: Dictionary = {}
	var selected_shell_spec: ShellSpec = null
	var total_shell_count: int = 0
	if tank_spec == null:
		validation_result["message"] = "INVALID TANK"
	elif tank_spec.allowed_shells.is_empty():
		validation_result["message"] = "TANK HAS NO SHELLS"
	else:
		for shell_spec: ShellSpec in tank_spec.allowed_shells:
			var shell_id: String = ShellManager.get_shell_id(shell_spec)
			var requested_count: int = max(0, int(requested_shell_loadout_by_id.get(shell_id, 0)))
			ammo_by_shell_spec[shell_spec] = requested_count
			total_shell_count += requested_count
		if ammo_by_shell_spec.is_empty():
			validation_result["message"] = "NO VALID SHELLS"
		elif total_shell_count <= 0:
			validation_result["message"] = "NO AMMUNITION"
		elif total_shell_count > tank_spec.shell_capacity:
			validation_result["message"] = "SHELL CAPACITY EXCEEDED"
		else:
			selected_shell_spec = _resolve_allowed_shell_spec(
				ammo_by_shell_spec, requested_selected_shell_id
			)
			if selected_shell_spec == null:
				selected_shell_spec = _pick_first_shell_with_ammo(ammo_by_shell_spec)
			if selected_shell_spec == null:
				validation_result["message"] = "NO USABLE SHELL"
			else:
				validation_result["valid"] = true
				validation_result["tank_spec"] = tank_spec
				validation_result["selected_shell_spec"] = selected_shell_spec
				validation_result["ammo_by_shell_spec"] = ammo_by_shell_spec
	return validation_result


func _resolve_allowed_shell_spec(ammo_by_shell_spec: Dictionary, shell_id: String) -> ShellSpec:
	if shell_id.is_empty():
		return null
	var shell_spec: ShellSpec = ShellManager.find_shell_spec(shell_id)
	if shell_spec == null:
		return null
	if not ammo_by_shell_spec.has(shell_spec):
		return null
	if int(ammo_by_shell_spec.get(shell_spec, 0)) <= 0:
		return null
	return shell_spec


func _pick_first_shell_with_ammo(ammo_by_shell_spec: Dictionary) -> ShellSpec:
	for shell_spec_variant: Variant in ammo_by_shell_spec.keys():
		var shell_spec: ShellSpec = shell_spec_variant as ShellSpec
		if shell_spec == null:
			continue
		if int(ammo_by_shell_spec.get(shell_spec_variant, 0)) > 0:
			return shell_spec
	return null
