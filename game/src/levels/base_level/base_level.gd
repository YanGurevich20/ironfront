class_name BaseLevel extends Node2D

#region Declarations

signal level_finished(
	success: bool, metrics: Dictionary[Metrics.Metric, int], objectives: Array[Objective]
)

signal objectives_updated(objectives: Array[Objective])

const TANK_CONTROLLER_TYPE := TankManager.TankControllerType

@export var score_thresholds: Dictionary = {"one_star": 30, "two_star": 60, "three_star": 100}
@export var objective_manager := ObjectiveManager.new()
@export var level_name := "level x"
@export var level_index: int

var run_time: float = 0.0
var enemies_left: int = 0
var player_tank: Tank
var next_local_kill_event_seq: int = 1
var pending_kill_context_by_victim_id: Dictionary[int, Dictionary] = {}
@onready var level_metrics: Metrics = Metrics.new()
@onready var metric_enum := Metrics.Metric
@onready var entities: Node2D = $Entities
@onready var player_spawn_point: Marker2D = $SpawnPoints/PlayerSpawnPoint
@onready var enemy_spawn_points: Array[SpawnPoint] = []


#endregion
#region Lifecycle
func _ready() -> void:
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)
	Utils.connect_checked(GameplayBus.tank_destroyed, _on_tank_destroyed)
	_initialize_spawn_points()


func _initialize_spawn_points() -> void:
	for spawn_point in $SpawnPoints.get_children() as Array[SpawnPoint]:
		if spawn_point.type != SpawnPoint.Type.PLAYER:
			enemy_spawn_points.append(spawn_point)


func start_level() -> void:
	next_local_kill_event_seq = 1
	pending_kill_context_by_victim_id.clear()
	_spawn_player()
	_spawn_enemies()
	_count_remaining_enemies()
	evaluate_metrics_and_objectives(false)


func _process(delta: float) -> void:
	run_time += delta


func finish_level(success: bool) -> void:
	evaluate_metrics_and_objectives(true)
	var result: Dictionary = objective_manager.get_objective_evaluation_result()
	var objective_count: int = result[ObjectiveManager.ObjectiveResult.COUNT]
	var objective_score: int = result[ObjectiveManager.ObjectiveResult.SCORE]
	var stars := calculate_stars(success, objective_score)
	(
		level_metrics
		. set_metrics(
			{
				metric_enum.STARS_EARNED: stars,
				metric_enum.SCORE_EARNED: objective_score,
				metric_enum.OBJECTIVES_COMPLETED: objective_count,
			}
		)
	)
	level_finished.emit(success, level_metrics.metrics, objective_manager.objectives)


#endregion
#region Metrics and Objectives
func _count_remaining_enemies() -> void:
	var entities_children: Array[Node] = entities.get_children()
	enemies_left = (
		entities_children
		. filter(func(entity: Node) -> bool: return entity is Tank and !(entity as Tank).is_player)
		. size()
	)


func calculate_stars(success: bool, score: int) -> int:
	if not success:
		return 0
	if score >= score_thresholds["three_star"]:
		return 3
	if score >= score_thresholds["two_star"]:
		return 2
	if score >= score_thresholds["one_star"]:
		return 1
	return 0


func _update_metrics(_is_level_finished: bool) -> void:
	var distance_traveled := roundi(player_tank.distance_traveled) if player_tank else 0
	(
		level_metrics
		. set_metrics(
			{
				metric_enum.DISTANCE_TRAVELED: distance_traveled,
				metric_enum.RUN_TIME: run_time,
				metric_enum.LEVELS_PLAYED: 1,
			}
		)
	)


func evaluate_metrics_and_objectives(is_level_finished: bool) -> void:
	_update_metrics(is_level_finished)
	objective_manager.evaluate_objectives(level_metrics.metrics)
	objectives_updated.emit(objective_manager.objectives)


#endregion
#region Tank Spawning
func _spawn_tank(tank: Tank, spawn_point: Marker2D) -> void:
	print("BaseLevel: spawn_tank (tank=%s id=%s)" % [tank.name, str(tank.get_instance_id())])
	Utils.connect_checked(tank.damage_taken, _on_damage_taken)
	entities.add_child(tank)
	tank.apply_spawn_state(spawn_point.global_position, spawn_point.global_rotation)


func _spawn_player() -> void:
	var player_data: PlayerData = PlayerData.get_instance()
	var selected_tank_id: String = player_data.selected_tank_id
	var unlocked_tank_ids: Array[String] = player_data.get_unlocked_tank_ids()
	if !unlocked_tank_ids.has(selected_tank_id):
		if unlocked_tank_ids.size() > 0:
			selected_tank_id = unlocked_tank_ids[0]
		else:
			selected_tank_id = TankManager.TANK_ID_TIGER_1
	var player: Tank = TankManager.create_tank(selected_tank_id, TANK_CONTROLLER_TYPE.PLAYER)
	player_tank = player
	_spawn_tank(player_tank, player_spawn_point)


