class_name ArenaActors
extends Node

const BOT_ACTOR_ID_START: int = -1

var runtime: ServerArenaRuntime
var arena_level: ArenaLevelMvp
var arena_spawn_transforms_by_id: Dictionary[StringName, Transform2D] = {}
var actor_tanks_by_id: Dictionary[int, Tank] = {}
var actor_metadata_by_id: Dictionary[int, Dictionary] = {}
var actor_id_by_tank_instance_id: Dictionary[int, int] = {}
var actor_spawn_ids_by_id: Dictionary[int, StringName] = {}
var bot_count: int = 0
var bot_respawn_delay_seconds: float = 5.0
var next_bot_actor_id: int = BOT_ACTOR_ID_START
var pending_bot_respawns: Array[Dictionary] = []


func _ready() -> void:
	Utils.connect_checked(GameplayBus.tank_destroyed, _on_tank_destroyed)


func configure(next_runtime: ServerArenaRuntime) -> void:
	runtime = next_runtime


func configure_bot_settings(next_bot_count: int, next_bot_respawn_delay_seconds: float) -> void:
	bot_count = max(0, next_bot_count)
	bot_respawn_delay_seconds = max(0.0, next_bot_respawn_delay_seconds)


func initialize_runtime(arena_level_packed_scene: PackedScene) -> bool:
	if arena_level_packed_scene == null:
		push_error("[server][arena-runtime] missing arena level scene")
		return false
	var arena_level_node: Node = arena_level_packed_scene.instantiate()
	var arena_level_candidate: ArenaLevelMvp = arena_level_node as ArenaLevelMvp
	if arena_level_candidate == null:
		push_error("[server][arena-runtime] arena level scene root must use ArenaLevelMvp script")
		arena_level_node.queue_free()
		return false
	add_child(arena_level_candidate)
	arena_level = arena_level_candidate
	var validation_result: Dictionary = arena_level.validate_spawn_markers()
	var is_valid: bool = validation_result.get("valid", false)
	var spawn_count: int = validation_result.get("spawn_count", 0)
	var empty_spawn_id_count: int = validation_result.get("empty_spawn_id_count", 0)
	var duplicate_spawn_ids: PackedStringArray = validation_result.get("duplicate_spawn_ids", [])
	if not is_valid:
		push_error(
			(
				"[server][arena-runtime] invalid spawn config count=%d empty_ids=%d duplicates=%s"
				% [spawn_count, empty_spawn_id_count, duplicate_spawn_ids]
			)
		)
		clear_runtime()
		return false
	arena_spawn_transforms_by_id = arena_level.get_spawn_transforms_by_id().duplicate(true)
	if arena_spawn_transforms_by_id.is_empty():
		push_error("[server][arena-runtime] spawn config produced zero spawn transforms")
		clear_runtime()
		return false
	_spawn_initial_bots()
	print(
		(
			(
				"[server][arena-runtime] initialized level=res://src/levels/arena/arena_level_mvp.tscn "
				+ "count=%d bots=%d"
			)
			% [spawn_count, bot_count]
		)
	)
	return true


func get_spawn_transforms_by_id() -> Dictionary[StringName, Transform2D]:
	return arena_spawn_transforms_by_id.duplicate(true)


func spawn_peer_tank_at_random(peer_id: int, player_name: String, tank_id: String) -> Dictionary:
	var random_spawn: Dictionary = _pick_random_spawn()
	if random_spawn.is_empty():
		return {"success": false, "reason": "NO_SPAWN_AVAILABLE"}
	var spawn_id: StringName = random_spawn.get("spawn_id", StringName())
	var spawn_transform: Transform2D = random_spawn.get("spawn_transform", Transform2D.IDENTITY)
	_spawn_peer_tank(peer_id, player_name, tank_id, spawn_id, spawn_transform)
	return {
		"success": true,
		"spawn_id": spawn_id,
		"spawn_transform": spawn_transform,
	}


func respawn_peer_tank_at_random(peer_id: int, player_name: String, tank_id: String) -> Dictionary:
	if not is_peer_tank_dead(peer_id):
		return {"success": false, "reason": "TANK_NOT_DEAD"}
	var random_spawn: Dictionary = _pick_random_spawn()
	if random_spawn.is_empty():
		return {"success": false, "reason": "NO_SPAWN_AVAILABLE"}
	var spawn_id: StringName = random_spawn.get("spawn_id", StringName())
	var spawn_transform: Transform2D = random_spawn.get("spawn_transform", Transform2D.IDENTITY)
	var respawned: bool = _respawn_peer_tank(
		peer_id, player_name, tank_id, spawn_id, spawn_transform
	)
	if not respawned:
		return {"success": false, "reason": "RESPAWN_FAILED"}
	return {
		"success": true,
		"spawn_id": spawn_id,
		"spawn_transform": spawn_transform,
	}


