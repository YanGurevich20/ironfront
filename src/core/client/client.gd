class_name Client
extends Node2D

const KILL_REWARD_DOLLARS: int = 5000

var current_level: BaseLevel
var current_level_key: int = 0
var arena_level: ArenaLevelMvp
var player_tank: Tank
var is_arena_active: bool = false
var local_player_dead: bool = false
var reward_tracker: RewardTracker = RewardTracker.new(KILL_REWARD_DOLLARS)

var arena_scene: PackedScene = preload("res://src/levels/arena/arena_level_mvp.tscn")
var active_shells_by_shot_id: Dictionary[int, Shell] = {}

@onready var root: SceneTree = get_tree()
@onready var ui_manager: UIManager = %UIManager
@onready var level_container: Node2D = %LevelContainer
@onready var enet_client: ENetClient = %Network
@onready var online_runtime: ClientOnlineRuntime = %OnlineRuntime
@onready var arena_sync_runtime: ArenaSyncRuntime = ArenaSyncRuntime.new()


func _ready() -> void:
	add_child(arena_sync_runtime)
	ui_manager.set_network_client(enet_client)
	Utils.connect_checked(UiBus.quit_pressed, func() -> void: get_tree().quit())
	Utils.connect_checked(UiBus.play_online_pressed, _connect_to_server)
	Utils.connect_checked(UiBus.level_pressed, _start_level)
	Utils.connect_checked(UiBus.pause_input, _pause_game)
	Utils.connect_checked(UiBus.resume_requested, _resume_game)
	Utils.connect_checked(UiBus.restart_level_requested, _restart_level)
	Utils.connect_checked(UiBus.abort_level_requested, _abort_level)
	Utils.connect_checked(UiBus.online_session_end_requested, _end_session)
	Utils.connect_checked(UiBus.online_respawn_requested, _on_respawn_requested)
	Utils.connect_checked(UiBus.return_to_menu_requested, _quit_level)
	Utils.connect_checked(online_runtime.join_status_changed, ui_manager.update_online_join_overlay)
	Utils.connect_checked(online_runtime.join_arena_completed, _on_join_arena_completed)
	Utils.connect_checked(online_runtime.state_snapshot_received, _on_state_snapshot_received)
	Utils.connect_checked(online_runtime.arena_shell_spawn_received, _on_arena_shell_spawn_received)
	Utils.connect_checked(
		online_runtime.arena_shell_impact_received, _on_arena_shell_impact_received
	)
	Utils.connect_checked(online_runtime.arena_respawn_received, _on_arena_respawn_received)
	Utils.connect_checked(
		online_runtime.arena_fire_rejected_received, _on_arena_fire_rejected_received
	)
	Utils.connect_checked(
		online_runtime.arena_loadout_state_received, _on_arena_loadout_state_received
	)
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)
	Utils.connect_checked(GameplayBus.tank_destroyed, _on_tank_destroyed)
	Utils.connect_checked(GameplayBus.online_kill_feed_event, _on_kill_feed_event)
	Utils.connect_checked(MultiplayerBus.online_join_retry_requested, _connect_to_server)
	Utils.connect_checked(
		MultiplayerBus.online_join_cancel_requested, online_runtime.cancel_join_request
	)
	PlayerProfileUtils.save_player_metrics()


func _connect_to_server() -> void:
	ui_manager.show_online_join_overlay()
	online_runtime.connect_to_server()


func _on_join_arena_completed(success: bool, message: String) -> void:
	if not success:
		if is_arena_active:
			_end_session(message)
			return
		ui_manager.complete_online_join_overlay(false, message)
		return
	var bootstrap_success: bool = _start_arena()
	if not bootstrap_success:
		ui_manager.complete_online_join_overlay(false, "ARENA BOOTSTRAP FAILED")
		return
	ui_manager.hide_online_join_overlay()


func _log_prefix() -> String:
	return RuntimeUtils.build_log_prefix(multiplayer)


