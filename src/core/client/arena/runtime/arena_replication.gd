class_name ArenaReplication
extends Node

var arena_level: ArenaLevelMvp
var local_player_tank: Tank
var log_context: Dictionary = {}

var latest_snapshot_server_tick: int = 0
var snapshot_render_delay_ticks: int = 2
var latest_snapshot_received_local_time_seconds: float = 0.0
var last_snapshot_received_server_tick: int = -1
var last_snapshot_received_local_time_seconds: float = -1.0
var estimated_server_ticks_per_second: float = 60.0
var remote_tanks_by_peer_id: Dictionary = {}
var remote_snapshot_history_by_peer_id: Dictionary = {}
var max_snapshot_history_per_peer: int = 24
var reconciliation_hard_snap_distance: float = 48.0
var reconciliation_min_error_distance: float = 6.0
var reconciliation_max_position_correction_speed: float = 96.0
var reconciliation_rotation_blend_per_second: float = 8.0
var reconciliation_velocity_blend_per_second: float = 5.0
var has_pending_local_authoritative_state: bool = false
var pending_local_authoritative_server_tick: int = 0
var pending_local_authoritative_position: Vector2 = Vector2.ZERO
var pending_local_authoritative_rotation: float = 0.0
var pending_local_authoritative_linear_velocity: Vector2 = Vector2.ZERO
var pending_local_last_processed_input_tick: int = 0


func configure_log_context(next_log_context: Dictionary) -> void:
	log_context = next_log_context.duplicate(true)


func start_match(next_arena_level: ArenaLevelMvp, next_local_player_tank: Tank) -> void:
	stop_match()
	arena_level = next_arena_level
	local_player_tank = next_local_player_tank
	latest_snapshot_server_tick = 0
	latest_snapshot_received_local_time_seconds = 0.0
	last_snapshot_received_server_tick = -1
	last_snapshot_received_local_time_seconds = -1.0
	estimated_server_ticks_per_second = 60.0
	remote_tanks_by_peer_id.clear()
	remote_snapshot_history_by_peer_id.clear()
	has_pending_local_authoritative_state = false
	pending_local_authoritative_server_tick = 0
	pending_local_authoritative_position = Vector2.ZERO
	pending_local_authoritative_rotation = 0.0
	pending_local_authoritative_linear_velocity = Vector2.ZERO
	pending_local_last_processed_input_tick = 0
	set_process(true)
	set_physics_process(true)
	print(
		(
			"%s[sync] match_started local_tank=%s"
			% [_log_prefix(), str(local_player_tank.get_instance_id())]
		)
	)


func stop_match() -> void:
	for shell_variant: Variant in remote_tanks_by_peer_id.values():
		var remote_tank: Tank = shell_variant
		if remote_tank != null:
			remote_tank.queue_free()
	remote_tanks_by_peer_id.clear()
	remote_snapshot_history_by_peer_id.clear()
	latest_snapshot_server_tick = 0
	latest_snapshot_received_local_time_seconds = 0.0
	last_snapshot_received_server_tick = -1
	last_snapshot_received_local_time_seconds = -1.0
	estimated_server_ticks_per_second = 60.0
	has_pending_local_authoritative_state = false
	pending_local_authoritative_server_tick = 0
	pending_local_authoritative_position = Vector2.ZERO
	pending_local_authoritative_rotation = 0.0
	pending_local_authoritative_linear_velocity = Vector2.ZERO
	pending_local_last_processed_input_tick = 0
	arena_level = null
	local_player_tank = null
	set_process(false)
	set_physics_process(false)
	print("%s[sync] match_stopped" % _log_prefix())


