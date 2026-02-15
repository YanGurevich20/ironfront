class_name ArenaClient
extends Node

signal join_status_changed(message: String, is_error: bool)
signal join_completed(success: bool, message: String)
signal session_ended(summary: Dictionary)
signal local_player_destroyed
signal local_player_respawned

enum ArenaPhase {
	DISCONNECTED,
	CONNECTING,
	NEGOTIATING,
	JOINING,
	ACTIVE,
}

const KILL_REWARD_DOLLARS: int = 5000

var default_connect_host: String = "ironfront.vikng.dev"
var default_connect_port: int = 7000
var protocol_version: int = MultiplayerProtocol.PROTOCOL_VERSION
var phase: ArenaPhase = ArenaPhase.DISCONNECTED
var cancel_join_requested: bool = false
var arena_membership_active: bool = false
var reward_tracker: RewardTracker = RewardTracker.new(KILL_REWARD_DOLLARS)

@onready var enet_client: ENetClient = %Network
@onready var session_api: ClientSessionApi = %Session
@onready var gameplay_api: ClientGameplayApi = %Gameplay
@onready var world: ArenaWorld = %ArenaWorld
@onready var input_sync: ArenaInputSync = %ArenaInputSync


func _ready() -> void:
	assert(enet_client != null, "ArenaClient requires %Network")
	assert(session_api != null, "ArenaClient requires %Session")
	assert(gameplay_api != null, "ArenaClient requires %Gameplay")
	assert(world != null, "ArenaClient requires %ArenaWorld")
	assert(input_sync != null, "ArenaClient requires %ArenaInputSync")
	world.configure_level_container(%LevelContainer)
	input_sync.configure(gameplay_api, enet_client, world)
	Utils.connect_checked(
		multiplayer.connected_to_server,
		func() -> void:
			if phase != ArenaPhase.CONNECTING:
				return
			phase = ArenaPhase.NEGOTIATING
			join_status_changed.emit("CONNECTED. NEGOTIATING SESSION...", false)
			var player_data: PlayerData = PlayerData.get_instance()
			session_api.send_client_hello(protocol_version, player_data.player_name)
	)
	Utils.connect_checked(
		multiplayer.connection_failed, func() -> void: _on_connection_ended("CONNECTION FAILED")
	)
	Utils.connect_checked(
		multiplayer.server_disconnected, func() -> void: _on_connection_ended("SERVER DISCONNECTED")
	)
	Utils.connect_checked(session_api.server_hello_ack_received, _on_server_hello_ack_received)
	Utils.connect_checked(session_api.join_arena_ack_received, _on_join_arena_ack_received)
	Utils.connect_checked(gameplay_api.state_snapshot_received, _on_state_snapshot_received)
	Utils.connect_checked(
		gameplay_api.arena_fire_rejected_received, _on_arena_fire_rejected_received
	)
	Utils.connect_checked(gameplay_api.arena_kill_event_received, _on_arena_kill_event_received)
	Utils.connect_checked(
		gameplay_api.arena_shell_spawn_received, world.handle_shell_spawn_received
	)
	Utils.connect_checked(
		gameplay_api.arena_shell_impact_received, world.handle_shell_impact_received
	)
	Utils.connect_checked(gameplay_api.arena_respawn_received, world.handle_remote_respawn_received)
	Utils.connect_checked(
		gameplay_api.arena_loadout_state_received, world.handle_loadout_state_received
	)
	Utils.connect_checked(world.local_player_destroyed, _on_local_player_destroyed)
	Utils.connect_checked(world.local_player_respawned, _on_local_player_respawned)


func is_active() -> bool:
	return phase == ArenaPhase.ACTIVE


func connect_to_server() -> void:
	cancel_join_requested = false
	if is_active():
		return
	var connect_result: Dictionary = enet_client.ensure_connecting(
		default_connect_host, default_connect_port
	)
	var status: String = str(connect_result.get("status", "failed"))
	if status == "already_connected":
		phase = ArenaPhase.JOINING
		join_status_changed.emit("CONNECTED. REQUESTING ARENA JOIN...", false)
		_send_join_arena()
		return
	if status == "already_connecting":
		phase = ArenaPhase.CONNECTING
		join_status_changed.emit("CONNECTING TO ONLINE SERVER...", false)
		return
	if status == "failed":
		_emit_join_failed("CONNECTION FAILED")
		_reset_to_disconnected()
		return
	phase = ArenaPhase.CONNECTING
	join_status_changed.emit("CONNECTING TO ONLINE SERVER...", false)


func cancel_join_request() -> void:
	if is_active():
		return
	if phase == ArenaPhase.DISCONNECTED:
		return
	cancel_join_requested = true
	_reset_to_disconnected()
	join_completed.emit(false, "CANCELED")


func request_respawn() -> void:
	if not is_active():
		return
	if not world.is_local_player_dead():
		return
	if not arena_membership_active:
		return
	if not input_sync.can_send_gameplay_requests():
		return
	gameplay_api.request_respawn()


func stop_session() -> void:
	if not is_active():
		return
	_leave_arena()


func end_session(status_message: String) -> void:
	if not is_active():
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var summary: Dictionary = reward_tracker.build_summary(status_message)
	reward_tracker.apply_rewards(player_data)
	GameplayBus.level_finished_and_saved.emit()
	_leave_arena()
	reward_tracker.reset()
	session_ended.emit(summary)


