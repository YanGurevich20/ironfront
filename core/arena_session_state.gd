class_name ArenaSessionState
extends RefCounted

var max_players: int = 10
var created_unix_time: float = 0.0
var players_by_peer_id: Dictionary[int, Dictionary] = {}


func _init(max_player_count: int = 10) -> void:
	max_players = max(1, max_player_count)
	created_unix_time = Time.get_unix_time_from_system()


func try_join_peer(peer_id: int, player_name: String) -> Dictionary:
	if players_by_peer_id.has(peer_id):
		return {"success": false, "message": "ALREADY JOINED ARENA"}

	if players_by_peer_id.size() >= max_players:
		return {"success": false, "message": "ARENA FULL"}

	players_by_peer_id[peer_id] = {
		"peer_id": peer_id,
		"player_name": player_name,
		"joined_unix_time": Time.get_unix_time_from_system(),
		"assigned_spawn_id": StringName(),
		"state_position": Vector2.ZERO,
		"state_rotation": 0.0,
		"state_linear_velocity": Vector2.ZERO,
		"input_left_track": 0.0,
		"input_right_track": 0.0,
		"input_turret_aim": 0.0,
		"input_fire_pressed": false,
		"last_input_tick": 0,
		"last_input_received_msec": 0,
	}
	return {"success": true, "message": "JOINED GLOBAL ARENA"}


func set_peer_spawn_id(peer_id: int, spawn_id: StringName) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	peer_state["assigned_spawn_id"] = spawn_id
	players_by_peer_id[peer_id] = peer_state
	return true


func get_peer_spawn_id(peer_id: int) -> StringName:
	if not players_by_peer_id.has(peer_id):
		return StringName()
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	return peer_state.get("assigned_spawn_id", StringName())


func has_peer(peer_id: int) -> bool:
	return players_by_peer_id.has(peer_id)


func get_peer_ids() -> Array[int]:
	return players_by_peer_id.keys()


func get_peer_state(peer_id: int) -> Dictionary:
	if not players_by_peer_id.has(peer_id):
		return {}
	return players_by_peer_id[peer_id]


func set_peer_authoritative_state(
	peer_id: int, position: Vector2, rotation: float, linear_velocity: Vector2
) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	peer_state["state_position"] = position
	peer_state["state_rotation"] = rotation
	peer_state["state_linear_velocity"] = linear_velocity
	players_by_peer_id[peer_id] = peer_state
	return true


func get_peer_last_input_tick(peer_id: int) -> int:
	if not players_by_peer_id.has(peer_id):
		return 0
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	return int(peer_state.get("last_input_tick", 0))


func set_peer_input_intent(
	peer_id: int,
	input_tick: int,
	left_track_input: float,
	right_track_input: float,
	turret_aim: float,
	fire_pressed: bool,
	received_msec: int
) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	var peer_state: Dictionary = players_by_peer_id[peer_id]
	var last_input_tick: int = int(peer_state.get("last_input_tick", 0))
	if input_tick <= last_input_tick:
		return false
	peer_state["input_left_track"] = left_track_input
	peer_state["input_right_track"] = right_track_input
	peer_state["input_turret_aim"] = turret_aim
	peer_state["input_fire_pressed"] = fire_pressed
	peer_state["last_input_tick"] = input_tick
	peer_state["last_input_received_msec"] = received_msec
	players_by_peer_id[peer_id] = peer_state
	return true


func remove_peer(peer_id: int, reason: String = "UNKNOWN") -> Dictionary:
	if not players_by_peer_id.has(peer_id):
		return {"removed": false, "spawn_id": StringName()}
	var spawn_id: StringName = get_peer_spawn_id(peer_id)
	players_by_peer_id.erase(peer_id)
	print(
		(
			"[server][arena] remove_peer peer=%d reason=%s active_players=%d/%d"
			% [peer_id, reason, players_by_peer_id.size(), max_players]
		)
	)
	return {"removed": true, "spawn_id": spawn_id}


func get_player_count() -> int:
	return players_by_peer_id.size()