func _spawn_enemies() -> void:
	for spawn_point: SpawnPoint in enemy_spawn_points:
		var is_dummy: bool = spawn_point.type == SpawnPoint.Type.DUMMY
		var controller_type: TankManager.TankControllerType = (
			TANK_CONTROLLER_TYPE.DUMMY if is_dummy else TANK_CONTROLLER_TYPE.AI
		)
		var enemy_tank: Tank = TankManager.create_tank(
			TankManager.TANK_ID_M4A1_SHERMAN, controller_type
		)
		_spawn_tank(enemy_tank, spawn_point)


#endregion
#region Signal Handlers
func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	entities.add_child(shell)
	Utils.connect_checked(shell.impact_resolved, _on_shell_impact_resolved)

	if tank == player_tank:
		level_metrics.increment_metric(metric_enum.SHOTS_FIRED)


func _on_damage_taken(amount: int, tank: Tank) -> void:
	if tank == player_tank:
		level_metrics.increment_metric(metric_enum.DAMAGE_TAKEN, amount)
	else:
		level_metrics.increment_metric(metric_enum.DAMAGE_DEALT, amount)
		level_metrics.increment_metric(metric_enum.SHOTS_HIT)


func _on_tank_destroyed(tank: Tank) -> void:
	_handle_tank_destroyed.call_deferred(tank)


func _on_shell_impact_resolved(
	shell: Shell,
	target_tank: Tank,
	result_type: ShellSpec.ImpactResultType,
	damage: int,
	_hit_position: Vector2,
	_post_impact_velocity: Vector2,
	_post_impact_rotation: float,
	_continue_simulation: bool
) -> void:
	if player_tank == null:
		return
	var firing_tank: Tank = shell.firing_tank as Tank
	if firing_tank == null:
		return
	var local_is_firing: bool = firing_tank == player_tank
	var local_is_target: bool = target_tank == player_tank
	if not local_is_firing and not local_is_target:
		return
	var related_tank: Tank = target_tank if local_is_firing else firing_tank
	if damage > 0:
		pending_kill_context_by_victim_id[target_tank.get_instance_id()] = {
			"killer_name": _resolve_player_name(firing_tank),
			"killer_tank_name": _resolve_tank_name(firing_tank),
			"killer_is_local": local_is_firing,
			"shell_short_name": _resolve_shell_type_label(shell),
		}
	GameplayBus.player_impact_event.emit(
		local_is_target,
		int(result_type),
		damage,
		_resolve_tank_name(related_tank),
		_resolve_shell_type_label(shell)
	)


func _resolve_tank_name(tank: Tank) -> String:
	if tank == null or tank.tank_spec == null:
		return "TANK"
	var display_name: String = tank.tank_spec.display_name.strip_edges()
	if display_name.is_empty():
		return "TANK"
	return display_name


func _resolve_player_name(tank: Tank) -> String:
	if tank == null:
		return "PLAYER"
	var resolved_name: String = tank.display_player_name.strip_edges()
	if not resolved_name.is_empty():
		return resolved_name
	if not tank.is_player:
		return "AI"
	var player_name: String = PlayerData.get_instance().player_name.strip_edges()
	return player_name if not player_name.is_empty() else "PLAYER"


func _resolve_shell_type_label(shell: Shell) -> String:
	if shell == null or shell.shell_spec == null or shell.shell_spec.base_shell_type == null:
		return "SHELL"
	var shell_type_name: String = (
		str(BaseShellType.ShellType.find_key(shell.shell_spec.base_shell_type.shell_type))
		. strip_edges()
	)
	if shell_type_name.is_empty():
		return "SHELL"
	return shell_type_name


func _handle_tank_destroyed(tank: Tank) -> void:
	_emit_player_kill_event_for_victim(tank)
	if tank == player_tank:
		level_metrics.increment_metric(metric_enum.DEATHS)
		finish_level(false)
	else:
		enemies_left -= 1
		level_metrics.increment_metric(metric_enum.KILLS)

		if enemies_left == 0:
			finish_level(true)


func _emit_player_kill_event_for_victim(victim_tank: Tank) -> void:
	if victim_tank == null:
		return
	var victim_id: int = victim_tank.get_instance_id()
	var kill_context: Dictionary = pending_kill_context_by_victim_id.get(victim_id, {})
	pending_kill_context_by_victim_id.erase(victim_id)
	if kill_context.is_empty():
		return
	var event_seq: int = next_local_kill_event_seq
	next_local_kill_event_seq += 1
	GameplayBus.player_kill_event.emit(
		event_seq,
		str(kill_context.get("killer_name", "PLAYER")),
		str(kill_context.get("killer_tank_name", "TANK")),
		bool(kill_context.get("killer_is_local", false)),
		str(kill_context.get("shell_short_name", "SHELL")),
		_resolve_player_name(victim_tank),
		_resolve_tank_name(victim_tank),
		victim_tank == player_tank
	)
#endregion
