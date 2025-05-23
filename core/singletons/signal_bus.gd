extends Node

# Input signals from UI controls
signal lever_input(lever_side: Lever.LeverSide, value: float)
signal wheel_input(value: float)
signal fire_input(shell_id: ShellManager.ShellId)
signal shell_selected(shell_id: ShellManager.ShellId)
signal pause_input()

signal reload_progress_left_updated(progress: float, tank: Tank) # 0 just fired, 1 fully loaded

signal login_pressed
signal log_out_pressed
signal quit_pressed
signal level_pressed(level: int)
signal level_started()
signal play_pressed

# Garage signals
signal tank_selected(tank_id: TankManager.TankId)
signal shell_unlock_requested(shell_id: ShellManager.ShellId)

# Tank signals
signal shell_fired(shell: Shell, tank: Tank)