class_name ClientApp
extends Node2D

@onready var ui_manager: UIManager = %UIManager
@onready var enet_client: ENetClient = %Network
@onready var offline_runtime: OfflineRuntime = %OfflineRuntime
@onready var arena_client: ArenaClient = %ArenaClient
@onready var auth_manager: AuthManager = %AuthManager


func _ready() -> void:
	ui_manager.set_network_client(enet_client)
	Utils.connect_checked(UiBus.quit_pressed, func() -> void: get_tree().quit())
	Utils.connect_checked(UiBus.auth_retry_requested, auth_manager.retry_sign_in)
	Utils.connect_checked(UiBus.log_out_pressed, auth_manager.sign_out)
	Utils.connect_checked(UiBus.play_online_pressed, _start_online_join)
	Utils.connect_checked(UiBus.level_pressed, _start_offline_level)
	Utils.connect_checked(UiBus.pause_input, _pause_game)
	Utils.connect_checked(UiBus.resume_requested, _resume_game)
	Utils.connect_checked(UiBus.restart_level_requested, _restart_level)
	Utils.connect_checked(UiBus.abort_level_requested, _abort_level)
	Utils.connect_checked(UiBus.online_session_end_requested, arena_client.end_session)
	Utils.connect_checked(UiBus.online_respawn_requested, arena_client.request_respawn)
	Utils.connect_checked(UiBus.return_to_menu_requested, _return_to_menu)
	Utils.connect_checked(MultiplayerBus.online_join_retry_requested, _start_online_join)
	Utils.connect_checked(
		MultiplayerBus.online_join_cancel_requested, arena_client.cancel_join_request
	)
	Utils.connect_checked(offline_runtime.objectives_updated, ui_manager.update_objectives)
	Utils.connect_checked(offline_runtime.level_completed, _on_offline_level_completed)
	Utils.connect_checked(arena_client.join_status_changed, ui_manager.update_online_join_overlay)
	Utils.connect_checked(arena_client.join_completed, _on_online_join_completed)
	Utils.connect_checked(arena_client.session_ended, _on_arena_session_ended)
	Utils.connect_checked(arena_client.local_player_destroyed, ui_manager.show_online_death_overlay)
	Utils.connect_checked(arena_client.local_player_respawned, ui_manager.hide_online_death_overlay)
	Utils.connect_checked(auth_manager.sign_in_succeeded, _on_auth_sign_in_succeeded)
	Utils.connect_checked(auth_manager.sign_in_failed, _on_auth_sign_in_failed)
	PlayerProfileUtils.save_player_metrics()


func _start_online_join() -> void:
	if offline_runtime.is_active():
		offline_runtime.quit_level()
	ui_manager.show_online_join_overlay()
	arena_client.connect_to_server()


func _start_offline_level(level_key: int) -> void:
	if arena_client.is_active():
		arena_client.stop_session()
	ui_manager.set_online_session_active(false)
	ui_manager.hide_online_death_overlay()
	offline_runtime.start_level(level_key)


func _pause_game() -> void:
	offline_runtime.pause_level()


func _resume_game() -> void:
	offline_runtime.resume_level()


func _restart_level() -> void:
	offline_runtime.restart_level()


func _abort_level() -> void:
	offline_runtime.abort_level()


func _return_to_menu() -> void:
	arena_client.stop_session()
	ui_manager.set_online_session_active(false)
	ui_manager.hide_online_death_overlay()
	offline_runtime.quit_level()


func _on_offline_level_completed(
	success: bool, metrics: Dictionary, objectives: Array, reward_info: Dictionary
) -> void:
	ui_manager.display_result(success, metrics, objectives, reward_info)
	ui_manager.finish_level()


func _on_online_join_completed(success: bool, message: String) -> void:
	if success:
		ui_manager.set_online_session_active(true)
		ui_manager.hide_online_death_overlay()
		ui_manager.hide_online_join_overlay()
		return
	ui_manager.complete_online_join_overlay(false, message)


func _on_arena_session_ended(summary: Dictionary) -> void:
	ui_manager.set_online_session_active(false)
	ui_manager.hide_online_death_overlay()
	ui_manager.finish_level()
	ui_manager.display_online_match_end(summary)


func _on_auth_sign_in_succeeded(result: AuthResult) -> void:
	var player_data: PlayerData = PlayerData.get_instance()
	var resolved_display_name: String = result.display_name.strip_edges()
	if not resolved_display_name.is_empty():
		player_data.player_name = resolved_display_name
		player_data.save()
	UiBus.auth_sign_in_finished.emit(true)
	UiBus.login_pressed.emit()


func _on_auth_sign_in_failed(reason: String) -> void:
	print("[client-app] auth sign-in failed reason=%s" % reason)
	UiBus.auth_sign_in_finished.emit(false)