#region level lifecycle
func _pause_game() -> void:
	if is_arena_active:
		return
	if current_level == null:
		return
	current_level.evaluate_metrics_and_objectives(false)
	var current_objectives := current_level.objective_manager.objectives
	ui_manager.update_objectives(current_objectives)
	root.set_pause(true)


func _resume_game() -> void:
	root.set_pause(false)


func _start_level(level_key: int) -> void:
	if is_arena_active:
		_quit_arena()
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
	if is_arena_active:
		push_warning("%s restart_level_ignored_online_arena_active" % _log_prefix())
		return
	_quit_level()
	_start_level(current_level_key)


func _abort_level() -> void:
	if is_arena_active:
		push_warning("%s abort_level_ignored_online_arena_active" % _log_prefix())
		return
	if current_level:
		current_level.finish_level(false)


func _finish_level(success: bool, metrics: Dictionary, objectives: Array) -> void:
	var reward_info: Dictionary = MatchResults.calculate_level_reward(metrics, current_level_key)
	ui_manager.display_result(success, metrics, objectives, reward_info)
	ui_manager.finish_level()
	PlayerProfileUtils.save_player_metrics(metrics)
	PlayerProfileUtils.save_game_progress(
		metrics, current_level_key, int(reward_info.get("total_reward", 0))
	)


func _quit_level() -> void:
	if is_arena_active:
		_quit_arena()
		return
	if current_level:
		current_level.level_finished.disconnect(_finish_level)
		current_level.objectives_updated.disconnect(ui_manager.update_objectives)
		level_container.remove_child(current_level)
		current_level.queue_free()
		current_level = null


func _start_arena() -> bool:
	if arena_scene == null:
		push_error("%s arena_scene is null" % _log_prefix())
		return false
	if current_level != null:
		_quit_level()
	if arena_level != null:
		_quit_arena()
	var arena_level_node: Node = arena_scene.instantiate()
	var arena_level_candidate: ArenaLevelMvp = arena_level_node as ArenaLevelMvp
	if arena_level_candidate == null:
		push_error("%s arena scene root must use ArenaLevelMvp script" % _log_prefix())
		arena_level_node.queue_free()
		return false
	level_container.add_child(arena_level_candidate)
	arena_level = arena_level_candidate
	var spawned_player_tank: Tank = PlayerProfileUtils.create_local_player_tank(
		TankManager.TankControllerType.MULTIPLAYER
	)
	if spawned_player_tank == null:
		_quit_arena()
		return false
	arena_level.add_child(spawned_player_tank)
	spawned_player_tank.apply_spawn_state(
		online_runtime.assigned_spawn_position, online_runtime.assigned_spawn_rotation
	)
	player_tank = spawned_player_tank
	local_player_dead = false
	reward_tracker.reset()
	is_arena_active = true
	ui_manager.set_online_session_active(true)
	ui_manager.hide_online_death_overlay()
	active_shells_by_shot_id.clear()
	arena_sync_runtime.start_runtime(arena_level, player_tank)
	online_runtime.set_arena_input_enabled(true)
	_resume_game()
	GameplayBus.level_started.emit()
	print(
		(
			"%s arena_started spawn_position=%s spawn_rotation=%.4f"
			% [
				_log_prefix(),
				online_runtime.assigned_spawn_position,
				online_runtime.assigned_spawn_rotation
			]
		)
	)
	return true


func _quit_arena() -> void:
	online_runtime.leave_arena()
	active_shells_by_shot_id.clear()
	local_player_dead = false
	ui_manager.hide_online_death_overlay()
	ui_manager.set_online_session_active(false)
	arena_sync_runtime.stop_runtime()
	if player_tank != null:
		player_tank.queue_free()
		player_tank = null
	if arena_level != null:
		level_container.remove_child(arena_level)
		arena_level.queue_free()
		arena_level = null
	is_arena_active = false
	online_runtime.set_arena_input_enabled(false)