func on_state_snapshot_received(server_tick: int, player_states: Array) -> void:
	var now_seconds: float = _get_now_seconds()
	if (
		last_snapshot_received_server_tick >= 0
		and server_tick > last_snapshot_received_server_tick
		and last_snapshot_received_local_time_seconds >= 0.0
	):
		var delta_ticks: int = server_tick - last_snapshot_received_server_tick
		var delta_seconds: float = max(
			0.0001, now_seconds - last_snapshot_received_local_time_seconds
		)
		var measured_tick_rate_hz: float = float(delta_ticks) / delta_seconds
		var clamped_tick_rate_hz: float = clamp(measured_tick_rate_hz, 20.0, 240.0)
		estimated_server_ticks_per_second = lerpf(
			estimated_server_ticks_per_second, clamped_tick_rate_hz, 0.2
		)
	last_snapshot_received_server_tick = server_tick
	last_snapshot_received_local_time_seconds = now_seconds
	latest_snapshot_received_local_time_seconds = now_seconds
	latest_snapshot_server_tick = max(latest_snapshot_server_tick, server_tick)
	var seen_peer_ids: Dictionary = {}
	for player_state_variant: Variant in player_states:
		var player_state: Dictionary = player_state_variant
		var peer_id: int = int(player_state.get("peer_id", 0))
		if peer_id == 0:
			continue
		seen_peer_ids[peer_id] = true
		var authoritative_position: Vector2 = player_state.get("position", Vector2.ZERO)
		var authoritative_rotation: float = float(player_state.get("rotation", 0.0))
		var authoritative_linear_velocity: Vector2 = player_state.get(
			"linear_velocity", Vector2.ZERO
		)
		var authoritative_turret_rotation: float = float(player_state.get("turret_rotation", 0.0))
		var last_processed_input_tick: int = int(player_state.get("last_processed_input_tick", 0))
		if peer_id == multiplayer.get_unique_id():
			_queue_local_reconciliation(
				server_tick,
				authoritative_position,
				authoritative_rotation,
				authoritative_linear_velocity,
				last_processed_input_tick
			)
			continue
		_record_remote_snapshot(
			peer_id,
			server_tick,
			authoritative_position,
			authoritative_rotation,
			authoritative_linear_velocity,
			authoritative_turret_rotation
		)
		_ensure_remote_tank(peer_id, player_state)
	_remove_stale_remote_tanks(seen_peer_ids)


func play_remote_fire_effect(peer_id: int) -> void:
	var remote_tank: Tank = remote_tanks_by_peer_id.get(peer_id)
	if remote_tank == null:
		return
	remote_tank.play_fire_effect()


func replace_local_player_tank(next_local_player_tank: Tank) -> void:
	local_player_tank = next_local_player_tank


func respawn_remote_tank(
	peer_id: int,
	player_name: String,
	spawn_position: Vector2,
	spawn_rotation: float,
	spawn_turret_rotation: float = 0.0
) -> void:
	var remote_tank: Tank = remote_tanks_by_peer_id.get(peer_id)
	if remote_tank != null:
		remote_tank.queue_free()
	remote_tanks_by_peer_id.erase(peer_id)
	remote_snapshot_history_by_peer_id.erase(peer_id)
	_spawn_remote_tank(peer_id, player_name, spawn_position, spawn_rotation, spawn_turret_rotation)


func get_tank_by_peer_id(peer_id: int) -> Tank:
	if peer_id == multiplayer.get_unique_id():
		return local_player_tank
	return remote_tanks_by_peer_id.get(peer_id)


func _process(_delta: float) -> void:
	_update_remote_tank_interpolation()


func _physics_process(delta: float) -> void:
	_apply_local_reconciliation(delta)


func _queue_local_reconciliation(
	server_tick: int,
	authoritative_position: Vector2,
	authoritative_rotation: float,
	authoritative_linear_velocity: Vector2,
	last_processed_input_tick: int
) -> void:
	has_pending_local_authoritative_state = true
	pending_local_authoritative_server_tick = server_tick
	pending_local_authoritative_position = authoritative_position
	pending_local_authoritative_rotation = authoritative_rotation
	pending_local_authoritative_linear_velocity = authoritative_linear_velocity
	pending_local_last_processed_input_tick = last_processed_input_tick


