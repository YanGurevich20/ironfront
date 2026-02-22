class_name PlayerHud
extends Control

const HP_PLACEHOLDER_TEXT: String = "--/--"
const MAX_MAG_EVENT_ITEMS: int = 3
const EVENT_TEXT_WHITE: Color = Colors.WHITE
const EVENT_ENEMY_RED: Color = Colors.ENEMY_RED

var hud_active: bool = false
var tracked_player_tank: Tank
var player_mag_event_rows: Array[HBoxContainer] = []
var next_mag_event_row_index: int = 0

@onready var player_health_value_label: Label = %PlayerHealthValue
@onready var player_health_bar: TextureProgressBar = %PlayerHealthBar
@onready var player_mag_event_list: VBoxContainer = %PlayerMagEventList
@onready var player_mag_event_item_scene: PackedScene = preload(
	"res://src/client/arena/battle_interface/player_mag_event_item.tscn"
)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_health_bar.tint_progress = Colors.FRIENDLY_GREEN
	Utils.connect_checked(GameplayBus.player_impact_event, _on_player_impact_event)
	_initialize_impact_rows()
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


func _on_player_impact_event(
	_shot_id: int,
	firing_peer_id: int,
	target_peer_id: int,
	local_is_target: bool,
	result_type: int,
	damage: int,
	shell_type: int
) -> void:
	if not hud_active:
		return
	var item: HBoxContainer = _next_impact_row()
	if item == null:
		return
	var hp_label: Label = item.get_node_or_null("HpLabel") as Label
	var verb_label: Label = item.get_node_or_null("VerbLabel") as Label
	var enemy_label: Label = item.get_node_or_null("EnemyLabel") as Label
	var shell_label: Label = item.get_node_or_null("ShellLabel") as Label
	if hp_label == null or verb_label == null or enemy_label == null or shell_label == null:
		return
	var related_tank_name: String = _resolve_related_tank_name(firing_peer_id, target_peer_id)
	hp_label.text = _build_hp_text(local_is_target, damage)
	hp_label.modulate = _resolve_hp_color(local_is_target, result_type)
	verb_label.text = _build_verb_text(local_is_target, result_type)
	verb_label.modulate = EVENT_TEXT_WHITE
	enemy_label.text = "[%s]" % related_tank_name
	enemy_label.modulate = EVENT_ENEMY_RED
	shell_label.text = _resolve_shell_type_label(shell_type)
	shell_label.modulate = EVENT_TEXT_WHITE
	item.visible = true


func _update_health_display(health: int) -> void:
	var max_health: int = max(1, int(player_health_bar.max_value))
	var clamped_health: int = clamp(health, 0, max_health)
	player_health_bar.value = clamped_health
	player_health_value_label.text = "%d/%d" % [clamped_health, max_health]


func _initialize_impact_rows() -> void:
	_clear_player_mag_event_list()
	player_mag_event_rows.clear()
	for _i: int in range(MAX_MAG_EVENT_ITEMS):
		var item: HBoxContainer = player_mag_event_item_scene.instantiate() as HBoxContainer
		if item == null:
			continue
		item.visible = false
		player_mag_event_list.add_child(item)
		player_mag_event_rows.append(item)
	next_mag_event_row_index = 0


func _next_impact_row() -> HBoxContainer:
	if player_mag_event_rows.is_empty():
		return null
	if next_mag_event_row_index >= player_mag_event_rows.size():
		next_mag_event_row_index = 0
	var row: HBoxContainer = player_mag_event_rows[next_mag_event_row_index]
	next_mag_event_row_index = (next_mag_event_row_index + 1) % player_mag_event_rows.size()
	var row_index: int = row.get_index()
	var latest_index: int = player_mag_event_list.get_child_count() - 1
	if row_index >= 0 and row_index != latest_index:
		player_mag_event_list.move_child(row, latest_index)
	return row


func _clear_impact_rows() -> void:
	next_mag_event_row_index = 0
	for row: HBoxContainer in player_mag_event_rows:
		if row == null:
			continue
		row.visible = false


func _clear_player_mag_event_list() -> void:
	for child: Control in player_mag_event_list.get_children():
		child.queue_free()


func _build_hp_text(local_is_target: bool, damage: int) -> String:
	var safe_damage: int = max(0, damage)
	var hp_prefix: String = "-" if local_is_target else ""
	return "%s%dHP" % [hp_prefix, safe_damage]


func _resolve_hp_color(local_is_target: bool, result_type: int) -> Color:
	if _is_non_pen_result(result_type):
		return Colors.GOLD_DARK
	return Colors.ENEMY_RED if local_is_target else Colors.GOLD


func _build_verb_text(local_is_target: bool, result_type: int) -> String:
	if not _is_non_pen_result(result_type):
		return " " if local_is_target else " to "
	var result_name: String = str(ShellSpec.ImpactResultType.find_key(result_type)).to_lower()
	if result_name == "unpenetrated":
		result_name = "unpenned"
	if result_name.is_empty():
		result_name = "impact"
	return " %s " % result_name


func _is_non_pen_result(result_type: int) -> bool:
	return (
		result_type == ShellSpec.ImpactResultType.BOUNCED
		or result_type == ShellSpec.ImpactResultType.UNPENETRATED
		or result_type == ShellSpec.ImpactResultType.SHATTERED
	)


func _reset_display() -> void:
	player_health_bar.max_value = 1
	player_health_bar.value = 0
	player_health_value_label.text = HP_PLACEHOLDER_TEXT
	_clear_impact_rows()


func _resolve_related_tank_name(firing_peer_id: int, target_peer_id: int) -> String:
	var local_peer_id: int = multiplayer.get_unique_id()
	var local_is_firing: bool = firing_peer_id == local_peer_id
	var related_peer_id: int = target_peer_id if local_is_firing else firing_peer_id
	var related_tank: Tank = _find_tank_by_peer_id(related_peer_id)
	return _resolve_tank_name(related_tank)


func _find_tank_by_peer_id(peer_id: int) -> Tank:
	for node: Node in get_tree().get_nodes_in_group("tank"):
		var tank: Tank = node as Tank
		if tank == null:
			continue
		if tank.network_peer_id != peer_id:
			continue
		return tank
	return null


func _resolve_tank_name(tank: Tank) -> String:
	if tank == null or not is_instance_valid(tank) or tank.tank_spec == null:
		return "TANK"
	var display_name: String = tank.tank_spec.display_name.strip_edges()
	if display_name.is_empty():
		return "TANK"
	return display_name


func _resolve_shell_type_label(shell_type: int) -> String:
	if shell_type < 0:
		return "SHELL"
	var shell_type_name: String = str(BaseShellType.ShellType.find_key(shell_type)).strip_edges()
	if shell_type_name.is_empty():
		return "SHELL"
	return shell_type_name
