class_name PlayerHud
extends Control

const HP_PLACEHOLDER_TEXT: String = "--/--"

var hud_active: bool = false
var tracked_player_tank: Tank

@onready var player_health_value_label: Label = %PlayerHealthValue
@onready var player_health_bar: TextureProgressBar = %PlayerHealthBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_health_bar.tint_progress = Colors.FRIENDLY_GREEN
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


func _update_health_display(health: int) -> void:
	var max_health: int = max(1, int(player_health_bar.max_value))
	var clamped_health: int = clamp(health, 0, max_health)
	player_health_bar.value = clamped_health
	player_health_value_label.text = "%d/%d" % [clamped_health, max_health]


func _reset_display() -> void:
	player_health_bar.max_value = 1
	player_health_bar.value = 0
	player_health_value_label.text = HP_PLACEHOLDER_TEXT
