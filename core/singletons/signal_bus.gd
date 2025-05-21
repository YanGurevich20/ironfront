extends Node

# Input signals from UI controls
signal lever_input(lever_side: Lever.LeverSide, value: float)
signal wheel_input(value: float)
signal fire_input()
signal shell_selected(shell_spec: ShellSpec)

signal reload_progress_left_updated(progress: float) # 1 just fired, 0 fully loaded

signal login_pressed
signal log_out_pressed
signal quit_pressed
signal level_pressed(level: int)
signal play_pressed

signal tank_selected(tank_id: TankManager.TankId)
signal shell_unlock_requested(shell_id: ShellManager.ShellId)