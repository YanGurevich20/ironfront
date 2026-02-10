class_name NetworkClient
extends Node

var client_peer: ENetMultiplayerPeer
var default_connect_host: String = "ironfront.vikng.dev"
var default_connect_port: int = 7000
var protocol_version: int = 1


func _ready() -> void:
	_setup_client_network_logging()


func connect_to_server() -> void:
	if multiplayer.multiplayer_peer != null:
		var connection_status: MultiplayerPeer.ConnectionStatus = (
			multiplayer.multiplayer_peer.get_connection_status()
		)
		if connection_status != MultiplayerPeer.CONNECTION_DISCONNECTED:
			print("[client] connect_to_server ignored: connection already active")
			return
		multiplayer.multiplayer_peer = null

	if client_peer != null:
		client_peer.close()
		client_peer = null

	var host: String = default_connect_host
	var port: int = default_connect_port

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--connect-host="):
			host = arg.trim_prefix("--connect-host=")
		elif arg.begins_with("--connect-port="):
			var parsed_port: int = int(arg.trim_prefix("--connect-port="))
			if parsed_port > 0:
				port = parsed_port

	client_peer = ENetMultiplayerPeer.new()
	var create_error: int = client_peer.create_client(host, port)
	if create_error != OK:
		push_error("[client] failed create_client %s:%d error=%d" % [host, port, create_error])
		return

	multiplayer.multiplayer_peer = client_peer
	print("[client] connecting to udp://%s:%d" % [host, port])


func _setup_client_network_logging() -> void:
	Utils.connect_checked(multiplayer.connected_to_server, _on_connected_to_server)
	Utils.connect_checked(multiplayer.connection_failed, _on_connection_failed)
	Utils.connect_checked(multiplayer.server_disconnected, _on_server_disconnected)
	Utils.connect_checked(multiplayer.peer_connected, _on_peer_connected)
	Utils.connect_checked(multiplayer.peer_disconnected, _on_peer_disconnected)


func _on_connected_to_server() -> void:
	print("[client] connected_to_server server_peer_id=%d" % multiplayer.get_unique_id())
	_send_client_hello()


func _on_connection_failed() -> void:
	push_warning("[client] connection_failed")
	_reset_connection()


func _on_server_disconnected() -> void:
	push_warning("[client] server_disconnected")
	_reset_connection()


func _on_peer_connected(peer_id: int) -> void:
	print("[client] peer_connected id=%d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[client] peer_disconnected id=%d" % peer_id)


func _send_client_hello() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var player_name: String = player_data.player_name
	_receive_client_hello.rpc_id(1, protocol_version, player_name)
	print("[client] sent client_hello protocol=%d player=%s" % [protocol_version, player_name])


func _reset_connection() -> void:
	if client_peer != null:
		client_peer.close()
		client_peer = null
	multiplayer.multiplayer_peer = null


@rpc("authority", "reliable")
func _receive_server_hello_ack(server_protocol_version: int, server_unix_time: int) -> void:
	if multiplayer.is_server():
		return
	print(
		(
			"[client] server_hello_ack protocol=%d server_time=%d"
			% [server_protocol_version, server_unix_time]
		)
	)


@rpc("any_peer", "reliable")
func _receive_client_hello(client_protocol_version: int, player_name: String) -> void:
	# This method exists so RPC path signatures stay valid on both peers.
	push_warning(
		(
			"[client] unexpected client_hello protocol=%d player=%s"
			% [client_protocol_version, player_name]
		)
	)
