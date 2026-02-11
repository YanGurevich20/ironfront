class_name ClientRuntimeUtils
extends RefCounted


static func build_log_prefix(multiplayer_api: MultiplayerAPI) -> String:
	var peer_id: int = 0
	if multiplayer_api.multiplayer_peer != null:
		peer_id = multiplayer_api.get_unique_id()
	return "[client pid=%d peer=%d]" % [OS.get_process_id(), peer_id]