func _send_join_arena() -> void:
	var player_data: PlayerData = PlayerData.get_instance()
	var join_loadout_payload: Dictionary = player_data.build_join_arena_payload()
	var selected_tank_id: int = int(
		join_loadout_payload.get("tank_id", ArenaSessionState.DEFAULT_TANK_ID)
	)
	session_api.send_join_arena(
		player_data.player_name,
		selected_tank_id,
		join_loadout_payload.get("shell_loadout_by_id", {}),
		str(join_loadout_payload.get("selected_shell_id", ""))
	)


func _start_arena(spawn_position: Vector2, spawn_rotation: float) -> bool:
	if not world.activate(spawn_position, spawn_rotation):
		return false
	phase = ArenaPhase.ACTIVE
	arena_membership_active = true
	reward_tracker.reset()
	input_sync.activate()
	GameplayBus.level_started.emit()
	return true


func _leave_arena() -> void:
	if arena_membership_active and enet_client.is_connected_to_server():
		session_api.send_leave_arena()
	arena_membership_active = false
	phase = ArenaPhase.DISCONNECTED
	input_sync.deactivate()
	world.deactivate()


func _on_connection_ended(reason: String) -> void:
	if cancel_join_requested:
		cancel_join_requested = false
		return
	if phase == ArenaPhase.ACTIVE:
		push_warning("[client] %s during active arena session" % reason.to_lower())
		_leave_arena()
		return
	push_warning("[client] %s" % reason.to_lower())
	_emit_join_failed(reason)
	_reset_to_disconnected()


func _on_server_hello_ack_received(server_protocol_version: int, _server_unix_time: int) -> void:
	if phase != ArenaPhase.NEGOTIATING:
		return
	if server_protocol_version != protocol_version:
		_emit_join_failed("PROTOCOL MISMATCH")
		_reset_to_disconnected()
		return
	phase = ArenaPhase.JOINING
	join_status_changed.emit("CONNECTED. REQUESTING ARENA JOIN...", false)
	_send_join_arena()


func _on_join_arena_ack_received(
	success: bool, message: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	if phase != ArenaPhase.JOINING:
		return
	if cancel_join_requested:
		cancel_join_requested = false
		return
	if not success:
		push_warning("[client] join_arena_ack_failed message=%s" % message)
		_emit_join_failed(message)
		_reset_to_disconnected()
		return
	join_status_changed.emit("ONLINE JOIN SUCCESS: %s" % message, false)
	if not _start_arena(spawn_position, spawn_rotation):
		join_completed.emit(false, "ARENA BOOTSTRAP FAILED")
		_reset_to_disconnected()
		return
	join_completed.emit(true, message)


func _on_state_snapshot_received(server_tick: int, player_states: Array, max_players: int) -> void:
	if not is_active():
		return
	world.apply_state_snapshot(server_tick, player_states)
	var active_human_players: int = 0
	var active_bots: int = 0
	for player_state_variant: Variant in player_states:
		var player_state: Dictionary = player_state_variant
		if bool(player_state.get("is_bot", false)):
			active_bots += int(bool(player_state.get("is_alive", true)))
			continue
		active_human_players += 1
	GameplayBus.online_player_count_updated.emit(active_human_players, max_players, active_bots)


func _on_arena_fire_rejected_received(reason: String) -> void:
	if not is_active():
		return
	GameplayBus.online_fire_rejected.emit(reason)


func _on_arena_kill_event_received(kill_event_payload: Dictionary) -> void:
	if not is_active():
		return
	var event_seq: int = int(kill_event_payload.get("event_seq", 0))
	var killer_peer_id: int = int(kill_event_payload.get("killer_peer_id", 0))
	var killer_name: String = str(kill_event_payload.get("killer_name", ""))
	var killer_tank_name: String = str(kill_event_payload.get("killer_tank_name", ""))
	var shell_short_name: String = str(kill_event_payload.get("shell_short_name", ""))
	var victim_peer_id: int = int(kill_event_payload.get("victim_peer_id", 0))
	var victim_name: String = str(kill_event_payload.get("victim_name", ""))
	var victim_tank_name: String = str(kill_event_payload.get("victim_tank_name", ""))
	reward_tracker.on_kill_feed_event(
		event_seq,
		killer_peer_id,
		killer_name,
		killer_tank_name,
		shell_short_name,
		victim_peer_id,
		victim_name,
		victim_tank_name,
		multiplayer.get_unique_id()
	)
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


func _on_local_player_destroyed() -> void:
	if not is_active():
		return
	input_sync.deactivate(false)
	local_player_destroyed.emit()


func _on_local_player_respawned() -> void:
	if not is_active():
		return
	input_sync.activate(false)
	local_player_respawned.emit()


func _emit_join_failed(reason: String) -> void:
	join_status_changed.emit("ONLINE JOIN FAILED: %s" % reason, true)
	join_completed.emit(false, reason)


func _reset_to_disconnected() -> void:
	enet_client.reset_connection()
	arena_membership_active = false
	phase = ArenaPhase.DISCONNECTED
	input_sync.deactivate()
	world.deactivate()