func _apply_local_reconciliation(delta: float) -> void:
	if local_player_tank == null:
		return
	if not has_pending_local_authoritative_state or delta <= 0.0:
		return
	var position_error: float = local_player_tank.global_position.distance_to(
		pending_local_authoritative_position
	)
	if position_error > reconciliation_hard_snap_distance:
		local_player_tank.global_position = pending_local_authoritative_position
		local_player_tank.global_rotation = pending_local_authoritative_rotation
		local_player_tank.linear_velocity = pending_local_authoritative_linear_velocity
		has_pending_local_authoritative_state = false
		push_warning(
			(
				"%s[sync][local] hard_snap tick=%d error=%.2f last_input=%d"
				% [
					_log_prefix(),
					pending_local_authoritative_server_tick,
					position_error,
					pending_local_last_processed_input_tick
				]
			)
		)
		return
	if position_error > reconciliation_min_error_distance:
		var correction_direction: Vector2 = (
			(pending_local_authoritative_position - local_player_tank.global_position).normalized()
		)
		var correction_distance: float = min(
			position_error - reconciliation_min_error_distance,
			reconciliation_max_position_correction_speed * delta
		)
		local_player_tank.global_position += correction_direction * correction_distance
	var rotation_blend: float = min(1.0, reconciliation_rotation_blend_per_second * delta)
	local_player_tank.global_rotation = lerp_angle(
		local_player_tank.global_rotation, pending_local_authoritative_rotation, rotation_blend
	)
	var velocity_blend: float = min(1.0, reconciliation_velocity_blend_per_second * delta)
	local_player_tank.linear_velocity = local_player_tank.linear_velocity.lerp(
		pending_local_authoritative_linear_velocity, velocity_blend
	)


func _record_remote_snapshot(
	peer_id: int,
	server_tick: int,
	state_position: Vector2,
	state_rotation: float,
	state_linear_velocity: Vector2,
	state_turret_rotation: float
) -> void:
	var history: Array = remote_snapshot_history_by_peer_id.get(peer_id, [])
	(
		history
		. append(
			{
				"server_tick": server_tick,
				"position": state_position,
				"rotation": state_rotation,
				"linear_velocity": state_linear_velocity,
				"turret_rotation": state_turret_rotation,
			}
		)
	)
	while history.size() > max_snapshot_history_per_peer:
		history.remove_at(0)
	remote_snapshot_history_by_peer_id[peer_id] = history


func _ensure_remote_tank(peer_id: int, player_state: Dictionary) -> void:
	if remote_tanks_by_peer_id.has(peer_id):
		return
	var player_name: String = str(player_state.get("player_name", ""))
	var spawn_position: Vector2 = player_state.get("position", Vector2.ZERO)
	var spawn_rotation: float = float(player_state.get("rotation", 0.0))
	var spawn_turret_rotation: float = float(player_state.get("turret_rotation", 0.0))
	_spawn_remote_tank(peer_id, player_name, spawn_position, spawn_rotation, spawn_turret_rotation)


func _remove_stale_remote_tanks(seen_peer_ids: Dictionary) -> void:
	var stale_peer_ids: Array[int] = []
	for peer_id_variant: Variant in remote_tanks_by_peer_id.keys():
		var peer_id: int = int(peer_id_variant)
		if seen_peer_ids.has(peer_id):
			continue
		stale_peer_ids.append(peer_id)
	for stale_peer_id: int in stale_peer_ids:
		var stale_tank: Tank = remote_tanks_by_peer_id.get(stale_peer_id)
		if stale_tank != null:
			stale_tank.queue_free()
		remote_tanks_by_peer_id.erase(stale_peer_id)
		remote_snapshot_history_by_peer_id.erase(stale_peer_id)
		print("%s[sync][remote] despawned peer=%d" % [_log_prefix(), stale_peer_id])


