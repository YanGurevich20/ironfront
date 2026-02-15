class_name ArenaSessionRuntime
extends Node

signal join_completed(success: bool, message: String)
signal session_ended(summary: Dictionary)
signal local_player_destroyed
signal local_player_respawned

const KILL_REWARD_DOLLARS: int = 5000

var arena_level: ArenaLevelMvp
var player_tank: Tank
var is_arena_active: bool = false
var local_player_dead: bool = false
var reward_tracker: RewardTracker = RewardTracker.new(KILL_REWARD_DOLLARS)
var arena_scene: PackedScene = preload("res://src/levels/arena/arena_level_mvp.tscn")

@onready var level_container: Node2D = %LevelContainer
@onready var online_runtime: ClientOnlineRuntime = %OnlineRuntime
@onready var replication: ArenaReplication = %Replication
@onready var shell_controller: ArenaClientShellController = %ShellController


func _ready() -> void:
	shell_controller.configure(replication, online_runtime)
	Utils.connect_checked(online_runtime.join_arena_completed, _on_join_arena_completed)
	Utils.connect_checked(online_runtime.state_snapshot_received, _on_state_snapshot_received)
	Utils.connect_checked(online_runtime.arena_respawn_received, _on_arena_respawn_received)
	Utils.connect_checked(
		online_runtime.arena_fire_rejected_received, _on_arena_fire_rejected_received
	)
	Utils.connect_checked(GameplayBus.tank_destroyed, _on_tank_destroyed)
	Utils.connect_checked(GameplayBus.online_kill_feed_event, _on_kill_feed_event)
	Utils.connect_checked(GameplayBus.lever_input, _on_lever_input)
	Utils.connect_checked(GameplayBus.wheel_input, _on_wheel_input)


func is_active() -> bool:
	return is_arena_active


func connect_to_server() -> void:
	online_runtime.connect_to_server()


func cancel_join_request() -> void:
	online_runtime.cancel_join_request()


func request_respawn() -> void:
	if not is_arena_active or not local_player_dead:
		return
	online_runtime.request_arena_respawn()


func stop_session() -> void:
	if not is_arena_active:
		return
	_quit_arena()


func end_session(status_message: String) -> void:
	if not is_arena_active:
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var summary: Dictionary = reward_tracker.build_summary(status_message)
	reward_tracker.apply_rewards(player_data)
	GameplayBus.level_finished_and_saved.emit()
	_quit_arena()
	reward_tracker.reset()
	session_ended.emit(summary)


func _log_prefix() -> String:
	var peer_id: int = 0
	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.get_unique_id()
	return "[client pid=%d peer=%d]" % [OS.get_process_id(), peer_id]


func _on_join_arena_completed(success: bool, message: String) -> void:
	if not success:
		if is_arena_active:
			end_session(message)
			return
		join_completed.emit(false, message)
		return
	var started: bool = _start_arena()
	if not started:
		join_completed.emit(false, "ARENA BOOTSTRAP FAILED")
		return
	join_completed.emit(true, message)


func _start_arena() -> bool:
	if arena_scene == null:
		push_error("%s arena_scene is null" % _log_prefix())
		return false
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
	replication.start_runtime(arena_level, player_tank)
	shell_controller.start_runtime(arena_level, player_tank)
	online_runtime.set_arena_input_enabled(true)
	get_tree().set_pause(false)
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
	GameplayBus.level_started.emit()
	return true


func _quit_arena() -> void:
	online_runtime.leave_arena()
	local_player_dead = false
	shell_controller.stop_runtime()
	replication.stop_runtime()
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
	local_player_destroyed.emit()


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


func _on_arena_respawn_received(
	peer_id: int, player_name: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	if not is_arena_active:
		return
	if peer_id == multiplayer.get_unique_id():
		_respawn_local_player_tank(spawn_position, spawn_rotation)
		return
	replication.respawn_remote_tank(peer_id, player_name, spawn_position, spawn_rotation)


func _on_arena_fire_rejected_received(reason: String) -> void:
	if not is_arena_active:
		return
	push_warning("%s authoritative_fire_rejected reason=%s" % [_log_prefix(), reason])
	GameplayBus.online_fire_rejected.emit(reason)


func _on_lever_input(lever_side: Lever.LeverSide, value: float) -> void:
	if not is_arena_active or local_player_dead or player_tank == null:
		return
	if lever_side == Lever.LeverSide.LEFT:
		player_tank.left_track_input = value
	elif lever_side == Lever.LeverSide.RIGHT:
		player_tank.right_track_input = value


func _on_wheel_input(value: float) -> void:
	if not is_arena_active or local_player_dead or player_tank == null:
		return
	player_tank.turret_rotation_input = value


func _on_state_snapshot_received(server_tick: int, player_states: Array, max_players: int) -> void:
	replication.on_state_snapshot_received(server_tick, player_states)
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
	replication.replace_local_player_tank(player_tank)
	shell_controller.replace_local_player_tank(player_tank)
	online_runtime.set_arena_input_enabled(true, false)
	local_player_respawned.emit()
