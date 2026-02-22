class_name KillFeedItem
extends HBoxContainer

signal expired(item: KillFeedItem)

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
	killer_label.modulate = Colors.GOLD if killer_is_local else Colors.ENEMY_RED
	shell_label.text = shell_short_name if not shell_short_name.is_empty() else "SHELL"
	shell_label.modulate = Colors.WHITE_BRIGHT
	victim_label.text = _format_player_tank_label(victim_name, victim_tank_name)
	victim_label.modulate = Colors.GOLD if victim_is_local else Colors.ENEMY_RED
	expire_timer.start()


func _on_expire_timeout() -> void:
	expired.emit(self)


func _format_player_tank_label(player_name: String, tank_name: String) -> String:
	var resolved_player_name: String = player_name if not player_name.is_empty() else "PLAYER"
	var resolved_tank_name: String = tank_name if not tank_name.is_empty() else "TANK"
	return "%s [%s]" % [resolved_player_name, resolved_tank_name]