func _spawn_peer_tank(
	peer_id: int,
	player_name: String,
	tank_id: String,
	spawn_id: StringName,
	spawn_transform: Transform2D
) -> void:
	if actor_tanks_by_id.has(peer_id):
		despawn_peer_tank(peer_id, "REPLACED_EXISTING_TANK")
	var validated_tank_id: String = ArenaLoadoutAuthorityUtils.resolve_valid_tank_id(tank_id)
	var spawned_tank: Tank = TankManager.create_tank(
		validated_tank_id, TankManager.TankControllerType.DUMMY
	)
	spawned_tank.add_to_group("arena_human_player")
	_register_actor(
		peer_id,
		spawned_tank,
		spawn_id,
		{
			"is_bot": false,
			"player_name": player_name,
			"tank_id": validated_tank_id,
		}
	)
	spawned_tank.apply_spawn_state(spawn_transform.origin, spawn_transform.get_rotation())
	ArenaLoadoutAuthorityUtils.sync_peer_tank_shell_state(runtime, peer_id, spawned_tank)
	ArenaLoadoutAuthorityUtils.send_peer_loadout_state(runtime, peer_id, spawned_tank)
	print(
		(
			(
				"[server][arena-runtime] tank_spawned actor=%d player=%s "
				+ "spawn_id=%s tank_instance=%s"
			)
			% [peer_id, player_name, spawn_id, str(spawned_tank.get_instance_id())]
		)
	)


func _respawn_peer_tank(
	peer_id: int,
	player_name: String,
	tank_id: String,
	spawn_id: StringName,
	spawn_transform: Transform2D
) -> bool:
	if not is_peer_tank_dead(peer_id):
		return false
	_spawn_peer_tank(peer_id, player_name, tank_id, spawn_id, spawn_transform)
	print("[server][arena-runtime] tank_respawned actor=%d spawn_id=%s" % [peer_id, spawn_id])
	return true


func despawn_peer_tank(peer_id: int, reason: String) -> void:
	_despawn_actor(peer_id, reason)


func is_peer_tank_dead(peer_id: int) -> bool:
	var spawned_tank: Tank = actor_tanks_by_id.get(peer_id)
	if spawned_tank == null:
		return false
	return spawned_tank._health <= 0


func update_pending_bot_respawns(delta: float) -> void:
	if pending_bot_respawns.is_empty():
		return
	var ready_respawns: Array[Dictionary] = []
	for index: int in range(pending_bot_respawns.size()):
		var pending_respawn: Dictionary = pending_bot_respawns[index]
		var delay_left: float = max(0.0, float(pending_respawn.get("delay_left", 0.0)) - delta)
		pending_bot_respawns[index]["delay_left"] = delay_left
		if delay_left <= 0.0:
			ready_respawns.append(pending_respawn)
	if ready_respawns.is_empty():
		return
	var ready_actor_ids: Array[int] = []
	for ready_respawn: Dictionary in ready_respawns:
		ready_actor_ids.append(int(ready_respawn.get("actor_id", 0)))
	pending_bot_respawns = pending_bot_respawns.filter(
		func(pending_respawn: Dictionary) -> bool:
			return not ready_actor_ids.has(int(pending_respawn.get("actor_id", 0)))
	)
	for ready_respawn: Dictionary in ready_respawns:
		var actor_id: int = int(ready_respawn.get("actor_id", 0))
		var bot_display_index: int = int(ready_respawn.get("bot_display_index", 0))
		if bot_display_index <= 0:
			continue
		_despawn_actor(actor_id, "BOT_RESPAWN")
		_spawn_bot_actor(bot_display_index)


func get_actor_player_name(actor_id: int) -> String:
	var metadata: Dictionary = actor_metadata_by_id[actor_id]
	var player_name: String = str(metadata["player_name"]).strip_edges()
	assert(not player_name.is_empty(), "actor %d missing player_name metadata" % actor_id)
	return player_name


func get_actor_tank_display_name(actor_id: int) -> String:
	var live_tank: Tank = actor_tanks_by_id[actor_id]
	var tank_spec: TankSpec = live_tank.tank_spec
	assert(tank_spec != null, "actor %d missing tank_spec" % actor_id)
	var tank_display_name: String = tank_spec.display_name.strip_edges()
	if tank_display_name.is_empty():
		tank_display_name = tank_spec.full_name.strip_edges()
	assert(
		not tank_display_name.is_empty(), "actor %d tank_spec missing display/full name" % actor_id
	)
	return tank_display_name


