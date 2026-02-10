extends Node

# Gameplay input and lifecycle signals

signal lever_input(lever_side: Lever.LeverSide, value: float)
signal wheel_input(value: float)
signal fire_input(shell_spec: ShellSpec)
signal shell_selected(shell_spec: ShellSpec, remaining_shell_count: int)
signal update_remaining_shell_count(count: int)
signal reload_progress_left_updated(progress: float, tank: Tank)  # 0 just fired, 1 fully loaded

signal shell_fired(shell: Shell, tank: Tank)
signal tank_destroyed(tank: Tank)

signal level_started
signal level_finished_and_saved

signal settings_changed
