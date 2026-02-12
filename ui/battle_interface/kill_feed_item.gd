class_name KillFeedItem
extends HBoxContainer

signal expired(item: KillFeedItem)

const ENEMY_COLOR: Color = Color(0.94, 0.27, 0.27)
const PLAYER_COLOR: Color = Color(0.98, 0.78, 0.22)
const SHELL_COLOR: Color = Color(1.0, 1.0, 1.0)

@onready var killer_label: Label = %KillerLabel
@onready var shell_label: Label = %ShellLabel
@onready var victim_label: Label = %VictimLabel
@onready var expire_timer: Timer = %ExpireTimer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Utils.connect_checked(expire_timer.timeout, _on_expire_timeout)


func set_kill_event(
	killer_name: String,
	killer_tank_name: String,
	killer_is_local: bool,
	shell_short_name: String,
	victim_name: String,
	victim_tank_name: String,
	victim_is_local: bool
) -> void:
	killer_label.text = _format_player_tank_label(killer_name, killer_tank_name)
	killer_label.modulate = PLAYER_COLOR if killer_is_local else ENEMY_COLOR
	var resolved_shell_short_name: String = shell_short_name.strip_edges()
	shell_label.text = (
		resolved_shell_short_name if not resolved_shell_short_name.is_empty() else "SHELL"
	)
	shell_label.modulate = SHELL_COLOR
	victim_label.text = _format_player_tank_label(victim_name, victim_tank_name)
	victim_label.modulate = PLAYER_COLOR if victim_is_local else ENEMY_COLOR
	expire_timer.start()


func _on_expire_timeout() -> void:
	expired.emit(self)


func _format_player_tank_label(player_name: String, tank_name: String) -> String:
	var resolved_player_name: String = player_name.strip_edges()
	var resolved_tank_name: String = tank_name.strip_edges()
	if resolved_player_name.is_empty():
		resolved_player_name = "PLAYER"
	if resolved_tank_name.is_empty():
		resolved_tank_name = "TANK"
	return "%s [%s]" % [resolved_player_name, resolved_tank_name]
