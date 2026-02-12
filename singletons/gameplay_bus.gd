extends Node

# Gameplay input and lifecycle signals

signal lever_input(lever_side: Lever.LeverSide, value: float)
signal wheel_input(value: float)
signal fire_input(shell_spec: ShellSpec)
signal shell_selected(shell_spec: ShellSpec, remaining_shell_count: int)
signal update_remaining_shell_count(count: int)
signal reload_progress_left_updated(progress: float, tank: Tank)  # 0 just fired, 1 fully loaded
signal online_fire_rejected(reason: String)
signal online_loadout_state_updated(
	selected_shell_path: String, shell_counts_by_path: Dictionary, reload_time_left: float
)

signal shell_fired(shell: Shell, tank: Tank)
signal tank_destroyed(tank: Tank)

signal level_started
signal level_finished_and_saved

signal settings_changed
