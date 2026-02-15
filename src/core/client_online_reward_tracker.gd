class_name ClientOnlineRewardTracker
extends RefCounted

var reward_per_kill_dollars: int
var kills: int = 0
var reward_dollars: int = 0
var last_kill_event_seq: int = 0


func _init(next_reward_per_kill_dollars: int) -> void:
	reward_per_kill_dollars = max(0, next_reward_per_kill_dollars)


func reset() -> void:
	kills = 0
	reward_dollars = 0
	last_kill_event_seq = 0


func on_kill_feed_event(
	event_seq: int,
	killer_peer_id: int,
	killer_name: String,
	killer_tank_name: String,
	shell_short_name: String,
	victim_actor_id: int,
	victim_name: String,
	victim_tank_name: String,
	local_peer_id: int
) -> void:
	if event_seq <= last_kill_event_seq:
		return
	last_kill_event_seq = event_seq
	if killer_name.is_empty() and killer_tank_name.is_empty():
		return
	if shell_short_name.is_empty():
		return
	if victim_actor_id == 0 or victim_name.is_empty() or victim_tank_name.is_empty():
		return
	if killer_peer_id != local_peer_id:
		return
	kills += 1
	reward_dollars += reward_per_kill_dollars


func build_summary(status_message: String) -> Dictionary:
	var resolved_reward_dollars: int = max(0, reward_dollars)
	return {
		"status_message": status_message,
		"kills": kills,
		"reward_dollars": resolved_reward_dollars,
	}


func apply_rewards(player_data: PlayerData) -> void:
	if player_data == null:
		return
	var resolved_reward_dollars: int = max(0, reward_dollars)
	if resolved_reward_dollars <= 0:
		return
	player_data.add_dollars(resolved_reward_dollars)
	player_data.save()
