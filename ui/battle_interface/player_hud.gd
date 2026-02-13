class_name PlayerHud
extends Control

const HP_PLACEHOLDER_TEXT: String = "--/--"
const MAX_MAG_EVENT_ITEMS: int = 3
const EVENT_TEXT_WHITE: Color = Colors.WHITE
const EVENT_ENEMY_RED: Color = Colors.ENEMY_RED

var hud_active: bool = false
var tracked_player_tank: Tank

@onready var player_health_value_label: Label = %PlayerHealthValue
@onready var player_health_bar: TextureProgressBar = %PlayerHealthBar
@onready var player_mag_event_list: VBoxContainer = %PlayerMagEventList
@onready var player_mag_event_item_scene: PackedScene = preload(
	"res://ui/battle_interface/player_mag_event_item.tscn"
)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_health_bar.tint_progress = Colors.FRIENDLY_GREEN
	Utils.connect_checked(GameplayBus.online_player_impact_event, _on_online_player_impact_event)
	_reset_display()
	visible = false


func _process(delta: float) -> void:
	if delta < 0.0 or not hud_active:
		return
	_try_track_player_tank()


func set_hud_active(is_active: bool) -> void:
	hud_active = is_active
	visible = is_active
	if not hud_active:
		_untrack_player_tank()
		_reset_display()
		return
	_try_track_player_tank()


func _try_track_player_tank() -> void:
	var next_player_tank: Tank = _find_player_tank()
	if next_player_tank == tracked_player_tank:
		return
	_untrack_player_tank()
	tracked_player_tank = next_player_tank
	if tracked_player_tank == null:
		_reset_display()
		return
	player_health_bar.max_value = tracked_player_tank.tank_spec.health
	_update_health_display(tracked_player_tank._health)
	Utils.connect_checked(tracked_player_tank.health_updated, _on_player_tank_health_updated)
	Utils.connect_checked(tracked_player_tank.tree_exiting, _on_player_tank_tree_exiting)


func _find_player_tank() -> Tank:
	for node: Node in get_tree().get_nodes_in_group("tank"):
		var candidate_tank: Tank = node as Tank
		if candidate_tank == null:
			continue
		if not candidate_tank.is_player:
			continue
		return candidate_tank
	return null


func _untrack_player_tank() -> void:
	if tracked_player_tank == null:
		return
	if tracked_player_tank.health_updated.is_connected(_on_player_tank_health_updated):
		tracked_player_tank.health_updated.disconnect(_on_player_tank_health_updated)
	if tracked_player_tank.tree_exiting.is_connected(_on_player_tank_tree_exiting):
		tracked_player_tank.tree_exiting.disconnect(_on_player_tank_tree_exiting)
	tracked_player_tank = null


func _on_player_tank_health_updated(health: int, tank: Tank) -> void:
	if tank != tracked_player_tank:
		return
	_update_health_display(health)


func _on_player_tank_tree_exiting() -> void:
	_untrack_player_tank()
	_reset_display()


func _on_online_player_impact_event(event_data: Dictionary) -> void:
	if not hud_active:
		return
	var item: HBoxContainer = player_mag_event_item_scene.instantiate() as HBoxContainer
	if item == null:
		return
	player_mag_event_list.add_child(item)
	var hp_label: Label = item.get_node("HpLabel")
	var verb_label: Label = item.get_node("VerbLabel")
	var enemy_label: Label = item.get_node("EnemyLabel")
	var shell_label: Label = item.get_node("ShellLabel")
	hp_label.text = str(event_data.get("hp_text", "0HP"))
	hp_label.modulate = event_data.get("hp_color", Colors.GOLD_DARK)
	verb_label.text = str(event_data.get("verb_text", " "))
	verb_label.modulate = EVENT_TEXT_WHITE
	enemy_label.text = str(event_data.get("enemy_text", "[TANK]"))
	enemy_label.modulate = EVENT_ENEMY_RED
	shell_label.text = str(event_data.get("shell_text", "SHELL"))
	shell_label.modulate = EVENT_TEXT_WHITE
	_trim_player_mag_event_list_to_limit()


func _update_health_display(health: int) -> void:
	var max_health: int = max(1, int(player_health_bar.max_value))
	var clamped_health: int = clamp(health, 0, max_health)
	player_health_bar.value = clamped_health
	player_health_value_label.text = "%d/%d" % [clamped_health, max_health]


func _trim_player_mag_event_list_to_limit() -> void:
	while player_mag_event_list.get_child_count() > MAX_MAG_EVENT_ITEMS:
		var oldest_item: Node = player_mag_event_list.get_child(0)
		player_mag_event_list.remove_child(oldest_item)
		oldest_item.queue_free()


func _clear_player_mag_event_list() -> void:
	for child: Node in player_mag_event_list.get_children():
		player_mag_event_list.remove_child(child)
		child.queue_free()


func _reset_display() -> void:
	player_health_bar.max_value = 1
	player_health_bar.value = 0
	player_health_value_label.text = HP_PLACEHOLDER_TEXT
	_clear_player_mag_event_list()
