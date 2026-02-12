class_name ServerArenaLoadoutAuthorityUtils
extends RefCounted


static func handle_peer_shell_select_request(
	runtime: ServerArenaRuntime,
	arena_session_state: ArenaSessionState,
	peer_id: int,
	spawned_tank: Tank,
	shell_select_request: Dictionary
) -> void:
	var shell_spec_path: String = str(shell_select_request.get("shell_spec_path", ""))
	var selected: bool = arena_session_state.apply_peer_shell_selection(peer_id, shell_spec_path)
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
	var selected_shell_path: String = arena_session_state.get_peer_selected_shell_path(peer_id)
	if selected_shell_path.is_empty():
		reject_peer_fire(runtime, peer_id, spawned_tank, "NO_SELECTED_SHELL")
		return
	var selected_shell_count: int = arena_session_state.get_peer_shell_count(
		peer_id, selected_shell_path
	)
	if selected_shell_count <= 0:
		reject_peer_fire(runtime, peer_id, spawned_tank, "OUT_OF_AMMO")
		return
	var selected_shell_spec: ShellSpec = load_shell_spec(runtime, selected_shell_path)
	if selected_shell_spec == null:
		reject_peer_fire(runtime, peer_id, spawned_tank, "INVALID_SHELL_SELECTION")
		return
	spawned_tank.set_current_shell_spec(selected_shell_spec)
	spawned_tank.set_remaining_shell_count(selected_shell_count)
	if spawned_tank.turret.get_reload_time_left() > 0.0:
		reject_peer_fire(runtime, peer_id, spawned_tank, "RELOADING")
		return
	var fired: bool = spawned_tank.fire_shell()
	if not fired:
		reject_peer_fire(runtime, peer_id, spawned_tank, "FIRE_BLOCKED")
		return
	var consumed: bool = arena_session_state.consume_peer_shell_ammo(peer_id, selected_shell_path)
	if not consumed:
		push_warning(
			(
				"[server][arena-runtime] shell_consume_failed peer=%d shell=%s"
				% [peer_id, selected_shell_path]
			)
		)
	sync_peer_tank_shell_state(runtime, peer_id, spawned_tank)
	send_peer_loadout_state(runtime, peer_id, spawned_tank)


static func sync_peer_tank_shell_state(
	runtime: ServerArenaRuntime, peer_id: int, spawned_tank: Tank
) -> void:
	if spawned_tank == null or runtime.arena_session_state == null:
		return
	var selected_shell_path: String = runtime.arena_session_state.get_peer_selected_shell_path(
		peer_id
	)
	if selected_shell_path.is_empty():
		spawned_tank.set_remaining_shell_count(0)
		return
	var selected_shell_spec: ShellSpec = load_shell_spec(runtime, selected_shell_path)
	if selected_shell_spec == null:
		spawned_tank.set_remaining_shell_count(0)
		return
	var selected_shell_count: int = runtime.arena_session_state.get_peer_shell_count(
		peer_id, selected_shell_path
	)
	spawned_tank.set_current_shell_spec(selected_shell_spec)
	spawned_tank.set_remaining_shell_count(selected_shell_count)


static func send_peer_loadout_state(
	runtime: ServerArenaRuntime, peer_id: int, spawned_tank: Tank
) -> void:
	if runtime.network_server == null or runtime.arena_session_state == null:
		return
	var selected_shell_path: String = runtime.arena_session_state.get_peer_selected_shell_path(
		peer_id
	)
	var shell_counts_by_path: Dictionary = runtime.arena_session_state.get_peer_ammo_by_shell_path(
		peer_id
	)
	var reload_time_left: float = 0.0
	if spawned_tank != null:
		reload_time_left = spawned_tank.turret.get_reload_time_left()
	runtime.network_server.send_arena_loadout_state(
		peer_id, selected_shell_path, shell_counts_by_path, reload_time_left
	)


static func reject_peer_fire(
	runtime: ServerArenaRuntime, peer_id: int, spawned_tank: Tank, reason: String
) -> void:
	if runtime.network_server != null:
		runtime.network_server.send_arena_fire_rejected(peer_id, reason)
	send_peer_loadout_state(runtime, peer_id, spawned_tank)


static func load_shell_spec(runtime: ServerArenaRuntime, shell_spec_path: String) -> ShellSpec:
	if runtime.shell_spec_cache_by_path.has(shell_spec_path):
		return runtime.shell_spec_cache_by_path[shell_spec_path]
	var loaded_resource: Resource = load(shell_spec_path)
	var loaded_shell_spec: ShellSpec = loaded_resource as ShellSpec
	if loaded_shell_spec == null:
		return null
	runtime.shell_spec_cache_by_path[shell_spec_path] = loaded_shell_spec
	return loaded_shell_spec


static func resolve_valid_tank_id(tank_id: int) -> int:
	if TankManager.tank_specs.has(tank_id):
		return tank_id
	return ArenaSessionState.DEFAULT_TANK_ID
