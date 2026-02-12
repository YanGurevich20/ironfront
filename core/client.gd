class_name Client
extends Node2D

const OnlineArenaSyncRuntimeScript := preload("res://core/online_arena_sync_runtime.gd")
const ClientMatchResultsData := preload("res://core/client_match_results.gd")
const ClientPlayerProfileUtilsData := preload("res://core/client_player_profile_utils.gd")
const ClientRuntimeUtilsData := preload("res://core/client_runtime_utils.gd")
const ClientOnlineShellAuthorityUtilsData := preload(
	"res://core/client_online_shell_authority_utils.gd"
)

var current_level: BaseLevel
var current_level_key: int = 0
var online_arena_level: ArenaLevelMvp
var online_player_tank: Tank
var is_online_arena_active: bool = false
var online_local_player_dead: bool = false

var online_arena_scene: PackedScene = preload("res://levels/arena/arena_level_mvp.tscn")
var shell_spec_cache_by_path: Dictionary[String, ShellSpec] = {}
var active_online_shells_by_shot_id: Dictionary[int, Shell] = {}

@onready var root: SceneTree = get_tree()
@onready var ui_manager: UIManager = %UIManager
@onready var level_container: Node2D = %LevelContainer
@onready var network_client: NetworkClient = %Network
@onready var online_sync_runtime: Object = OnlineArenaSyncRuntimeScript.new()


func _ready() -> void:
	add_child(online_sync_runtime as Node)
	ui_manager.set_network_client(network_client)
	Utils.connect_checked(UiBus.quit_pressed, func() -> void: get_tree().quit())
	Utils.connect_checked(UiBus.play_online_pressed, _connect_to_online_server)
	Utils.connect_checked(UiBus.level_pressed, _start_level)
	Utils.connect_checked(UiBus.pause_input, _pause_game)
	Utils.connect_checked(UiBus.resume_requested, _resume_game)
	Utils.connect_checked(UiBus.restart_level_requested, _restart_level)
	Utils.connect_checked(UiBus.abort_level_requested, _abort_level)
	Utils.connect_checked(UiBus.online_match_abort_requested, _abort_online_match)
	Utils.connect_checked(UiBus.online_respawn_requested, _on_online_respawn_requested)
	Utils.connect_checked(UiBus.return_to_menu_requested, _quit_level)
	Utils.connect_checked(network_client.join_status_changed, ui_manager.update_online_join_overlay)
	Utils.connect_checked(network_client.join_arena_completed, _on_join_arena_completed)
	Utils.connect_checked(
		network_client.state_snapshot_received,
		func(server_tick: int, player_states: Array) -> void:
			online_sync_runtime.call("on_state_snapshot_received", server_tick, player_states)
	)
	Utils.connect_checked(network_client.arena_shell_spawn_received, _on_arena_shell_spawn_received)
	Utils.connect_checked(
		network_client.arena_shell_impact_received, _on_arena_shell_impact_received
	)
	Utils.connect_checked(network_client.arena_respawn_received, _on_arena_respawn_received)
	Utils.connect_checked(
		network_client.arena_fire_rejected_received, _on_arena_fire_rejected_received
	)
	Utils.connect_checked(
		network_client.arena_loadout_state_received, _on_arena_loadout_state_received
	)
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)
	Utils.connect_checked(GameplayBus.tank_destroyed, _on_tank_destroyed)
	Utils.connect_checked(MultiplayerBus.online_join_retry_requested, _connect_to_online_server)
	Utils.connect_checked(
		MultiplayerBus.online_join_cancel_requested,
		func() -> void: network_client.cancel_join_request()
	)
	ClientPlayerProfileUtilsData.save_player_metrics()


func _connect_to_online_server() -> void:
	ui_manager.show_online_join_overlay()
	network_client.connect_to_server()


func _on_join_arena_completed(success: bool, message: String) -> void:
	if not success:
		ui_manager.complete_online_join_overlay(false, message)
		return
	var bootstrap_success: bool = _start_online_arena()
	if not bootstrap_success:
		ui_manager.complete_online_join_overlay(false, "ARENA BOOTSTRAP FAILED")
		return
	ui_manager.hide_online_join_overlay()


func _log_prefix() -> String:
	return ClientRuntimeUtilsData.build_log_prefix(multiplayer)


#region level lifecycle
func _pause_game() -> void:
	if is_online_arena_active:
		return
	if current_level == null:
		return
	current_level.evaluate_metrics_and_objectives(false)
	# TODO: Consider moving objective getter to the base level class
	var current_objectives := current_level.objective_manager.objectives
	ui_manager.update_objectives(current_objectives)
	root.set_pause(true)


