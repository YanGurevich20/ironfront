class_name Main
extends Node

var client_scene: PackedScene = preload("res://core/client.tscn")
var server_scene: PackedScene = preload("res://core/server.tscn")


func _ready() -> void:
	var launch_server_runtime: bool = OS.has_feature("dedicated_server") or _has_server_cli_flag()
	if launch_server_runtime:
		var server_runtime: Node = server_scene.instantiate()
		add_child(server_runtime)
		print("[main] launched server runtime")
	else:
		var client_runtime: Node = client_scene.instantiate()
		add_child(client_runtime)
		print("[main] launched client runtime")


func _has_server_cli_flag() -> bool:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for user_arg: String in user_args:
		if user_arg == "--server":
			return true
	return false
