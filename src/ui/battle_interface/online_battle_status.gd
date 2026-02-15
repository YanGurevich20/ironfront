class_name OnlineBattleStatus
extends Control

const MAX_KILL_FEED_ITEMS: int = 5
const PLAYER_COUNT_PLACEHOLDER_TEXT: String = "PLAYERS --/--"
const BOT_COUNT_PLACEHOLDER_TEXT: String = "BOTS --"
const PING_PLACEHOLDER_TEXT: String = "PING --"
const PING_UPDATE_INTERVAL_SECONDS: float = 1.0

var online_session_active: bool = false
var latest_kill_event_seq: int = 0
var ping_update_elapsed_seconds: float = 0.0
var network_client: NetworkClient

@onready var player_count_label: Label = %PlayerCountLabel
@onready var bot_count_label: Label = %BotCountLabel
@onready var ping_label: Label = %PingLabel
@onready var kill_feed_list: VBoxContainer = %KillFeedList
@onready
var kill_feed_item_scene: PackedScene = preload("res://src/ui/battle_interface/kill_feed_item.tscn")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Utils.connect_checked(GameplayBus.online_player_count_updated, _on_online_player_count_updated)
	Utils.connect_checked(GameplayBus.online_kill_feed_event, _on_online_kill_feed_event)
	set_online_session_active(false)


func _process(delta: float) -> void:
	if not online_session_active:
		return
	ping_update_elapsed_seconds += delta
	if ping_update_elapsed_seconds < PING_UPDATE_INTERVAL_SECONDS:
		return
	ping_update_elapsed_seconds = 0.0
	_refresh_ping_indicator()


func set_network_client(network_client_ref: NetworkClient) -> void:
	network_client = network_client_ref
	_refresh_ping_indicator()


func set_online_session_active(is_active: bool) -> void:
	online_session_active = is_active
	visible = is_active
	latest_kill_event_seq = 0
	ping_update_elapsed_seconds = 0.0
	player_count_label.text = PLAYER_COUNT_PLACEHOLDER_TEXT
	bot_count_label.text = BOT_COUNT_PLACEHOLDER_TEXT
	ping_label.text = PING_PLACEHOLDER_TEXT
	ping_label.visible = false
	_clear_kill_feed()
	_refresh_ping_indicator()


func _on_online_player_count_updated(
	active_players: int, max_players: int, active_bots: int
) -> void:
	if not online_session_active:
		return
	if max_players <= 0:
		player_count_label.text = "PLAYERS %d/--" % max(0, active_players)
	else:
		player_count_label.text = "PLAYERS %d/%d" % [max(0, active_players), max_players]
	bot_count_label.text = "BOTS %d" % max(0, active_bots)


func _on_online_kill_feed_event(
	event_seq: int,
	killer_peer_id: int,
	killer_name: String,
	killer_tank_name: String,
	shell_short_name: String,
	victim_peer_id: int,
	victim_name: String,
	victim_tank_name: String
) -> void:
	if not online_session_active:
		return
	if event_seq <= latest_kill_event_seq:
		return
	latest_kill_event_seq = event_seq
	var local_peer_id: int = (
		multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	)
	var kill_feed_item: Node = kill_feed_item_scene.instantiate()
	kill_feed_list.add_child(kill_feed_item)
	kill_feed_list.move_child(kill_feed_item, 0)
	kill_feed_item.call(
		"set_kill_event",
		killer_name,
		killer_tank_name,
		killer_peer_id == local_peer_id,
		shell_short_name,
		victim_name,
		victim_tank_name,
		victim_peer_id == local_peer_id
	)
	kill_feed_item.connect("expired", Callable(self, "_on_kill_feed_item_expired"))
	_trim_kill_feed_to_limit()


func _on_kill_feed_item_expired(item: Node) -> void:
	if item == null:
		return
	if item.get_parent() != kill_feed_list:
		return
	kill_feed_list.remove_child(item)
	item.queue_free()


func _trim_kill_feed_to_limit() -> void:
	while kill_feed_list.get_child_count() > MAX_KILL_FEED_ITEMS:
		var oldest_item: Node = kill_feed_list.get_child(kill_feed_list.get_child_count() - 1)
		kill_feed_list.remove_child(oldest_item)
		oldest_item.queue_free()


func _clear_kill_feed() -> void:
	for child: Node in kill_feed_list.get_children():
		kill_feed_list.remove_child(child)
		child.queue_free()


func _refresh_ping_indicator() -> void:
	if not online_session_active:
		ping_label.visible = false
		return
	if network_client == null:
		ping_label.visible = false
		return
	var ping_msec: int = network_client.get_connection_ping_msec()
	if ping_msec < 0:
		ping_label.visible = false
		return
	ping_label.visible = true
	ping_label.text = "[EU]PING %dms" % ping_msec
