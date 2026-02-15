extends Node

# Gameplay input and lifecycle signals

signal lever_input(lever_side: Lever.LeverSide, value: float)
signal wheel_input(value: float)
signal fire_input
signal shell_selected(shell_spec: ShellSpec, remaining_shell_count: int)
signal update_remaining_shell_count(count: int)
signal reload_progress_left_updated(progress: float, tank: Tank)  # 0 just fired, 1 fully loaded
signal online_fire_rejected(reason: String)
signal online_loadout_state_updated(
	selected_shell_id: String, shell_counts_by_id: Dictionary, reload_time_left: float
)
signal online_player_count_updated(active_players: int, max_players: int, active_bots: int)
signal online_kill_feed_event(
	event_seq: int,
	killer_peer_id: int,
	killer_name: String,
	killer_tank_name: String,
	shell_short_name: String,
	victim_peer_id: int,
	victim_name: String,
	victim_tank_name: String
)
signal online_player_impact_event(event_data: Dictionary)

signal shell_fired(shell: Shell, tank: Tank)
signal tank_destroyed(tank: Tank)

signal level_started
signal level_finished_and_saved
signal player_data_changed

signal settings_changed
