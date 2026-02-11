class_name NetworkClientConnectionUtils
extends RefCounted


static func get_safe_peer_id(multiplayer_api: MultiplayerAPI) -> int:
	if multiplayer_api.multiplayer_peer == null:
		return 0
	return multiplayer_api.get_unique_id()


static func is_connected_to_server(multiplayer_api: MultiplayerAPI) -> bool:
	if multiplayer_api.multiplayer_peer == null:
		return false
	return (
		multiplayer_api.multiplayer_peer.get_connection_status()
		== MultiplayerPeer.CONNECTION_CONNECTED
	)


static func can_send_input_intents(
	multiplayer_api: MultiplayerAPI, arena_input_enabled: bool
) -> bool:
	return arena_input_enabled and is_connected_to_server(multiplayer_api)


static func get_connection_ping_msec(
	multiplayer_api: MultiplayerAPI, arena_input_enabled: bool
) -> int:
	if not can_send_input_intents(multiplayer_api, arena_input_enabled):
		return -1
	var enet_peer: ENetMultiplayerPeer = multiplayer_api.multiplayer_peer as ENetMultiplayerPeer
	if enet_peer == null:
		return -1
	var server_packet_peer: ENetPacketPeer = enet_peer.get_peer(1)
	if server_packet_peer == null:
		return -1
	return int(server_packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
