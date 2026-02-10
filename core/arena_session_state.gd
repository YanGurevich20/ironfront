class_name ArenaSessionState
extends RefCounted

var max_players: int = 10
var created_unix_time: float = 0.0
var players_by_peer_id: Dictionary = {}


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
