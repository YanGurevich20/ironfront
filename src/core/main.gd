class_name Main
extends Node

var client_scene: PackedScene = preload("res://src/core/client.tscn")
var server_scene: PackedScene = preload("res://src/core/server.tscn")


func _ready() -> void:
	print("[main] cli args=%s" % str(OS.get_cmdline_args()))
	if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_user_args():
		var server_runtime: Server = server_scene.instantiate()
		add_child(server_runtime)
		print("[main] launched server runtime")
	else:
		var client_runtime: Client = client_scene.instantiate()
		add_child(client_runtime)
		print("[main] launched client runtime")
