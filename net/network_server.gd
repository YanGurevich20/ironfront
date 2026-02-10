class_name NetworkServer
extends Node

var server_peer: ENetMultiplayerPeer
var protocol_version: int = 1


func start_server(listen_port: int, max_clients: int) -> bool:
	server_peer = ENetMultiplayerPeer.new()
	var error_code: int = server_peer.create_server(listen_port, max_clients)
	if error_code != OK:
		push_error("Server failed to start on port %d (error %d)" % [listen_port, error_code])
		return false

	multiplayer.multiplayer_peer = server_peer
	Utils.connect_checked(multiplayer.peer_connected, _on_peer_connected)
	Utils.connect_checked(multiplayer.peer_disconnected, _on_peer_disconnected)
	Utils.connect_checked(multiplayer.connected_to_server, _on_connected_to_server)
	Utils.connect_checked(multiplayer.connection_failed, _on_connection_failed)
	Utils.connect_checked(multiplayer.server_disconnected, _on_server_disconnected)

	print("[server] listening on udp://0.0.0.0:%d max_clients=%d" % [listen_port, max_clients])
	return true


func _on_peer_connected(peer_id: int) -> void:
	print("[server] peer_connected id=%d peers=%d" % [peer_id, multiplayer.get_peers().size()])


func _on_peer_disconnected(peer_id: int) -> void:
	print("[server] peer_disconnected id=%d peers=%d" % [peer_id, multiplayer.get_peers().size()])


func _on_connected_to_server() -> void:
	push_warning("connected_to_server signal fired in server process")


func _on_connection_failed() -> void:
	push_warning("connection_failed signal fired in server process")


func _on_server_disconnected() -> void:
	push_warning("server_disconnected signal fired in server process")


@rpc("any_peer", "reliable")
func _receive_client_hello(client_protocol_version: int, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	print(
		(
			"[server] client_hello peer=%d protocol=%d player=%s"
			% [peer_id, client_protocol_version, player_name]
		)
	)
	_receive_server_hello_ack.rpc_id(peer_id, protocol_version, Time.get_unix_time_from_system())


@rpc("authority", "reliable")
func _receive_server_hello_ack(server_protocol_version: int, server_unix_time: int) -> void:
	# This method exists so RPC path signatures stay valid on both peers.
	push_warning(
		(
			"[server] unexpected server_hello_ack protocol=%d server_time=%d"
			% [server_protocol_version, server_unix_time]
		)
	)