func _resume_game() -> void:
	root.set_pause(false)


func _start_level(level_key: int) -> void:
	if is_online_arena_active:
		_quit_online_arena()
	ui_manager.set_online_session_active(false)
	_resume_game()
	current_level_key = level_key
	current_level = LevelManager.LEVEL_SCENES[level_key].instantiate()
	Utils.connect_checked(current_level.level_finished, _finish_level)
	Utils.connect_checked(current_level.objectives_updated, ui_manager.update_objectives)
	level_container.add_child(current_level)
	current_level.start_level()
	GameplayBus.level_started.emit()


func _restart_level() -> void:
	if is_online_arena_active:
		push_warning("%s restart_level_ignored_online_arena_active" % _log_prefix())
		return
	_quit_level()
	_start_level(current_level_key)


func _abort_level() -> void:
	if is_online_arena_active:
		push_warning("%s abort_level_ignored_online_arena_active" % _log_prefix())
		return
	if current_level:
		current_level.finish_level(false)


func _abort_online_match() -> void:
	if not is_online_arena_active:
		return
	_quit_online_arena()
	ui_manager.finish_level()
	ui_manager.display_online_match_end("MATCH ABORTED")


func _finish_level(success: bool, metrics: Dictionary, objectives: Array) -> void:
	var reward_info: Dictionary = ClientMatchResultsData.calculate_level_reward(
		metrics, current_level_key
	)
	ui_manager.display_result(success, metrics, objectives, reward_info)
	ui_manager.finish_level()
	ClientPlayerProfileUtilsData.save_player_metrics(metrics)
	ClientPlayerProfileUtilsData.save_game_progress(
		metrics, current_level_key, int(reward_info.get("total_reward", 0))
	)


func _quit_level() -> void:
	if is_online_arena_active:
		_quit_online_arena()
		return
	if current_level:
		current_level.level_finished.disconnect(_finish_level)
		current_level.objectives_updated.disconnect(ui_manager.update_objectives)
		level_container.remove_child(current_level)
		current_level.queue_free()
		current_level = null


func _start_online_arena() -> bool:
	if online_arena_scene == null:
		push_error("%s online_arena_scene is null" % _log_prefix())
		return false
	if current_level != null:
		_quit_level()
	if online_arena_level != null:
		_quit_online_arena()
	var arena_level_node: Node = online_arena_scene.instantiate()
	var arena_level_candidate: ArenaLevelMvp = arena_level_node as ArenaLevelMvp
	if arena_level_candidate == null:
		push_error("%s arena scene root must use ArenaLevelMvp script" % _log_prefix())
		arena_level_node.queue_free()
		return false
	level_container.add_child(arena_level_candidate)
	online_arena_level = arena_level_candidate
	var player_tank: Tank = ClientPlayerProfileUtilsData.create_local_player_tank()
	if player_tank == null:
		_quit_online_arena()
		return false
	online_arena_level.add_child(player_tank)
	player_tank.apply_spawn_state(
		network_client.assigned_spawn_position, network_client.assigned_spawn_rotation
	)
	online_player_tank = player_tank
	online_local_player_dead = false
	is_online_arena_active = true
	ui_manager.set_online_session_active(true)
	ui_manager.hide_online_death_overlay()
	active_online_shells_by_shot_id.clear()
	online_sync_runtime.call("start_runtime", online_arena_level, online_player_tank)
	network_client.set_arena_input_enabled(true)
	_resume_game()
	GameplayBus.level_started.emit()
	print(
		(
			"%s online_arena_started spawn_position=%s spawn_rotation=%.4f"
			% [
				_log_prefix(),
				network_client.assigned_spawn_position,
				network_client.assigned_spawn_rotation
			]
		)
	)
	return true


func _quit_online_arena() -> void:
	network_client.leave_arena()
	active_online_shells_by_shot_id.clear()
	online_local_player_dead = false
	ui_manager.hide_online_death_overlay()
	ui_manager.set_online_session_active(false)
	online_sync_runtime.call("stop_runtime")
	if online_player_tank != null:
		online_player_tank.queue_free()
		online_player_tank = null
	if online_arena_level != null:
		level_container.remove_child(online_arena_level)
		online_arena_level.queue_free()
		online_arena_level = null
	is_online_arena_active = false
	network_client.set_arena_input_enabled(false)


