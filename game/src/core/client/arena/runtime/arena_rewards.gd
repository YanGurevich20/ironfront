class_name ArenaRewards
extends Node

@export var reward_per_kill_dollars: int = 5000

var kills: int = 0
var reward_dollars: int = 0
var last_kill_event_seq: int = 0


func start_session() -> void:
	reset()
	if not GameplayBus.player_kill_event.is_connected(on_player_kill_event):
		GameplayBus.player_kill_event.connect(on_player_kill_event)


func stop_session() -> void:
	if GameplayBus.player_kill_event.is_connected(on_player_kill_event):
		GameplayBus.player_kill_event.disconnect(on_player_kill_event)


func reset() -> void:
	kills = 0
	reward_dollars = 0
	last_kill_event_seq = 0


func on_player_kill_event(
	event_seq: int,
	killer_name: String,
	killer_tank_name: String,
	killer_is_local: bool,
	shell_short_name: String,
	victim_name: String,
	victim_tank_name: String,
	_victim_is_local: bool
) -> void:
	if event_seq <= last_kill_event_seq:
		return
	last_kill_event_seq = event_seq
	if killer_name.is_empty() and killer_tank_name.is_empty():
		return
	if shell_short_name.is_empty():
		return
	if victim_name.is_empty() or victim_tank_name.is_empty():
		return
	if not killer_is_local:
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


func apply_rewards() -> void:
	var resolved_reward_dollars: int = max(0, reward_dollars)
	if resolved_reward_dollars <= 0:
		return
	Account.economy.dollars += resolved_reward_dollars
