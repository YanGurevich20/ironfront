class_name ServerArenaActorUtils
extends RefCounted

const BOT_ACTOR_ID_START: int = -1


static func spawn_initial_bots(runtime: ServerArenaRuntime) -> void:
	for bot_index: int in range(runtime.bot_count):
		var bot_display_index: int = bot_index + 1
		spawn_bot_actor(runtime, bot_display_index)


static func spawn_bot_actor(runtime: ServerArenaRuntime, bot_display_index: int) -> bool:
	if runtime.arena_level == null:
		return false
	var random_spawn: Dictionary = pick_random_spawn(runtime)
	if random_spawn.is_empty():
		push_warning("[server][arena-runtime] bot_spawn_failed reason=NO_SPAWN_AVAILABLE")
		return false
	var spawn_id: StringName = random_spawn.get("spawn_id", StringName())
	var spawn_transform: Transform2D = random_spawn.get("spawn_transform", Transform2D.IDENTITY)
	var actor_id: int = allocate_bot_actor_id(runtime)
	var bot_tank: Tank = TankManager.create_tank(
		TankManager.TankId.M4A1_SHERMAN, TankManager.TankControllerType.AI
	)
	bot_tank.add_to_group("arena_bot")
	var bot_player_name: String = "BOT%d" % bot_display_index
	bot_tank.display_player_name = bot_player_name
	register_actor(
		runtime,
		actor_id,
		bot_tank,
		spawn_id,
		{
			"is_bot": true,
			"player_name": bot_player_name,
			"tank_id": int(TankManager.TankId.M4A1_SHERMAN),
			"bot_display_index": bot_display_index,
		}
	)
	bot_tank.apply_spawn_state(spawn_transform.origin, spawn_transform.get_rotation())
	print(
		(
			"[server][arena-runtime] bot_spawned actor=%d name=%s spawn_id=%s"
			% [actor_id, bot_player_name, spawn_id]
		)
	)
	return true


static func schedule_bot_respawn(runtime: ServerArenaRuntime, actor_id: int) -> void:
	for pending_respawn: Dictionary in runtime.pending_bot_respawns:
		if int(pending_respawn.get("actor_id", 0)) == actor_id:
			return
	var actor_metadata: Dictionary = runtime.actor_metadata_by_id.get(actor_id, {})
	var bot_display_index: int = int(actor_metadata.get("bot_display_index", 0))
	if bot_display_index <= 0:
		return
	(
		runtime
		. pending_bot_respawns
		. append(
			{
				"actor_id": actor_id,
				"bot_display_index": bot_display_index,
				"delay_left": runtime.bot_respawn_delay_seconds,
			}
		)
	)
	print(
		(
			"[server][arena-runtime] bot_respawn_scheduled actor=%d delay=%.2fs"
			% [actor_id, runtime.bot_respawn_delay_seconds]
		)
	)


static func update_pending_bot_respawns(runtime: ServerArenaRuntime, delta: float) -> void:
	if runtime.pending_bot_respawns.is_empty():
		return
	var ready_respawns: Array[Dictionary] = []
	for index: int in range(runtime.pending_bot_respawns.size()):
		var pending_respawn: Dictionary = runtime.pending_bot_respawns[index]
		var delay_left: float = max(0.0, float(pending_respawn.get("delay_left", 0.0)) - delta)
		runtime.pending_bot_respawns[index]["delay_left"] = delay_left
		if delay_left <= 0.0:
			ready_respawns.append(pending_respawn)
	if ready_respawns.is_empty():
		return
	var ready_actor_ids: Array[int] = []
	for ready_respawn: Dictionary in ready_respawns:
		ready_actor_ids.append(int(ready_respawn.get("actor_id", 0)))
	runtime.pending_bot_respawns = runtime.pending_bot_respawns.filter(
		func(pending_respawn: Dictionary) -> bool:
			return not ready_actor_ids.has(int(pending_respawn.get("actor_id", 0)))
	)
	for ready_respawn: Dictionary in ready_respawns:
		var actor_id: int = int(ready_respawn.get("actor_id", 0))
		var bot_display_index: int = int(ready_respawn.get("bot_display_index", 0))
		if bot_display_index <= 0:
			continue
		despawn_actor(runtime, actor_id, "BOT_RESPAWN")
		spawn_bot_actor(runtime, bot_display_index)


static func register_actor(
	runtime: ServerArenaRuntime,
	actor_id: int,
	spawned_tank: Tank,
	spawn_id: StringName,
	actor_metadata: Dictionary
) -> void:
	runtime.arena_level.add_child(spawned_tank)
	runtime.actor_tanks_by_id[actor_id] = spawned_tank
	runtime.actor_metadata_by_id[actor_id] = actor_metadata.duplicate(true)
	runtime.actor_id_by_tank_instance_id[spawned_tank.get_instance_id()] = actor_id
	runtime.actor_spawn_ids_by_id[actor_id] = spawn_id


static func despawn_actor(runtime: ServerArenaRuntime, actor_id: int, reason: String) -> void:
	var spawned_tank: Tank = runtime.actor_tanks_by_id.get(actor_id)
	if spawned_tank != null:
		spawned_tank.remove_from_group("arena_human_player")
		runtime.actor_id_by_tank_instance_id.erase(spawned_tank.get_instance_id())
		spawned_tank.queue_free()
	runtime.actor_tanks_by_id.erase(actor_id)
	runtime.actor_spawn_ids_by_id.erase(actor_id)
	runtime.actor_metadata_by_id.erase(actor_id)
	print("[server][arena-runtime] tank_despawned actor=%d reason=%s" % [actor_id, reason])


