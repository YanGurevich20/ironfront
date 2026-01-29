extends Node

# Input signals from UI controls
@warning_ignore("unused_signal")
signal lever_input(lever_side: Lever.LeverSide, value: float)
@warning_ignore("unused_signal")
signal wheel_input(value: float)
@warning_ignore("unused_signal")
signal fire_input(shell_spec: ShellSpec)
@warning_ignore("unused_signal")
signal shell_selected(shell_spec: ShellSpec, remaining_shell_count: int)
@warning_ignore("unused_signal")
signal pause_input

@warning_ignore("unused_signal")
signal update_remaining_shell_count(count: int)
@warning_ignore("unused_signal")
signal reload_progress_left_updated(progress: float, tank: Tank)  # 0 just fired, 1 fully loaded

@warning_ignore("unused_signal")
signal login_pressed
@warning_ignore("unused_signal")
signal log_out_pressed
@warning_ignore("unused_signal")
signal quit_pressed
@warning_ignore("unused_signal")
signal level_pressed(level: int)
@warning_ignore("unused_signal")
signal level_started
@warning_ignore("unused_signal")
signal play_pressed
@warning_ignore("unused_signal")
signal level_finished_and_saved

# Garage signals
@warning_ignore("unused_signal")
signal tank_selected(tank_id: TankManager.TankId)
@warning_ignore("unused_signal")
signal shell_unlock_requested(shell_spec: ShellSpec)
@warning_ignore("unused_signal")
signal shell_info_requested(shell_spec: ShellSpec)

# Tank signals
@warning_ignore("unused_signal")
signal shell_fired(shell: Shell, tank: Tank)
signal tank_destroyed(tank: Tank)

# Settings signals
@warning_ignore("unused_signal")
signal settings_changed
