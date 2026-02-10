class_name OnlineArenaSyncRuntime
extends Node

var arena_level: ArenaLevelMvp
var local_player_tank: Tank
var runtime_active: bool = false

var latest_snapshot_server_tick: int = 0
var snapshot_render_delay_ticks: int = 2
var remote_tanks_by_peer_id: Dictionary = {}
var remote_snapshot_history_by_peer_id: Dictionary = {}
var max_snapshot_history_per_peer: int = 24
var reconciliation_hard_snap_distance: float = 48.0
var reconciliation_soft_blend: float = 0.35


func start_runtime(next_arena_level: ArenaLevelMvp, next_local_player_tank: Tank) -> void:
	stop_runtime()
	arena_level = next_arena_level
	local_player_tank = next_local_player_tank
	runtime_active = arena_level != null and local_player_tank != null
	latest_snapshot_server_tick = 0
	remote_tanks_by_peer_id.clear()
	remote_snapshot_history_by_peer_id.clear()
	set_process(runtime_active)
	print(
		(
			"%s[sync] runtime_started local_tank=%s"
			% [_log_prefix(), str(local_player_tank.get_instance_id())]
		)
	)


func stop_runtime() -> void:
	for peer_id_variant: Variant in remote_tanks_by_peer_id.keys():
		var peer_id: int = int(peer_id_variant)
		var remote_tank: Tank = remote_tanks_by_peer_id.get(peer_id)
		if remote_tank == null:
			continue
		remote_tank.queue_free()
	remote_tanks_by_peer_id.clear()
	remote_snapshot_history_by_peer_id.clear()
	latest_snapshot_server_tick = 0
	arena_level = null
	local_player_tank = null
	runtime_active = false
	set_process(false)
	print("%s[sync] runtime_stopped" % _log_prefix())


func on_state_snapshot_received(server_tick: int, player_states: Array) -> void:
	if not runtime_active:
		return
	latest_snapshot_server_tick = max(latest_snapshot_server_tick, server_tick)
	var seen_peer_ids: Dictionary = {}
	for player_state_variant: Variant in player_states:
		var player_state: Dictionary = player_state_variant
		var peer_id: int = int(player_state.get("peer_id", 0))
		if peer_id <= 0:
			continue
		seen_peer_ids[peer_id] = true
		var authoritative_position: Vector2 = player_state.get("position", Vector2.ZERO)
		var authoritative_rotation: float = float(player_state.get("rotation", 0.0))
		var authoritative_linear_velocity: Vector2 = player_state.get(
			"linear_velocity", Vector2.ZERO
		)
		var last_processed_input_tick: int = int(player_state.get("last_processed_input_tick", 0))
		if peer_id == multiplayer.get_unique_id():
			_apply_local_reconciliation(
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
			authoritative_linear_velocity
		)
		_ensure_remote_tank(peer_id, player_state)
	_remove_stale_remote_tanks(seen_peer_ids)


func _process(_delta: float) -> void:
	if not runtime_active:
		return
	_update_remote_tank_interpolation()


func _apply_local_reconciliation(
	server_tick: int,
	authoritative_position: Vector2,
	authoritative_rotation: float,
	authoritative_linear_velocity: Vector2,
	last_processed_input_tick: int
) -> void:
	if local_player_tank == null:
		return
	var position_error: float = local_player_tank.global_position.distance_to(
		authoritative_position
	)
	if position_error > reconciliation_hard_snap_distance:
		local_player_tank.global_position = authoritative_position
		local_player_tank.global_rotation = authoritative_rotation
		local_player_tank.linear_velocity = authoritative_linear_velocity
		push_warning(
			(
				"%s[sync][local] hard_snap tick=%d error=%.2f last_input=%d"
				% [_log_prefix(), server_tick, position_error, last_processed_input_tick]
			)
		)
		return
	local_player_tank.global_position = local_player_tank.global_position.lerp(
		authoritative_position, reconciliation_soft_blend
	)
	local_player_tank.global_rotation = lerp_angle(
		local_player_tank.global_rotation, authoritative_rotation, reconciliation_soft_blend
	)
	local_player_tank.linear_velocity = local_player_tank.linear_velocity.lerp(
		authoritative_linear_velocity, reconciliation_soft_blend
	)


func _record_remote_snapshot(
	peer_id: int,
	server_tick: int,
	state_position: Vector2,
	state_rotation: float,
	state_linear_velocity: Vector2
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
			}
		)
	)
	while history.size() > max_snapshot_history_per_peer:
		history.remove_at(0)
	remote_snapshot_history_by_peer_id[peer_id] = history


func _ensure_remote_tank(peer_id: int, player_state: Dictionary) -> void:
	if remote_tanks_by_peer_id.has(peer_id):
		return
	if arena_level == null:
		return
	var remote_tank: Tank = TankManager.create_tank(
		TankManager.TankId.M4A1_SHERMAN, TankManager.TankControllerType.DUMMY
	)
	remote_tank.freeze = true
	remote_tank.sleeping = true
	var spawn_position: Vector2 = player_state.get("position", Vector2.ZERO)
	var spawn_rotation: float = float(player_state.get("rotation", 0.0))
	remote_tank.global_position = spawn_position
	remote_tank.global_rotation = spawn_rotation
	arena_level.add_child(remote_tank)
	remote_tanks_by_peer_id[peer_id] = remote_tank
	print(
		(
			"%s[sync][remote] spawned peer=%d player=%s pos=%s rot=%.3f"
			% [
				_log_prefix(),
				peer_id,
				str(player_state.get("player_name", "")),
				spawn_position,
				spawn_rotation
			]
		)
	)


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
	var target_tick: int = max(0, latest_snapshot_server_tick - snapshot_render_delay_ticks)
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
			if sample_tick <= target_tick:
				older_sample = history_sample
			if sample_tick >= target_tick:
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
				float(target_tick - older_tick) / float(newer_tick - older_tick), 0.0, 1.0
			)
		var older_position: Vector2 = older_sample.get("position", remote_tank.global_position)
		var newer_position: Vector2 = newer_sample.get("position", older_position)
		var older_rotation: float = float(older_sample.get("rotation", remote_tank.global_rotation))
		var newer_rotation: float = float(newer_sample.get("rotation", older_rotation))
		remote_tank.global_position = older_position.lerp(newer_position, blend_t)
		remote_tank.global_rotation = lerp_angle(older_rotation, newer_rotation, blend_t)


func _log_prefix() -> String:
	var peer_id: int = 0
	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.get_unique_id()
	return "[client-sync pid=%d peer=%d]" % [OS.get_process_id(), peer_id]