func _update_remote_tank_interpolation() -> void:
	if latest_snapshot_server_tick <= 0:
		return
	var elapsed_since_latest_snapshot_seconds: float = max(
		0.0, _get_now_seconds() - latest_snapshot_received_local_time_seconds
	)
	var projected_server_tick: float = (
		float(latest_snapshot_server_tick)
		+ elapsed_since_latest_snapshot_seconds * estimated_server_ticks_per_second
	)
	var target_tick: float = max(0.0, projected_server_tick - float(snapshot_render_delay_ticks))
	for peer_id_variant: Variant in remote_tanks_by_peer_id.keys():
		var peer_id: int = int(peer_id_variant)
		var remote_tank: Tank = remote_tanks_by_peer_id.get(peer_id)
		if remote_tank == null:
			continue
		var history: Array = remote_snapshot_history_by_peer_id.get(peer_id, [])
		if history.is_empty():
			continue
		var older_sample: Dictionary = {}
		var newer_sample: Dictionary = {}
		for history_sample_variant: Variant in history:
			var history_sample: Dictionary = history_sample_variant
			var sample_tick: int = int(history_sample.get("server_tick", 0))
			if float(sample_tick) <= target_tick:
				older_sample = history_sample
			if float(sample_tick) >= target_tick:
				newer_sample = history_sample
				break
		if older_sample.is_empty():
			older_sample = history[0]
		if newer_sample.is_empty():
			newer_sample = history[history.size() - 1]
		var older_tick: int = int(older_sample.get("server_tick", 0))
		var newer_tick: int = int(newer_sample.get("server_tick", 0))
		var blend_t: float = 0.0
		if newer_tick > older_tick:
			blend_t = clamp(
				(target_tick - float(older_tick)) / float(newer_tick - older_tick), 0.0, 1.0
			)
		var older_position: Vector2 = older_sample.get("position", remote_tank.global_position)
		var newer_position: Vector2 = newer_sample.get("position", older_position)
		var older_rotation: float = float(older_sample.get("rotation", remote_tank.global_rotation))
		var newer_rotation: float = float(newer_sample.get("rotation", older_rotation))
		var older_turret_rotation: float = float(
			older_sample.get("turret_rotation", remote_tank.turret.rotation)
		)
		var newer_turret_rotation: float = float(
			newer_sample.get("turret_rotation", older_turret_rotation)
		)
		remote_tank.global_position = older_position.lerp(newer_position, blend_t)
		remote_tank.global_rotation = lerp_angle(older_rotation, newer_rotation, blend_t)
		remote_tank.turret.rotation = lerp_angle(
			older_turret_rotation, newer_turret_rotation, blend_t
		)


func _spawn_remote_tank(
	peer_id: int,
	player_name: String,
	spawn_position: Vector2,
	spawn_rotation: float,
	spawn_turret_rotation: float
) -> void:
	assert(arena_level != null, "ArenaReplication requires arena_level")
	var remote_tank: Tank = TankManager.create_tank(
		TankManager.TankId.M4A1_SHERMAN, TankManager.TankControllerType.DUMMY
	)
	remote_tank.display_player_name = player_name.strip_edges()
	remote_tank.freeze = true
	remote_tank.sleeping = true
	arena_level.add_child(remote_tank)
	remote_tank.apply_spawn_state(spawn_position, spawn_rotation, spawn_turret_rotation)
	remote_tanks_by_peer_id[peer_id] = remote_tank
	print(
		(
			"%s[sync][remote] spawned peer=%d player=%s pos=%s rot=%.3f"
			% [_log_prefix(), peer_id, player_name, spawn_position, spawn_rotation]
		)
	)


func _log_prefix() -> String:
	var process_id: int = int(log_context.get("process_id", OS.get_process_id()))
	var peer_id: int = int(log_context.get("peer_id", 0))
	return "[client-repl pid=%d peer=%d]" % [process_id, peer_id]


func _get_now_seconds() -> float:
	return float(Time.get_ticks_usec()) / 1_000_000.0
