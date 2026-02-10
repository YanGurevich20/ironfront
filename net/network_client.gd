class_name NetworkClient
extends Node

signal join_status_changed(message: String, is_error: bool)
signal join_arena_completed(success: bool, message: String)

var client_peer: ENetMultiplayerPeer
var default_connect_host: String = "ironfront.vikng.dev"
var default_connect_port: int = 7000
var protocol_version: int = 1
var cancel_join_requested: bool = false
var join_attempt_id: int = 0
var assigned_spawn_position: Vector2 = Vector2.ZERO
var assigned_spawn_rotation: float = 0.0


func _ready() -> void:
	_setup_client_network_logging()


func connect_to_server() -> void:
	join_attempt_id += 1
	cancel_join_requested = false
	_log_join("connect_requested")
	if multiplayer.multiplayer_peer != null:
		if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			multiplayer.multiplayer_peer = null
			_log_join("cleared_offline_multiplayer_peer")
		else:
			var connection_status: MultiplayerPeer.ConnectionStatus = (
				multiplayer.multiplayer_peer.get_connection_status()
			)
			_log_join("existing_peer_status=%d" % connection_status)
			if connection_status == MultiplayerPeer.CONNECTION_CONNECTED:
				_log_join("already_connected -> request_join_arena")
				join_status_changed.emit("CONNECTED. REQUESTING ARENA JOIN...", false)
				_send_join_arena()
				return
			if connection_status == MultiplayerPeer.CONNECTION_CONNECTING:
				_log_join("connect_ignored_connection_in_progress")
				join_status_changed.emit("CONNECTING TO ONLINE SERVER...", false)
				return
			multiplayer.multiplayer_peer = null
			_log_join("cleared_stale_multiplayer_peer")

	if client_peer != null:
		client_peer.close()
		client_peer = null

	var host: String = default_connect_host
	var port: int = default_connect_port

	client_peer = ENetMultiplayerPeer.new()
	var create_error: int = client_peer.create_client(host, port)
	if create_error != OK:
		_log_join("create_client_failed host=%s port=%d error=%d" % [host, port, create_error])
		push_error(
			"%s failed create_client %s:%d error=%d" % [_log_prefix(), host, port, create_error]
		)
		return

	multiplayer.multiplayer_peer = client_peer
	_log_join("connecting_to=udp://%s:%d" % [host, port])
	join_status_changed.emit("CONNECTING TO ONLINE SERVER...", false)


func _setup_client_network_logging() -> void:
	Utils.connect_checked(multiplayer.connected_to_server, _on_connected_to_server)
	Utils.connect_checked(multiplayer.connection_failed, _on_connection_failed)
	Utils.connect_checked(multiplayer.server_disconnected, _on_server_disconnected)
	Utils.connect_checked(multiplayer.peer_connected, _on_peer_connected)
	Utils.connect_checked(multiplayer.peer_disconnected, _on_peer_disconnected)


func _on_connected_to_server() -> void:
	_log_join("connected_to_server unique_peer_id=%d" % multiplayer.get_unique_id())
	join_status_changed.emit("CONNECTED. NEGOTIATING SESSION...", false)
	_send_client_hello()


func _on_connection_failed() -> void:
	if cancel_join_requested:
		_log_join("connection_failed_ignored_due_to_cancel")
		cancel_join_requested = false
		return
	_log_join("connection_failed")
	push_warning("%s connection_failed" % _log_prefix())
	join_status_changed.emit("ONLINE JOIN FAILED: CONNECTION FAILED", true)
	join_arena_completed.emit(false, "CONNECTION FAILED")
	_reset_connection()


func _on_server_disconnected() -> void:
	if cancel_join_requested:
		_log_join("server_disconnected_ignored_due_to_cancel")
		cancel_join_requested = false
		return
	_log_join("server_disconnected")
	push_warning("%s server_disconnected" % _log_prefix())
	join_status_changed.emit("ONLINE JOIN FAILED: SERVER DISCONNECTED", true)
	join_arena_completed.emit(false, "SERVER DISCONNECTED")
	_reset_connection()


