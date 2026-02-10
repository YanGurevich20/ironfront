class_name Server
extends Node

@export var listen_port: int = 7000
@export var max_clients: int = 32
@export var tick_rate_hz: int = 30

var tick_timer: Timer
var tick_count: int = 0

@onready var network_server: NetworkServer = %Network


func _ready() -> void:
	_apply_cli_args()
	var server_started: bool = network_server.start_server(listen_port, max_clients)
	if not server_started:
		get_tree().quit(1)
	_start_tick_loop()


func _apply_cli_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--port="):
			var port_value: int = int(arg.trim_prefix("--port="))
			if port_value > 0:
				listen_port = port_value


func _start_tick_loop() -> void:
	tick_timer = Timer.new()
	tick_timer.one_shot = false
	tick_timer.wait_time = 1.0 / float(tick_rate_hz)
	add_child(tick_timer)
	Utils.connect_checked(tick_timer.timeout, _on_tick)
	tick_timer.start()
	print("[server] tick loop started at %d Hz" % tick_rate_hz)


func _on_tick() -> void:
	tick_count += 1
	if tick_count % tick_rate_hz == 0:
		var uptime_seconds: int = int(tick_count / float(tick_rate_hz))
		print("[server] uptime=%ds peers=%d" % [uptime_seconds, multiplayer.get_peers().size()])