func _on_tank_destroyed(tank: Tank) -> void:
	if not is_arena_active:
		return
	if tank != player_tank:
		return
	local_player_dead = true
	online_runtime.set_arena_input_enabled(false, false)
	ui_manager.show_online_death_overlay()


func _on_kill_feed_event(
	event_seq: int,
	killer_peer_id: int,
	killer_name: String,
	killer_tank_name: String,
	shell_short_name: String,
	victim_peer_id: int,
	victim_name: String,
	victim_tank_name: String
) -> void:
	if not is_arena_active:
		return
	if multiplayer.multiplayer_peer == null:
		return
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


func _on_respawn_requested() -> void:
	if not is_arena_active:
		return
	if not local_player_dead:
		return
	online_runtime.request_arena_respawn()


func _on_arena_respawn_received(
	peer_id: int, player_name: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	if not is_arena_active:
		return
	if peer_id == multiplayer.get_unique_id():
		_respawn_local_player_tank(spawn_position, spawn_rotation)
		return
	arena_sync_runtime.respawn_remote_tank(peer_id, player_name, spawn_position, spawn_rotation)


func _on_arena_fire_rejected_received(reason: String) -> void:
	if not is_arena_active:
		return
	push_warning("%s authoritative_fire_rejected reason=%s" % [_log_prefix(), reason])
	GameplayBus.online_fire_rejected.emit(reason)


func _end_session(status_message: String) -> void:
	if not is_arena_active:
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var summary: Dictionary = reward_tracker.build_summary(status_message)
	reward_tracker.apply_rewards(player_data)
	GameplayBus.level_finished_and_saved.emit()
	_quit_arena()
	ui_manager.finish_level()
	ui_manager.display_online_match_end(summary)
	reward_tracker.reset()


func _on_state_snapshot_received(server_tick: int, player_states: Array, max_players: int) -> void:
	arena_sync_runtime.on_state_snapshot_received(server_tick, player_states)
	if not is_arena_active:
		return
	var active_human_players: int = 0
	var active_bots: int = 0
	for player_state_variant: Variant in player_states:
		var player_state: Dictionary = player_state_variant
		if bool(player_state.get("is_bot", false)):
			active_bots += int(bool(player_state.get("is_alive", true)))
			continue
		active_human_players += 1
	GameplayBus.online_player_count_updated.emit(active_human_players, max_players, active_bots)


func _on_arena_loadout_state_received(
	selected_shell_id: String, shell_counts_by_id: Dictionary, reload_time_left: float
) -> void:
	ShellAuthorityUtils.handle_loadout_state_received(
		self, selected_shell_id, shell_counts_by_id, reload_time_left
	)


func _respawn_local_player_tank(spawn_position: Vector2, spawn_rotation: float) -> void:
	if arena_level == null:
		return
	if player_tank != null:
		player_tank.queue_free()
	var respawned_tank: Tank = PlayerProfileUtils.create_local_player_tank(
		TankManager.TankControllerType.MULTIPLAYER
	)
	if respawned_tank == null:
		push_error("%s arena_respawn_failed player_tank_creation" % _log_prefix())
		return
	arena_level.add_child(respawned_tank)
	respawned_tank.apply_spawn_state(spawn_position, spawn_rotation)
	player_tank = respawned_tank
	local_player_dead = false
	ui_manager.hide_online_death_overlay()
	arena_sync_runtime.replace_local_player_tank(player_tank)
	online_runtime.set_arena_input_enabled(true, false)


func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	if not is_arena_active or arena_level == null or tank != player_tank:
		return
	shell.queue_free()


func _on_arena_shell_spawn_received(
	shot_id: int,
	firing_peer_id: int,
	shell_id: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	ShellAuthorityUtils.handle_shell_spawn_received(
		self, shot_id, firing_peer_id, shell_id, spawn_position, shell_velocity, shell_rotation
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
	ShellAuthorityUtils.handle_shell_impact_received(
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