func _on_peer_connected(peer_id: int) -> void:
	_log_join("peer_connected id=%d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_log_join("peer_disconnected id=%d" % peer_id)


func _send_client_hello() -> void:
	if multiplayer.multiplayer_peer == null:
		_log_join("skip_send_client_hello no_multiplayer_peer")
		return
	if multiplayer.is_server():
		_log_join("skip_send_client_hello running_as_server")
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var player_name: String = player_data.player_name
	_receive_client_hello.rpc_id(1, protocol_version, player_name)
	_log_join("sent_client_hello protocol=%d player=%s" % [protocol_version, player_name])


func _send_join_arena() -> void:
	if multiplayer.multiplayer_peer == null:
		_log_join("skip_send_join_arena no_multiplayer_peer")
		return
	if multiplayer.is_server():
		_log_join("skip_send_join_arena running_as_server")
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var player_name: String = player_data.player_name
	_join_arena.rpc_id(1, player_name)
	_log_join("sent_join_arena player=%s" % player_name)


func cancel_join_request() -> void:
	if multiplayer.multiplayer_peer == null and client_peer == null:
		_log_join("cancel_ignored_no_active_connection")
		return
	cancel_join_requested = true
	_log_join("cancel_requested_resetting_connection")
	_reset_connection()
	join_arena_completed.emit(false, "CANCELED")


func _reset_connection() -> void:
	_log_join("reset_connection begin")
	if client_peer != null:
		client_peer.close()
		client_peer = null
	multiplayer.multiplayer_peer = null
	assigned_spawn_position = Vector2.ZERO
	assigned_spawn_rotation = 0.0
	_log_join("reset_connection complete")


@rpc("authority", "reliable")
func _receive_server_hello_ack(server_protocol_version: int, server_unix_time: int) -> void:
	if multiplayer.is_server():
		return
	_log_join(
		(
			"received_server_hello_ack protocol=%d server_time=%d"
			% [server_protocol_version, server_unix_time]
		)
	)
	if server_protocol_version != protocol_version:
		_log_join(
			(
				"server_hello_ack_protocol_mismatch client=%d server=%d"
				% [protocol_version, server_protocol_version]
			)
		)
		join_status_changed.emit("ONLINE JOIN FAILED: PROTOCOL MISMATCH", true)
		join_arena_completed.emit(false, "PROTOCOL MISMATCH")
		_reset_connection()
		return
	join_status_changed.emit("CONNECTED. REQUESTING ARENA JOIN...", false)
	_send_join_arena()


@rpc("any_peer", "reliable")
func _receive_client_hello(client_protocol_version: int, player_name: String) -> void:
	# This method exists so RPC path signatures stay valid on both peers.
	push_warning(
		(
			"%s unexpected client_hello protocol=%d player=%s"
			% [_log_prefix(), client_protocol_version, player_name]
		)
	)


@rpc("any_peer", "reliable")
func _join_arena(player_name: String) -> void:
	# This method exists so RPC path signatures stay valid on both peers.
	_log_join("unexpected_join_arena player=%s" % player_name)
	push_warning("%s unexpected join_arena player=%s" % [_log_prefix(), player_name])


@rpc("authority", "reliable")
func _join_arena_ack(
	success: bool, message: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	if multiplayer.is_server():
		return
	if cancel_join_requested:
		_log_join(
			(
				(
					"join_arena_ack_ignored_due_to_cancel success=%s message=%s "
					+ "spawn_position=%s spawn_rotation=%.4f"
				)
				% [success, message, spawn_position, spawn_rotation]
			)
		)
		cancel_join_requested = false
		return
	var log_message: String = (
		("%s join_arena_ack success=%s message=%s " + "spawn_position=%s spawn_rotation=%.4f")
		% [_log_prefix(), success, message, spawn_position, spawn_rotation]
	)
	_log_join("received_%s" % log_message)
	if success:
		assigned_spawn_position = spawn_position
		assigned_spawn_rotation = spawn_rotation
		print(log_message)
		join_status_changed.emit("ONLINE JOIN SUCCESS: %s" % message, false)
	else:
		push_warning(log_message)
		join_status_changed.emit("ONLINE JOIN FAILED: %s" % message, true)
		_reset_connection()
	join_arena_completed.emit(success, message)


func _log_join(message: String) -> void:
	print("%s[join:%d] %s" % [_log_prefix(), join_attempt_id, message])


func _log_prefix() -> String:
	return "[client pid=%d peer=%d]" % [OS.get_process_id(), _get_safe_peer_id()]


func _get_safe_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()
