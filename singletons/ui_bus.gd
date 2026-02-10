extends Node

# UI intent and flow signals

signal login_pressed
signal log_out_pressed
signal quit_pressed
signal garage_menu_pressed
signal play_pressed
signal play_online_pressed
signal level_pressed(level: int)
signal pause_input
signal shell_unlock_requested(shell_spec: ShellSpec)
signal shell_info_requested(shell_spec: ShellSpec)
signal resume_requested
signal restart_level_requested
signal abort_level_requested
signal return_to_menu_requested