func clear_runtime() -> void:
	for tank: Tank in actor_tanks_by_id.values():
		tank.queue_free()
	actor_tanks_by_id.clear()
	actor_metadata_by_id.clear()
	actor_id_by_tank_instance_id.clear()
	actor_spawn_ids_by_id.clear()
	arena_spawn_transforms_by_id.clear()
	pending_bot_respawns.clear()
	next_bot_actor_id = BOT_ACTOR_ID_START
	if arena_level != null:
		if arena_level.get_parent() == self:
			remove_child(arena_level)
		arena_level.queue_free()
	arena_level = null


func _spawn_initial_bots() -> void:
	for bot_index: int in range(bot_count):
		var bot_display_index: int = bot_index + 1
		_spawn_bot_actor(bot_display_index)


func _spawn_bot_actor(bot_display_index: int) -> bool:
	if arena_level == null:
		return false
	var random_spawn: Dictionary = _pick_random_spawn()
	if random_spawn.is_empty():
		push_warning("[server][arena-runtime] bot_spawn_failed reason=NO_SPAWN_AVAILABLE")
		return false
	var spawn_id: StringName = random_spawn.get("spawn_id", StringName())
	var spawn_transform: Transform2D = random_spawn.get("spawn_transform", Transform2D.IDENTITY)
	var actor_id: int = _allocate_bot_actor_id()
	var bot_tank: Tank = TankManager.create_tank(
		TankManager.TANK_ID_M4A1_SHERMAN, TankManager.TankControllerType.AI
	)
	bot_tank.add_to_group("arena_bot")
	var bot_player_name: String = "BOT%d" % bot_display_index
	bot_tank.display_player_name = bot_player_name
	_register_actor(
		actor_id,
		bot_tank,
		spawn_id,
		{
			"is_bot": true,
			"player_name": bot_player_name,
			"tank_id": TankManager.TANK_ID_M4A1_SHERMAN,
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


func _register_actor(
	actor_id: int, spawned_tank: Tank, spawn_id: StringName, metadata: Dictionary
) -> void:
	arena_level.add_child(spawned_tank)
	actor_tanks_by_id[actor_id] = spawned_tank
	actor_metadata_by_id[actor_id] = metadata.duplicate(true)
	actor_id_by_tank_instance_id[spawned_tank.get_instance_id()] = actor_id
	actor_spawn_ids_by_id[actor_id] = spawn_id


func _despawn_actor(actor_id: int, reason: String) -> void:
	var spawned_tank: Tank = actor_tanks_by_id.get(actor_id)
	if spawned_tank != null:
		spawned_tank.remove_from_group("arena_human_player")
		actor_id_by_tank_instance_id.erase(spawned_tank.get_instance_id())
		spawned_tank.queue_free()
	actor_tanks_by_id.erase(actor_id)
	actor_spawn_ids_by_id.erase(actor_id)
	actor_metadata_by_id.erase(actor_id)
	print("[server][arena-runtime] tank_despawned actor=%d reason=%s" % [actor_id, reason])


func _pick_random_spawn() -> Dictionary:
	var available_spawn_ids: Array[StringName] = arena_spawn_transforms_by_id.keys()
	if available_spawn_ids.is_empty():
		return {}
	available_spawn_ids.shuffle()
	var selected_spawn_id: StringName = available_spawn_ids[0]
	return {
		"spawn_id": selected_spawn_id,
		"spawn_transform": arena_spawn_transforms_by_id[selected_spawn_id],
	}


func _allocate_bot_actor_id() -> int:
	while actor_tanks_by_id.has(next_bot_actor_id):
		next_bot_actor_id -= 1
	var actor_id: int = next_bot_actor_id
	next_bot_actor_id -= 1
	return actor_id


func _schedule_bot_respawn(actor_id: int) -> void:
	for pending_respawn: Dictionary in pending_bot_respawns:
		if int(pending_respawn.get("actor_id", 0)) == actor_id:
			return
	var metadata: Dictionary = actor_metadata_by_id.get(actor_id, {})
	var bot_display_index: int = int(metadata.get("bot_display_index", 0))
	if bot_display_index <= 0:
		return
	(
		pending_bot_respawns
		. append(
			{
				"actor_id": actor_id,
				"bot_display_index": bot_display_index,
				"delay_left": bot_respawn_delay_seconds,
			}
		)
	)
	print(
		(
			"[server][arena-runtime] bot_respawn_scheduled actor=%d delay=%.2fs"
			% [actor_id, bot_respawn_delay_seconds]
		)
	)


func _on_tank_destroyed(tank: Tank) -> void:
	var tank_instance_id: int = tank.get_instance_id()
	if not actor_id_by_tank_instance_id.has(tank_instance_id):
		return
	var actor_id: int = actor_id_by_tank_instance_id[tank_instance_id]
	var metadata: Dictionary = actor_metadata_by_id.get(actor_id, {})
	if not bool(metadata.get("is_bot", false)):
		return
	_schedule_bot_respawn(actor_id)
