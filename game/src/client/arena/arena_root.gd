class_name ArenaRoot
extends Node

signal arena_finished(summary: Dictionary)
signal return_to_garage_requested
signal logout_requested
signal settings_requested

var _last_session_summary: Dictionary = {}
var _online_session_active: bool = false

var _enet_client: ENetClient
var _session_api: ClientSessionApi
var _gameplay_api: ClientGameplayApi

@onready var arena_client: ArenaClient = $ArenaClient
@onready var battle_interface: BattleInterface = %BattleInterface
@onready var level_container: Node2D = %LevelContainer
@onready var online_join_overlay: OnlineJoinOverlay = %OnlineJoinOverlay
@onready var online_pause_overlay: OnlinePauseOverlay = %OnlinePauseOverlay
@onready var online_match_result_overlay: OnlineMatchResultOverlay = %OnlineMatchResultOverlay
@onready var online_death_overlay: OnlineDeathOverlay = %OnlineDeathOverlay


func configure_network_stack(
	enet_client: ENetClient, session_api: ClientSessionApi, gameplay_api: ClientGameplayApi
) -> void:
	_enet_client = enet_client
	_session_api = session_api
	_gameplay_api = gameplay_api
	_configure_arena_client_if_possible()


func _enter_tree() -> void:
	_configure_arena_client_if_possible()


func _ready() -> void:
	assert(_enet_client != null, "ArenaRoot missing ENetClient dependency")
	assert(_session_api != null, "ArenaRoot missing ClientSessionApi dependency")
	assert(_gameplay_api != null, "ArenaRoot missing ClientGameplayApi dependency")
	_configure_arena_client_if_possible()
	_hide_all_overlays()
	Utils.connect_checked(arena_client.join_status_changed, _on_join_status_changed)
	Utils.connect_checked(arena_client.join_completed, _on_join_completed)
	Utils.connect_checked(arena_client.session_ended, _on_session_ended)
	Utils.connect_checked(arena_client.local_player_destroyed, _on_local_player_destroyed)
	Utils.connect_checked(arena_client.local_player_respawned, _on_local_player_respawned)
	Utils.connect_checked(GameplayBus.level_started, _on_level_started)
	Utils.connect_checked(online_pause_overlay.exit_overlay_pressed, _on_overlay_exit)
	Utils.connect_checked(
		online_pause_overlay.settings_pressed, func() -> void: settings_requested.emit()
	)
	Utils.connect_checked(online_pause_overlay.abort_pressed, _on_online_abort_pressed)
	Utils.connect_checked(online_pause_overlay.logout_pressed, _on_online_logout_pressed)
	Utils.connect_checked(online_match_result_overlay.exit_overlay_pressed, _on_return_to_garage)
	Utils.connect_checked(online_match_result_overlay.return_pressed, _on_return_to_garage)
	Utils.connect_checked(online_death_overlay.respawn_pressed, _on_online_respawn_pressed)
	Utils.connect_checked(online_death_overlay.return_pressed, _on_online_death_return_pressed)
	Utils.connect_checked(MultiplayerBus.online_join_cancel_requested, _on_join_cancel_requested)
	Utils.connect_checked(MultiplayerBus.online_join_retry_requested, _on_join_retry_requested)
	Utils.connect_checked(online_join_overlay.close_requested, _on_join_overlay_close)
	Utils.connect_checked(UiBus.pause_input, _on_pause_pressed)

	online_join_overlay.visible = true
	battle_interface.set_network_client(_enet_client)
	arena_client.connect_to_server()


func _hide_all_overlays() -> void:
	online_join_overlay.visible = false
	online_pause_overlay.visible = false
	online_match_result_overlay.visible = false
	online_death_overlay.visible = false


func _on_join_status_changed(message: String, is_error: bool) -> void:
	if online_join_overlay.visible:
		online_join_overlay.set_status(message, is_error)


func _on_join_completed(success: bool, message: String) -> void:
	if online_join_overlay.visible:
		online_join_overlay.complete(success, message)
		online_join_overlay.visible = false


func _on_join_cancel_requested() -> void:
	arena_client.cancel_join_request()
	online_join_overlay.visible = false
	return_to_garage_requested.emit()


func _on_join_retry_requested() -> void:
	arena_client.connect_to_server()


func _on_join_overlay_close() -> void:
	online_join_overlay.visible = false
	if not arena_client.is_active():
		return_to_garage_requested.emit()


func _on_level_started() -> void:
	_online_session_active = true
	battle_interface.visible = true
	battle_interface.set_online_session_active(true)
	battle_interface.start_level()


func _on_session_ended(summary: Dictionary) -> void:
	_online_session_active = false
	_last_session_summary = summary
	battle_interface.finish_level()
	online_match_result_overlay.display_match_end(summary)
	_hide_all_overlays()
	online_match_result_overlay.visible = true


func _on_local_player_destroyed() -> void:
	_hide_all_overlays()
	online_death_overlay.visible = true


func _on_local_player_respawned() -> void:
	online_death_overlay.visible = false


func _on_pause_pressed() -> void:
	if online_death_overlay.visible:
		return
	if _online_session_active:
		_hide_all_overlays()
		online_pause_overlay.visible = true


func _on_overlay_exit() -> void:
	_hide_all_overlays()
	UiBus.resume_requested.emit()


func _on_online_abort_pressed() -> void:
	arena_client.end_session("MATCH ABORTED")


func _on_online_logout_pressed() -> void:
	arena_client.stop_session()
	logout_requested.emit()


func _on_online_respawn_pressed() -> void:
	arena_client.request_respawn()


func _on_online_death_return_pressed() -> void:
	arena_client.end_session("YOU WERE DESTROYED")


func _on_return_to_garage() -> void:
	arena_finished.emit(_last_session_summary)


func _configure_arena_client_if_possible() -> void:
	if _enet_client == null or _session_api == null or _gameplay_api == null:
		return
	var next_arena_client: ArenaClient = get_node_or_null("ArenaClient")
	var next_level_container: Node2D = get_node_or_null("LevelContainer")
	if next_arena_client == null or next_level_container == null:
		return
	next_arena_client.configure_dependencies(
		_enet_client, _session_api, _gameplay_api, next_level_container
	)
