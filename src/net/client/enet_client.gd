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


func is_connected_to_server() -> bool:
	return NetworkClientConnectionUtils.is_connected_to_server(multiplayer)


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