static func respawn_peer_tank_at_random(
	runtime: ServerArenaRuntime, peer_id: int, player_name: String, tank_id: int
) -> Dictionary:
	if not runtime.is_peer_tank_dead(peer_id):
		return {"success": false, "reason": "TANK_NOT_DEAD"}
	var random_spawn: Dictionary = pick_random_spawn(runtime)
	if random_spawn.is_empty():
		return {"success": false, "reason": "NO_SPAWN_AVAILABLE"}
	var spawn_id: StringName = random_spawn.get("spawn_id", StringName())
	var spawn_transform: Transform2D = random_spawn.get("spawn_transform", Transform2D.IDENTITY)
	var respawned: bool = runtime.respawn_peer_tank(
		peer_id, player_name, tank_id, spawn_id, spawn_transform
	)
	if not respawned:
		return {"success": false, "reason": "RESPAWN_FAILED"}
	return {
		"success": true,
		"spawn_id": spawn_id,
		"spawn_transform": spawn_transform,
	}


static func spawn_peer_tank_at_random(
	runtime: ServerArenaRuntime, peer_id: int, player_name: String, tank_id: int
) -> Dictionary:
	var random_spawn: Dictionary = pick_random_spawn(runtime)
	if random_spawn.is_empty():
		return {"success": false, "reason": "NO_SPAWN_AVAILABLE"}
	var spawn_id: StringName = random_spawn.get("spawn_id", StringName())
	var spawn_transform: Transform2D = random_spawn.get("spawn_transform", Transform2D.IDENTITY)
	runtime.spawn_peer_tank(peer_id, player_name, tank_id, spawn_id, spawn_transform)
	return {
		"success": true,
		"spawn_id": spawn_id,
		"spawn_transform": spawn_transform,
	}


static func pick_random_spawn(runtime: ServerArenaRuntime) -> Dictionary:
	var available_spawn_ids: Array[StringName] = runtime.arena_spawn_transforms_by_id.keys()
	if available_spawn_ids.is_empty():
		return {}
	available_spawn_ids.shuffle()
	var selected_spawn_id: StringName = available_spawn_ids[0]
	return {
		"spawn_id": selected_spawn_id,
		"spawn_transform": runtime.arena_spawn_transforms_by_id[selected_spawn_id],
	}


static func allocate_bot_actor_id(runtime: ServerArenaRuntime) -> int:
	while runtime.actor_tanks_by_id.has(runtime.next_bot_actor_id):
		runtime.next_bot_actor_id -= 1
	var actor_id: int = runtime.next_bot_actor_id
	runtime.next_bot_actor_id -= 1
	return actor_id


static func clear_runtime(runtime: ServerArenaRuntime) -> void:
	for tank: Tank in runtime.actor_tanks_by_id.values():
		tank.queue_free()
	runtime.actor_tanks_by_id.clear()
	runtime.actor_metadata_by_id.clear()
	runtime.actor_id_by_tank_instance_id.clear()
	runtime.actor_spawn_ids_by_id.clear()
	runtime.arena_spawn_transforms_by_id.clear()
	runtime.pending_bot_respawns.clear()
	runtime.shot_id_by_shell_instance_id.clear()
	runtime.firing_actor_id_by_shell_instance_id.clear()
	runtime.shell_spec_cache_by_path.clear()
	runtime.next_shell_shot_id = 1
	runtime.next_kill_event_seq = 1
	runtime.next_bot_actor_id = BOT_ACTOR_ID_START

	if runtime.arena_level != null:
		if runtime.arena_level.get_parent() == runtime:
			runtime.remove_child(runtime.arena_level)
		runtime.arena_level.queue_free()
	runtime.arena_level = null


static func get_actor_player_name(runtime: ServerArenaRuntime, actor_id: int) -> String:
	var actor_metadata: Dictionary = runtime.actor_metadata_by_id.get(actor_id, {})
	var player_name: String = str(actor_metadata.get("player_name", "")).strip_edges()
	if not player_name.is_empty():
		return player_name
	if runtime.arena_session_state == null:
		return str(actor_id)
	var peer_state: Dictionary = runtime.arena_session_state.get_peer_state(actor_id)
	player_name = str(peer_state.get("player_name", "")).strip_edges()
	if player_name.is_empty():
		return str(actor_id)
	return player_name


static func get_actor_tank_display_name(runtime: ServerArenaRuntime, actor_id: int) -> String:
	var live_tank: Tank = runtime.actor_tanks_by_id.get(actor_id)
	var tank_spec: TankSpec = null
	if live_tank != null:
		tank_spec = live_tank.tank_spec
	if tank_spec == null:
		var actor_metadata: Dictionary = runtime.actor_metadata_by_id.get(actor_id, {})
		var tank_id: int = int(actor_metadata.get("tank_id", ArenaSessionState.DEFAULT_TANK_ID))
		if TankManager.tank_specs.has(tank_id):
			tank_spec = TankManager.tank_specs[tank_id]
	if tank_spec == null:
		return "TANK"
	var display_name: String = tank_spec.display_name.strip_edges()
	if not display_name.is_empty():
		return display_name
	var full_name: String = tank_spec.full_name.strip_edges()
	if not full_name.is_empty():
		return full_name
	return "TANK"
