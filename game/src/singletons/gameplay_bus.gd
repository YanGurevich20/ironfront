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
signal player_kill_event(
	event_seq: int,
	killer_name: String,
	killer_tank_name: String,
	killer_is_local: bool,
	shell_short_name: String,
	victim_name: String,
	victim_tank_name: String,
	victim_is_local: bool
)
signal player_impact_event(
	local_is_target: bool,
	result_type: int,
	damage: int,
	related_tank_name: String,
	shell_short_name: String
)

signal shell_fired(shell: Shell, tank: Tank)
signal tank_destroyed(tank: Tank)

signal level_started
signal level_finished
signal player_data_changed

signal settings_changed