func _on_tank_destroyed(tank: Tank) -> void:
	if not is_online_arena_active:
		return
	if tank != online_player_tank:
		return
	online_local_player_dead = true
	network_client.set_arena_input_enabled(false, false)
	ui_manager.show_online_death_overlay()


func _on_online_respawn_requested() -> void:
	if not is_online_arena_active:
		return
	if not online_local_player_dead:
		return
	network_client.request_arena_respawn()


func _on_arena_respawn_received(
	peer_id: int, spawn_position: Vector2, spawn_rotation: float
) -> void:
	if not is_online_arena_active:
		return
	if peer_id == multiplayer.get_unique_id():
		_respawn_local_online_player_tank(spawn_position, spawn_rotation)
		return
	online_sync_runtime.call("respawn_remote_tank", peer_id, spawn_position, spawn_rotation)


func _on_arena_fire_rejected_received(reason: String) -> void:
	if not is_online_arena_active:
		return
	push_warning("%s authoritative_fire_rejected reason=%s" % [_log_prefix(), reason])
	GameplayBus.online_fire_rejected.emit(reason)


func _on_arena_loadout_state_received(
	selected_shell_path: String, shell_counts_by_path: Dictionary, reload_time_left: float
) -> void:
	if not is_online_arena_active:
		return
	if online_player_tank == null:
		return
	if selected_shell_path.is_empty():
		online_player_tank.set_remaining_shell_count(0)
		GameplayBus.online_loadout_state_updated.emit(
			selected_shell_path, shell_counts_by_path, reload_time_left
		)
		return
	var selected_shell_spec: ShellSpec = _get_cached_shell_spec(selected_shell_path)
	if selected_shell_spec == null:
		push_warning(
			(
				"%s authoritative_loadout_state_invalid_selected_shell path=%s"
				% [_log_prefix(), selected_shell_path]
			)
		)
		GameplayBus.online_loadout_state_updated.emit(
			selected_shell_path, shell_counts_by_path, reload_time_left
		)
		return
	var selected_shell_count: int = max(0, int(shell_counts_by_path.get(selected_shell_path, 0)))
	online_player_tank.apply_authoritative_shell_state(
		selected_shell_spec, selected_shell_count, reload_time_left
	)
	GameplayBus.online_loadout_state_updated.emit(
		selected_shell_path, shell_counts_by_path, reload_time_left
	)


func _respawn_local_online_player_tank(spawn_position: Vector2, spawn_rotation: float) -> void:
	if online_arena_level == null:
		return
	if online_player_tank != null:
		online_player_tank.queue_free()
	var respawned_tank: Tank = ClientPlayerProfileUtilsData.create_local_player_tank()
	if respawned_tank == null:
		push_error("%s online_respawn_failed player_tank_creation" % _log_prefix())
		return
	online_arena_level.add_child(respawned_tank)
	respawned_tank.apply_spawn_state(spawn_position, spawn_rotation)
	online_player_tank = respawned_tank
	online_local_player_dead = false
	ui_manager.hide_online_death_overlay()
	online_sync_runtime.call("replace_local_player_tank", online_player_tank)
	network_client.set_arena_input_enabled(true, false)


func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	if not is_online_arena_active or online_arena_level == null or tank != online_player_tank:
		return
	shell.queue_free()


func _on_arena_shell_spawn_received(
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	ClientOnlineShellAuthorityUtilsData.handle_shell_spawn_received(
		self,
		shot_id,
		firing_peer_id,
		shell_spec_path,
		spawn_position,
		shell_velocity,
		shell_rotation
	)


func _on_arena_shell_impact_received(
	shot_id: int,
	firing_peer_id: int,
	target_peer_id: int,
	result_type: int,
	damage: int,
	remaining_health: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
) -> void:
	ClientOnlineShellAuthorityUtilsData.handle_shell_impact_received(
		self,
		shot_id,
		firing_peer_id,
		target_peer_id,
		result_type,
		damage,
		remaining_health,
		hit_position,
		post_impact_velocity,
		post_impact_rotation,
		continue_simulation
	)


func _get_cached_shell_spec(shell_spec_path: String) -> ShellSpec:
	if shell_spec_cache_by_path.has(shell_spec_path):
		return shell_spec_cache_by_path[shell_spec_path]
	var loaded_shell_spec_resource: Resource = load(shell_spec_path)
	var loaded_shell_spec: ShellSpec = loaded_shell_spec_resource as ShellSpec
	if loaded_shell_spec == null:
		return null
	shell_spec_cache_by_path[shell_spec_path] = loaded_shell_spec
	return loaded_shell_spec
