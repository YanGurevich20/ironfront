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

const ARENA_SESSION_RUNTIME_SCENE: PackedScene = preload(
	"res://src/client/arena/runtime/arena_session_runtime.tscn"
)

var default_connect_host: String = "ironfront.vikng.dev"
var default_connect_port: int = 7000
var protocol_version: int = MultiplayerProtocol.PROTOCOL_VERSION
var phase: ArenaPhase = ArenaPhase.DISCONNECTED
var cancel_join_requested: bool = false
var runtime: ArenaSessionRuntime

var enet_client: ENetClient
var session_api: ClientSessionApi
var gameplay_api: ClientGameplayApi
var level_container: Node2D


func configure_dependencies(
	next_enet_client: ENetClient,
	next_session_api: ClientSessionApi,
	next_gameplay_api: ClientGameplayApi,
	next_level_container: Node2D
) -> void:
	enet_client = next_enet_client
	session_api = next_session_api
	gameplay_api = next_gameplay_api
	level_container = next_level_container


func _ready() -> void:
	assert(enet_client != null, "ArenaClient missing ENetClient dependency")
	assert(session_api != null, "ArenaClient missing ClientSessionApi dependency")
	assert(gameplay_api != null, "ArenaClient missing ClientGameplayApi dependency")
	assert(level_container != null, "ArenaClient missing level_container dependency")
	Utils.connect_checked(multiplayer.connected_to_server, _on_connected_to_server)
	Utils.connect_checked(
		multiplayer.connection_failed, func() -> void: _on_connection_ended("CONNECTION FAILED")
	)
	Utils.connect_checked(
		multiplayer.server_disconnected, func() -> void: _on_connection_ended("SERVER DISCONNECTED")
	)
	Utils.connect_checked(session_api.server_hello_ack_received, _on_server_hello_ack_received)
	Utils.connect_checked(session_api.join_arena_ack_received, _on_join_arena_ack_received)


func is_active() -> bool:
	return phase == ArenaPhase.ACTIVE and runtime != null


func connect_to_server() -> void:
	cancel_join_requested = false
	if runtime != null:
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
	if runtime != null:
		return
	if phase == ArenaPhase.DISCONNECTED:
		return
	cancel_join_requested = true
	_reset_to_disconnected()
	join_completed.emit(false, "CANCELED")


func request_respawn() -> void:
	if runtime == null:
		return
	runtime.request_respawn()


func stop_session() -> void:
	_leave_arena()


func end_session(status_message: String) -> void:
	if runtime == null:
		return
	var summary: Dictionary = runtime.build_summary(status_message)
	runtime.apply_rewards()
	GameplayBus.level_finished.emit()
	_leave_arena()
	session_ended.emit(summary)


func _send_join_arena() -> void:
	var join_loadout_payload: Dictionary = Account.loadout.to_join_arena_payload()
	session_api.send_join_arena(Account.username, join_loadout_payload)


func _start_arena(spawn_position: Vector2, spawn_rotation: float) -> bool:
	_teardown_runtime()
	var next_runtime: ArenaSessionRuntime = ARENA_SESSION_RUNTIME_SCENE.instantiate()
	runtime = next_runtime
	runtime.configure(gameplay_api, enet_client, level_container)
	add_child(runtime)
	Utils.connect_checked(runtime.local_player_destroyed, _on_local_player_destroyed)
	Utils.connect_checked(runtime.local_player_respawned, _on_local_player_respawned)
	if not runtime.start_session(spawn_position, spawn_rotation):
		_teardown_runtime()
		return false
	phase = ArenaPhase.ACTIVE
	return true


func _leave_arena() -> void:
	if runtime != null and enet_client.is_connected_to_server():
		session_api.send_leave_arena()
	phase = ArenaPhase.DISCONNECTED
	_teardown_runtime()


func _on_connected_to_server() -> void:
	if phase != ArenaPhase.CONNECTING:
		return
	phase = ArenaPhase.NEGOTIATING
	join_status_changed.emit("CONNECTED. NEGOTIATING SESSION...", false)
	session_api.send_client_hello(protocol_version, Account.username)


func _on_connection_ended(reason: String) -> void:
	if cancel_join_requested:
		cancel_join_requested = false
		return
	if runtime != null:
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


func _on_local_player_destroyed() -> void:
	local_player_destroyed.emit()


func _on_local_player_respawned() -> void:
	local_player_respawned.emit()


func _emit_join_failed(reason: String) -> void:
	join_status_changed.emit("ONLINE JOIN FAILED: %s" % reason, true)
	join_completed.emit(false, reason)


func _reset_to_disconnected() -> void:
	enet_client.reset_connection()
	phase = ArenaPhase.DISCONNECTED
	_teardown_runtime()


func _teardown_runtime() -> void:
	if runtime == null:
		return
	runtime.stop_session()
	runtime.queue_free()
	runtime = null
