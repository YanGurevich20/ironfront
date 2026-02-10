class_name Main
extends Node

var client_scene: PackedScene = preload("res://core/client.tscn")
var server_scene: PackedScene = preload("res://core/server.tscn")


func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		var server_runtime: Node = server_scene.instantiate()
		add_child(server_runtime)
		print("[main] launched server runtime")
	else:
		var client_runtime: Node = client_scene.instantiate()
		add_child(client_runtime)
		print("[main] launched client runtime")
