class_name BattleInterface extends Control

const PING_UPDATE_INTERVAL_SECONDS: float = 0.25

var ping_update_elapsed_seconds: float = 0.0
var network_client: NetworkClient

@onready var tank_control: TankControl = %TankControl
@onready var enemy_indicators: EnemyIndicators = %EnemyIndicators
@onready var tank_hud_layer: Node = %TankHUDLayer
@onready var ping_label: Label = %PingLabel


func _process(delta: float) -> void:
	ping_update_elapsed_seconds += delta
	if ping_update_elapsed_seconds < PING_UPDATE_INTERVAL_SECONDS:
		return
	ping_update_elapsed_seconds = 0.0
	_refresh_ping_indicator()


func set_network_client(network_client_ref: NetworkClient) -> void:
	network_client = network_client_ref
	_refresh_ping_indicator()


func finish_level() -> void:
	tank_control.reset_input()
	enemy_indicators.reset_indicators()
	tank_hud_layer.call("reset_huds")
	ping_label.visible = false


func start_level() -> void:
	tank_control.display_controls()
	enemy_indicators.display_indicators()
	tank_hud_layer.call("display_huds")
	ping_update_elapsed_seconds = 0.0
	_refresh_ping_indicator()


func _refresh_ping_indicator() -> void:
	if network_client == null:
		ping_label.visible = false
		return
	if not network_client.should_show_ping_indicator():
		ping_label.visible = false
		return
	var ping_msec: int = network_client.get_connection_ping_msec()
	if ping_msec < 0:
		ping_label.visible = false
		return
	ping_label.visible = true
	ping_label.text = "PING %dms" % ping_msec
