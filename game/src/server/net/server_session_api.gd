class_name ServerSessionApi
extends Node

signal arena_join_requested(peer_id: int, player_name: String, requested_loadout: Dictionary)
signal arena_leave_requested(peer_id: int)

var protocol_version: int = MultiplayerProtocol.PROTOCOL_VERSION


func configure_protocol(next_protocol_version: int) -> void:
	protocol_version = next_protocol_version


@rpc("authority", "reliable")
func _receive_server_hello_ack(_server_protocol_version: int, _server_unix_time: int) -> void:
	push_warning("[server][session] unexpected RPC: _receive_server_hello_ack")


@rpc("any_peer", "reliable")
func _receive_client_hello(client_protocol_version: int, player_name: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	print("[server][join] client_hello peer=%d protocol=%d" % [peer_id, client_protocol_version])
	print("[server] client_hello peer=%d player=%s" % [peer_id, player_name])
	_receive_server_hello_ack.rpc_id(peer_id, protocol_version, Time.get_unix_time_from_system())


@rpc("any_peer", "reliable")
func _join_arena(player_name: String, requested_loadout: Dictionary) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	arena_join_requested.emit(peer_id, player_name, requested_loadout)


@rpc("any_peer", "reliable")
func _leave_arena() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	arena_leave_requested.emit(peer_id)


@rpc("authority", "reliable")
func _join_arena_ack(
	_success: bool, _message: String, _spawn_position: Vector2, _spawn_rotation: float
) -> void:
	push_warning("[server][session] unexpected RPC: _join_arena_ack")


@rpc("authority", "reliable")
func _leave_arena_ack(_success: bool, _message: String) -> void:
	push_warning("[server][session] unexpected RPC: _leave_arena_ack")


func complete_arena_join(
	peer_id: int, join_message: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	_join_arena_ack.rpc_id(peer_id, true, join_message, spawn_position, spawn_rotation)


func reject_arena_join(peer_id: int, join_message: String) -> void:
	_join_arena_ack.rpc_id(peer_id, false, join_message, Vector2.ZERO, 0.0)


func complete_arena_leave(peer_id: int, leave_message: String) -> void:
	_leave_arena_ack.rpc_id(peer_id, true, leave_message)
