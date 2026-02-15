class_name NetworkClientConnectionUtils
extends RefCounted


static func is_connected_to_server(multiplayer_api: MultiplayerAPI) -> bool:
	if multiplayer_api.multiplayer_peer == null:
		return false
	return (
		multiplayer_api.multiplayer_peer.get_connection_status()
		== MultiplayerPeer.CONNECTION_CONNECTED
	)


static func resolve_cli_connect_target(default_host: String, default_port: int) -> Dictionary:
	var client_args: Dictionary = Utils.get_parsed_cmdline_user_args()
	var resolved_host: String = client_args.get("host", default_host)
	var resolved_port: int = max(0, int(client_args.get("port", default_port)))
	print("[client][cli] resolved_host=%s resolved_port=%d" % [resolved_host, resolved_port])
	return {"host": resolved_host, "port": resolved_port}
