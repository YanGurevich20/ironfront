class_name ClientMatchResults
extends RefCounted


static func calculate_level_reward(new_metrics: Dictionary, level_key: int) -> Dictionary:
	var current_run_stars: int = new_metrics.get(Metrics.Metric.STARS_EARNED, 0)
	var game_progress: PlayerData = PlayerData.get_instance()
	var previous_max_stars: int = game_progress.get_stars_for_level(level_key)
	var dollars_to_award_this_run: int = 0
	var doubled_stars: Array[int] = []
	var star_dollar_values: Dictionary[int, int] = {
		1: 5_000,
		2: 15_000,
		3: 30_000,
	}
	for star_level: int in range(1, current_run_stars + 1):
		var base_dollars: int = star_dollar_values.get(star_level, 0)
		var dollars_for_this_star: int = base_dollars
		if star_level > previous_max_stars:
			dollars_for_this_star = base_dollars * 2
			doubled_stars.append(star_level)
		dollars_to_award_this_run += dollars_for_this_star
	return {"total_reward": dollars_to_award_this_run, "doubled_stars": doubled_stars}
