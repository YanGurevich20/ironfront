class_name BattleInterface
extends Control

var network_client: ENetClient

@onready var tank_control: TankControl = %TankControl
@onready var enemy_indicators: EnemyIndicators = %EnemyIndicators
@onready var tank_hud_layer: TankHUDLayer = %TankHUDLayer
@onready var player_hud: PlayerHud = %PlayerHud
@onready var online_battle_status: OnlineBattleStatus = %OnlineBattleStatus


func _ready() -> void:
	player_hud.set_hud_active(false)


func set_network_client(network_client_ref: ENetClient) -> void:
	network_client = network_client_ref
	online_battle_status.set_network_client(network_client)


func set_online_session_active(is_active: bool) -> void:
	online_battle_status.set_online_session_active(is_active)


func finish_level() -> void:
	tank_control.reset_input()
	enemy_indicators.reset_indicators()
	tank_hud_layer.reset_huds()
	player_hud.set_hud_active(false)
	set_online_session_active(false)


func start_level() -> void:
	enemy_indicators.display_indicators()
	tank_hud_layer.display_huds()
	player_hud.set_hud_active(true)
