class_name NetworkClientKillFeedUtils
extends RefCounted


static func handle_kill_event_payload(kill_event_payload: Dictionary) -> void:
	var event_seq: int = int(kill_event_payload.get("event_seq", 0))
	var killer_peer_id: int = int(kill_event_payload.get("killer_peer_id", 0))
	var killer_name: String = str(kill_event_payload.get("killer_name", ""))
	var killer_tank_name: String = str(kill_event_payload.get("killer_tank_name", ""))
	var shell_short_name: String = str(kill_event_payload.get("shell_short_name", ""))
	var victim_peer_id: int = int(kill_event_payload.get("victim_peer_id", 0))
	var victim_name: String = str(kill_event_payload.get("victim_name", ""))
	var victim_tank_name: String = str(kill_event_payload.get("victim_tank_name", ""))
	GameplayBus.online_kill_feed_event.emit(
		event_seq,
		killer_peer_id,
		killer_name,
		killer_tank_name,
		shell_short_name,
		victim_peer_id,
		victim_name,
		victim_tank_name
	)
