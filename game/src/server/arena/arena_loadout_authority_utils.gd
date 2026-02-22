class_name ArenaLoadoutAuthorityUtils
extends RefCounted


static func handle_peer_shell_select_request(
	runtime: ServerArenaRuntime,
	arena_session_state: ArenaSessionState,
	peer_id: int,
	spawned_tank: Tank,
	shell_select_request: Dictionary
) -> void:
	var shell_id: String = str(shell_select_request.get("shell_id", ""))
	var selected: bool = arena_session_state.apply_peer_shell_selection(peer_id, shell_id)
	if not selected:
		send_peer_loadout_state(runtime, peer_id, spawned_tank)
		return
	sync_peer_tank_shell_state(runtime, peer_id, spawned_tank)
	send_peer_loadout_state(runtime, peer_id, spawned_tank)


static func handle_peer_fire_request(
	runtime: ServerArenaRuntime,
	arena_session_state: ArenaSessionState,
	peer_id: int,
	spawned_tank: Tank
) -> void:
	var selected_shell_id: String = arena_session_state.get_peer_selected_shell_id(peer_id)
	var selected_shell_count: int = arena_session_state.get_peer_shell_count(
		peer_id, selected_shell_id
	)
	if selected_shell_count <= 0:
		reject_peer_fire(runtime, peer_id, spawned_tank, "OUT_OF_AMMO")
		return
	var selected_shell_spec: ShellSpec = ShellManager.get_shell_spec(selected_shell_id)
	assert(selected_shell_spec != null, "Invalid selected shell_id: %s" % selected_shell_id)
	spawned_tank.set_current_shell_spec(selected_shell_spec)
	spawned_tank.set_remaining_shell_count(selected_shell_count)
	if spawned_tank.turret.get_reload_time_left() > 0.0:
		reject_peer_fire(runtime, peer_id, spawned_tank, "RELOADING")
		return
	var fired: bool = spawned_tank.fire_shell()
	if not fired:
		reject_peer_fire(runtime, peer_id, spawned_tank, "FIRE_BLOCKED")
		return
	var consumed: bool = arena_session_state.consume_peer_shell_ammo(peer_id, selected_shell_id)
	if not consumed:
		push_warning(
			(
				"[server][arena-runtime] shell_consume_failed peer=%d shell=%s"
				% [peer_id, selected_shell_id]
			)
		)
	sync_peer_tank_shell_state(runtime, peer_id, spawned_tank)
	send_peer_loadout_state(runtime, peer_id, spawned_tank)


static func sync_peer_tank_shell_state(
	runtime: ServerArenaRuntime, peer_id: int, spawned_tank: Tank
) -> void:
	var selected_shell_id: String = runtime.arena_session_state.get_peer_selected_shell_id(peer_id)
	var selected_shell_spec: ShellSpec = ShellManager.get_shell_spec(selected_shell_id)
	assert(selected_shell_spec != null, "Invalid selected shell_id: %s" % selected_shell_id)
	var selected_shell_count: int = runtime.arena_session_state.get_peer_shell_count(
		peer_id, selected_shell_id
	)
	spawned_tank.set_current_shell_spec(selected_shell_spec)
	spawned_tank.set_remaining_shell_count(selected_shell_count)


static func send_peer_loadout_state(
	runtime: ServerArenaRuntime, peer_id: int, spawned_tank: Tank
) -> void:
	var selected_shell_id: String = runtime.arena_session_state.get_peer_selected_shell_id(peer_id)
	var shell_counts_by_id: Dictionary = runtime.arena_session_state.get_peer_ammo_by_shell_id(
		peer_id
	)
	var reload_time_left: float = spawned_tank.turret.get_reload_time_left()
	runtime.network_gameplay.send_arena_loadout_state(
		peer_id, selected_shell_id, shell_counts_by_id, reload_time_left
	)


static func reject_peer_fire(
	runtime: ServerArenaRuntime, peer_id: int, spawned_tank: Tank, reason: String
) -> void:
	runtime.network_gameplay.send_arena_fire_rejected(peer_id, reason)
	send_peer_loadout_state(runtime, peer_id, spawned_tank)


static func resolve_valid_tank_id(tank_id: String) -> String:
	if TankManager.tank_specs.has(tank_id):
		return tank_id
	return ArenaSessionState.DEFAULT_TANK_ID
