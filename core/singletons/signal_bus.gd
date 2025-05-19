extends Node

# Input signals from UI controls
signal lever_input(lever_side: Lever.Side, value: float)
signal wheel_input(value: float)
signal fire_input()

signal login_pressed
signal log_out_pressed
signal quit_pressed
signal level_pressed(level: int)
signal play_pressed