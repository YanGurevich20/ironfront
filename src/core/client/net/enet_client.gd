class_name ENetClient
extends Node

var client_peer: ENetMultiplayerPeer


func connect_to_server(host: String, port: int) -> bool:
	reset_connection()
	client_peer = ENetMultiplayerPeer.new()
	var create_error: int = client_peer.create_client(host, port)
	if create_error != OK:
		push_error("[client] failed create_client %s:%d error=%d" % [host, port, create_error])
		client_peer = null
		return false
	multiplayer.multiplayer_peer = client_peer
	return true


func reset_connection() -> void:
	if client_peer != null:
		client_peer.close()
		client_peer = null
	multiplayer.multiplayer_peer = null


func get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	if multiplayer.multiplayer_peer == null:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	return multiplayer.multiplayer_peer.get_connection_status()


func resolve_cli_connect_target(default_host: String, default_port: int) -> Dictionary:
	var client_args: Dictionary = Utils.get_parsed_cmdline_user_args()
	var resolved_host: String = str(client_args.get("host", default_host))
	var resolved_port: int = max(0, int(client_args.get("port", default_port)))
	print("[client][cli] resolved_host=%s resolved_port=%d" % [resolved_host, resolved_port])
	return {"host": resolved_host, "port": resolved_port}


func ensure_connecting(default_host: String, default_port: int) -> Dictionary:
	var connection_status: MultiplayerPeer.ConnectionStatus = get_connection_status()
	if connection_status == MultiplayerPeer.CONNECTION_CONNECTED:
		return {"status": "already_connected"}
	if connection_status == MultiplayerPeer.CONNECTION_CONNECTING:
		return {"status": "already_connecting"}
	reset_connection()
	var target: Dictionary = resolve_cli_connect_target(default_host, default_port)
	var host: String = str(target.get("host", default_host))
	var port: int = int(target.get("port", default_port))
	if not connect_to_server(host, port):
		return {"status": "failed", "host": host, "port": port}
	return {"status": "started", "host": host, "port": port}


func is_connected_to_server() -> bool:
	return get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func get_connection_ping_msec() -> int:
	if not is_connected_to_server():
		return -1
	var enet_peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer
	if enet_peer == null:
		return -1
	var server_packet_peer: ENetPacketPeer = enet_peer.get_peer(1)
	if server_packet_peer == null:
		return -1
	return int(server_packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
