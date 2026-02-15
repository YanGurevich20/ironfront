class_name NetworkClientJoinAckUtils
extends RefCounted


static func handle_join_arena_ack(
	network_client: NetworkClient,
	success: bool,
	message: String,
	spawn_position: Vector2,
	spawn_rotation: float
) -> void:
	if network_client.cancel_join_requested:
		network_client._log_join("join_arena_ack_ignored_due_to_cancel")
		network_client.cancel_join_requested = false
		return
	network_client._log_join("join_arena_ack success=%s message=%s" % [success, message])
	if success:
		network_client.assigned_spawn_position = spawn_position
		network_client.assigned_spawn_rotation = spawn_rotation
		network_client.arena_membership_active = true
		network_client.join_status_changed.emit("ONLINE JOIN SUCCESS: %s" % message, false)
	else:
		network_client.arena_membership_active = false
		push_warning("[client] join_arena_ack_failed message=%s" % message)
		network_client.join_status_changed.emit("ONLINE JOIN FAILED: %s" % message, true)
		network_client._reset_connection()
	network_client.join_arena_completed.emit(success, message)
