class_name BaseLevel extends Node2D

#region Declarations
signal level_finished(success: bool, metrics: Dictionary[Metrics.Metric, int], objectives: Array[Objective])
signal objectives_updated(objectives: Array[Objective])

@export var score_thresholds: Dictionary = {
	"one_star": 30,
	"two_star": 60,
	"three_star": 100
}
@export var objective_manager:= ObjectiveManager.new()
@export var level_name := "level x"
@export var level_index : int

var run_time: float = 0.0
var enemies_left: int = 0
var player_tank: Tank
@onready var level_metrics: Metrics = Metrics.new()
@onready var MetricEnum := Metrics.Metric
@onready var entities: Node = $Entities
@onready var player_spawn_point: Marker2D = $SpawnPoints/PlayerSpawnPoint
@onready var enemy_spawn_points: Array[Marker2D] = []
#endregion
#region Lifecycle
func _ready() -> void:
	SignalBus.shell_fired.connect(_on_shell_fired)
	_initialize_spawn_points()

func _initialize_spawn_points() -> void:
	for spawn_point in $SpawnPoints.get_children() as Array[SpawnPoint]:
		if spawn_point.type == SpawnPoint.Type.ENEMY:
			enemy_spawn_points.append(spawn_point)

func start_level() -> void:
	_spawn_player()
	_spawn_enemies()
	_count_remaining_enemies()
	evaluate_metrics_and_objectives(false)

func _process(delta: float) -> void:
	run_time += delta

func finish_level(success: bool) -> void:
	evaluate_metrics_and_objectives(true)
	var result: Dictionary = objective_manager.get_objective_evaluation_result()
	var objective_count:int = result[ObjectiveManager.ObjectiveResult.COUNT]
	var objective_score: int = result[ObjectiveManager.ObjectiveResult.SCORE]
	var stars := calculate_stars(success, objective_score)
	level_metrics.set_metrics({
		MetricEnum.STARS_EARNED: stars,
		MetricEnum.SCORE_EARNED: objective_score,
		MetricEnum.OBJECTIVES_COMPLETED: objective_count,
	})
	level_finished.emit(success, level_metrics.metrics, objective_manager.objectives)
#endregion
#region Metrics and Objectives
func _count_remaining_enemies() -> void:
	var entities_children: Array[Node] = entities.get_children()
	enemies_left = entities_children.filter(
		func(entity: Node) -> bool:
			return entity is Tank and !(entity as Tank).is_player
	).size()

func calculate_stars(success: bool, score: int) -> int:
	if not success: return 0
	if score >= score_thresholds["three_star"]: return 3
	elif score >= score_thresholds["two_star"]: return 2
	elif score >= score_thresholds["one_star"]: return 1
	else: return 0

func _update_metrics(_is_level_finished: bool) -> void:
	var distance_traveled: = roundi(player_tank.distance_traveled) if player_tank else 0
	level_metrics.set_metrics({
		MetricEnum.DISTANCE_TRAVELED: distance_traveled,
		MetricEnum.RUN_TIME: run_time,
		MetricEnum.LEVELS_PLAYED: 1,
	})

func evaluate_metrics_and_objectives(is_level_finished: bool) -> void:
	_update_metrics(is_level_finished)
	objective_manager.evaluate_objectives(level_metrics.metrics)
	objectives_updated.emit(objective_manager.objectives)
#endregion
#region Tank Spawning
func _spawn_tank(tank: Tank, spawn_point: Marker2D) -> void:
	tank.global_position = spawn_point.global_position
	tank.global_rotation = spawn_point.global_rotation
	tank.damage_taken.connect(_on_damage_taken)
	tank.tank_destroyed.connect(_on_tank_destroyed)
	entities.add_child(tank)

func _spawn_player() -> void:
	var player_data: PlayerData = PlayerData.get_instance()
	var selected_tank_id: TankManager.TankId = player_data.selected_tank_id
	var unlocked_tank_ids: Array[TankManager.TankId] = player_data.get_unlocked_tank_ids()
	if !unlocked_tank_ids.has(selected_tank_id):
		if unlocked_tank_ids.size() > 0:
			selected_tank_id = unlocked_tank_ids[0]
		else:
			selected_tank_id = TankManager.TankId.TIGER_1
	var player: Tank = TankManager.create_tank(selected_tank_id, TankManager.TankControllerType.PLAYER)
	player_tank = player
	_spawn_tank(player_tank, player_spawn_point)

func _spawn_enemies() -> void:
	for spawn_point in enemy_spawn_points:
		if level_index == 0:
			#TODO: This is temporary override for level 0.
			# develop a better system for level overrides, or use composition
			var dummy_tank: Tank = TankManager.create_tank(TankManager.TankId.M4A1_SHERMAN, TankManager.TankControllerType.DUMMY)
			_spawn_tank(dummy_tank, spawn_point)
			continue
		var enemy_tank: Tank = TankManager.create_tank(TankManager.TankId.M4A1_SHERMAN, TankManager.TankControllerType.AI)
		_spawn_tank(enemy_tank, spawn_point)
#endregion
#region Signal Handlers
func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	entities.add_child(shell)

	if tank == player_tank:
		level_metrics.increment_metric(MetricEnum.SHOTS_FIRED)

func _on_damage_taken(amount: int, tank: Tank) -> void:
	if tank == player_tank:
		level_metrics.increment_metric(MetricEnum.DAMAGE_TAKEN, amount)
	else:
		level_metrics.increment_metric(MetricEnum.DAMAGE_DEALT, amount)
		level_metrics.increment_metric(MetricEnum.SHOTS_HIT)

func _on_tank_destroyed(tank: Tank) -> void:
	_handle_tank_destroyed.call_deferred(tank)

func _handle_tank_destroyed(tank: Tank) -> void:
	if tank == player_tank:
		level_metrics.increment_metric(MetricEnum.DEATHS)
		finish_level(false)
	else:
		enemies_left -= 1
		level_metrics.increment_metric(MetricEnum.KILLS)

		if enemies_left == 0:
			finish_level(true)
#endregion
