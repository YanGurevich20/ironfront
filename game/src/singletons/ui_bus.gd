extends Node

signal quit_pressed
signal garage_menu_pressed
signal play_pressed
signal pause_input
signal shell_unlock_requested(shell_spec: ShellSpec)
signal shell_info_requested(shell_spec: ShellSpec)
signal resume_requested
signal online_session_end_requested(status_message: String)
signal online_respawn_requested
