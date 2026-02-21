class_name PlayerProfileUtils
extends RefCounted


static func create_local_player_tank(
	controller_type: TankManager.TankControllerType = TankManager.TankControllerType.PLAYER
) -> Tank:
	var player_data: PlayerData = PlayerData.get_instance()
	var selected_tank_id: String = player_data.selected_tank_id
	var unlocked_tank_ids: Array[String] = player_data.get_unlocked_tank_ids()
	if not unlocked_tank_ids.has(selected_tank_id):
		if unlocked_tank_ids.size() > 0:
			selected_tank_id = unlocked_tank_ids[0]
		else:
			selected_tank_id = TankManager.TANK_ID_TIGER_1
	var player_tank: Tank = TankManager.create_tank(selected_tank_id, controller_type)
	player_tank.display_player_name = player_data.player_name.strip_edges()
	return player_tank


static func fetch_level_stars(level: int) -> int:
	var game_progress: PlayerData = PlayerData.get_instance()
	return game_progress.get_stars_for_level(level)


static func save_player_metrics(new_metrics: Dictionary = {}) -> void:
	var player_metrics: Metrics = Metrics.get_instance()
	player_metrics.merge_metrics(new_metrics)
	player_metrics.save()


static func save_game_progress(
	new_metrics: Dictionary, level_key: int, dollar_reward: int = 0
) -> void:
	var current_run_stars: int = new_metrics.get(Metrics.Metric.STARS_EARNED, 0)
	var game_progress: PlayerData = PlayerData.get_instance()
	var dollars_to_award_this_run: int = dollar_reward

	game_progress.update_progress(level_key, current_run_stars, dollars_to_award_this_run)
	game_progress.save()
	GameplayBus.level_finished_and_saved.emit()
